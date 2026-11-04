# Setup

This repository contains code, documentation, the Codex skill, and a Quickemu configuration template. It does not contain Windows media, VM disks, firmware state, or Sysinternals archives.

1. Install Quickemu, QEMU/KVM, SPICE, and `spicy` using the official instructions for your distribution.
2. Download a Windows 11 ISO from Microsoft and the VirtIO driver ISO from the Fedora VirtIO project. Keep both outside git.
3. Copy `examples/windows-11-ctf.conf` to a local VM directory, replace the ISO placeholders, create the disk with Quickemu, and review the unattended answer file before booting.
4. Run the unattended installation and install the VirtIO guest agent in Windows. Confirm that `bin/win-agent ping` returns successfully.
5. Register the server with a stdio MCP client using the absolute path to `bin/windows-vm-mcp`; see [MCP.md](MCP.md). The server root can be overridden with `WINDOWS_VM_ROOT`, and the guest-agent socket with `WINDOWS_VM_AGENT_SOCKET`.

The optional tools ISO should contain `tools/x64dbg.zip` and `tools/install-tools.ps1`. Run the script in Windows to extract x64dbg. It asks before downloading Sysinternals from Microsoft's official URL; the archive is never distributed by this project.

Update tool material manually: replace `tools/x64dbg.zip` with a current upstream snapshot and update its checksum in the documentation; run the installer again to obtain the current Sysinternals release from Microsoft.

The MIT license covers this project's code and skill. x64dbg remains third-party material under its upstream terms; Microsoft software and Windows licensing remain the user's responsibility.
