import asyncio
import base64
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parent.parent

class FakeGuest:
    def __init__(self, path):
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.bind(str(path))
        self.socket.listen()
        self.socket.settimeout(0.2)
        self.stop = threading.Event()
        self.finished = threading.Event()
        self.files = {}
        self.handles = {}
        self.counter = 0
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()
    def serve(self):
        while not self.stop.is_set():
            try:
                conn, _ = self.socket.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            with conn, conn.makefile('rb') as inp:
                for line in inp:
                    req = json.loads(line)
                    cmd, args = req['execute'], req.get('arguments', {})
                    if cmd == 'guest-ping': result = {}
                    elif cmd == 'guest-exec': result = {'pid': 321}
                    elif cmd == 'guest-exec-status':
                        result = {'exited': self.finished.is_set()}
                        if result['exited']:
                            result.update(exitcode=7, **{'out-data': base64.b64encode(b'guest output').decode()})
                    elif cmd == 'guest-file-open':
                        self.counter += 1
                        self.handles[self.counter] = [args['path'], 0]
                        if args['mode'] == 'wb': self.files[args['path']] = b''
                        result = self.counter
                    elif cmd == 'guest-file-write':
                        key = self.handles[args['handle']][0]
                        chunk = base64.b64decode(args['buf-b64'])
                        self.files[key] += chunk
                        result = {'count': len(chunk)}
                    elif cmd == 'guest-file-read':
                        handle = self.handles[args['handle']]
                        data = self.files[handle[0]]
                        chunk = data[handle[1]:handle[1]+args['count']]
                        handle[1] += len(chunk)
                        result = {'count': len(chunk), 'buf-b64': base64.b64encode(chunk).decode(), 'eof': handle[1] >= len(data)}
                    elif cmd == 'guest-file-close': result = {}
                    else: raise AssertionError(cmd)
                    conn.sendall((json.dumps({'return': result, 'id': req['id']}) + '\n').encode())
    def close(self):
        self.stop.set()
        self.socket.close()
        self.thread.join(timeout=2)

class MCPIntegration(unittest.IsolatedAsyncioTestCase):
    async def test_two_clients_lease_execution_and_transfer(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'tests') as temp:
            vmroot = Path(temp)
            vmdir = vmroot / 'windows-11-English-International'
            vmdir.mkdir()
            guest_socket = vmroot / 'ga.sock'
            guest = FakeGuest(guest_socket)
            params = StdioServerParameters(command=str(ROOT / '.venv/bin/python'), args=[str(ROOT / 'mcp_server/server.py')],
                                           env={'WINDOWS_VM_ROOT': str(vmroot), 'WINDOWS_VM_AGENT_SOCKET': str(guest_socket), 'PATH': os.environ['PATH']})
            try:
                async with stdio_client(params) as (r1, w1), stdio_client(params) as (r2, w2):
                    async with ClientSession(r1, w1) as c1, ClientSession(r2, w2) as c2:
                        await c1.initialize(); await c2.initialize()
                        tools = await c1.list_tools()
                        self.assertIn('execute', {t.name for t in tools.tools})
                        lease = await c1.call_tool('acquire_vm', {'owner': 'first'})
                        self.assertFalse(lease.isError, lease)
                        token = lease.structuredContent['token']
                        conflict = await c2.call_tool('acquire_vm', {'owner': 'second'})
                        self.assertTrue(conflict.isError)
                        denied = await c2.call_tool('release_vm', {'token': 'wrong'})
                        self.assertTrue(denied.isError)
                        ping = await c1.call_tool('guest_ping', {})
                        self.assertEqual(ping.structuredContent['status'], 'ready')
                        source = vmroot / 'sample.bin'
                        data = bytes(range(256)) * 600
                        source.write_bytes(data)
                        put = await c1.call_tool('put_file', {'token': token, 'host_path': str(source), 'guest_path': 'C:\\sample.bin'})
                        self.assertFalse(put.isError, put)
                        self.assertEqual(guest.files['C:\\sample.bin'], data)
                        dest = vmroot / 'result.bin'
                        get = await c1.call_tool('get_file', {'token': token, 'guest_path': 'C:\\sample.bin', 'host_path': str(dest)})
                        self.assertFalse(get.isError, get)
                        self.assertEqual(dest.read_bytes(), data)
                        self.assertTrue((await c1.call_tool('get_file', {'token': token, 'guest_path': 'C:\\sample.bin', 'host_path': str(dest)})).isError)
                        task = asyncio.create_task(c1.call_tool('execute', {'token': token, 'program': 'test.exe', 'timeout_seconds': 1}))
                        await asyncio.sleep(0.25)
                        self.assertTrue((await c2.call_tool('vm_status', {})).isError)
                        run = await task
                        self.assertTrue(run.structuredContent['timed_out'])
                        self.assertTrue((await c1.call_tool('release_vm', {'token': token})).isError)
                        guest.finished.set()
                        status = await c1.call_tool('execution_status', {'token': token})
                        self.assertEqual(status.structuredContent['exitcode'], 7)
                        self.assertEqual(status.structuredContent['stdout'], 'guest output')
                        self.assertFalse((await c1.call_tool('release_vm', {'token': token})).isError)
                        self.assertFalse((await c2.call_tool('acquire_vm', {'owner': 'second'})).isError)
                # The lease persists after both client processes disconnect.
                async with stdio_client(params) as (r3, w3):
                    async with ClientSession(r3, w3) as c3:
                        await c3.initialize()
                        status = await c3.call_tool('vm_status', {})
                        self.assertEqual(status.structuredContent['lease_owner'], 'second')
                        self.assertTrue((await c3.call_tool('acquire_vm', {'owner': 'third'})).isError)
                        self.assertTrue((await c3.call_tool('recover_vm_lease', {'acknowledge_risk': False})).isError)
                        self.assertFalse((await c3.call_tool('recover_vm_lease', {'acknowledge_risk': True})).isError)
                        self.assertFalse((await c3.call_tool('acquire_vm', {'owner': 'third'})).isError)
            finally:
                guest.close()

if __name__ == '__main__':
    unittest.main()
