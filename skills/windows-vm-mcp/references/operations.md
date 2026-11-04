# Operations reference

## Registering a client

For Codex, the local server is registered globally with:

```bash
codex mcp add windows-ctf -- /absolute/path/to/windows-vm-mcp/bin/windows-vm-mcp
```

Other MCP clients need a stdio server whose command is the absolute path to `bin/windows-vm-mcp` and whose working user can access the VM directory. A client sandbox may need explicit access to the VM directory, the host files passed to `put_file`/`get_file`, QEMU/KVM resources, and the Unix guest-agent socket. MCP registration alone does not mount a share or grant filesystem privileges.

## Launching the VM manually

When a client cannot keep a child process alive, start the VM from a terminal:

```bash
cd /path/to/windows-vm-mcp
setsid -f sh -c 'exec bin/winvm headless' > vm-launch.log 2>&1
```

Open the GUI with:

```bash
spicy --uri='spice+unix:///path/to/windows-vm-mcp/windows-11-English-International/windows-11-English-International.sock'
```

The configuration sets `gl="off"` because some hosts do not expose `/dev/dri/renderD128`.

## Safety and recovery

A guest-agent timeout can mean the process started but its response was lost. First poll `execution_status`; do not immediately retry a potentially destructive command. If the PID is unknown after a connection failure, inspect the guest GUI and recover the lease only after accepting the risk.

The VM currently has networking disabled. Dynamic analysis is still not a complete security boundary. Avoid host directory sharing for untrusted samples and use a clean powered-off backup for repeated experiments.

## Verification boundary

The MCP path has been verified against the installed Windows guest with `guest_ping` and `cmd.exe /c ver`, returning Windows 11 build `10.0.26300.9457`. The test suite also verifies two-client lease coordination, file transfer, timeout handling, and abandoned-lease recovery with a fake guest agent. It does not prove that every MCP client's sandbox grants the required host permissions.
