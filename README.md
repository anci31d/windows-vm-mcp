# Windows 11 CTF VM

Windows 11 x64, English International, Quickemu. The VM uses 4 vCPUs, 4 GiB RAM, an 80 GiB thin-provisioned disk and no guest network. The first installation uses Quickemu's unattended answer file, which accepts the Windows license, selects Windows Pro and creates the local administrator `Quickemu` with the default password `quickemu` and automatic login. This is a disposable lab account, not an activated Windows license. UAC is disabled by the Quickemu answer file. Review `windows-11-English-International/unattended/autounattend.xml` before first boot.

## One-Line Install

Install and register the VM MCP server and agent skill in one line across supported AI agents (Antigravity, Codex, Claude Code):

```bash
curl -fsSL https://raw.githubusercontent.com/anci31d/windows-vm-mcp/master/install.sh | bash
```

Or if you have already cloned the repository:

```bash
./install.sh
```

To remove all MCP registrations and agent skills:

```bash
./uninstall.sh
```

The installer automatically detects installed agent CLIs (`agy`, `codex`, `claude`), registers the `windows-ctf` MCP server, links the `windows-vm-mcp` skill, builds the Python virtual environment, and verifies the installation with test suite execution.

## System Dependencies

| Component | Requirement | Package (Ubuntu/Debian) | Package (Arch Linux) | Package (Fedora) |
|---|---|---|---|---|
| **OS** | Linux x86_64 with KVM (`/dev/kvm`) | `qemu-system-x86` | `qemu-desktop` | `qemu-kvm` |
| **VM Launcher** | Quickemu (v4.9+) | `quickemu` | `quickemu` | `quickemu` |
| **SPICE Viewer** | `spicy` (for socket & GUI) | `spicy` (`spice-client-gtk`) | `spice-gtk` | `spice-gtk` |
| **ISO Tool** | `mkisofs` / `genisoimage` (builds `tools.iso`) | `genisoimage` | `cdrtools` | `genisoimage` |
| **Python** | Python 3.10+ & venv | `python3 python3-venv` | `python` | `python3` |
| **VCS** | Git | `git` | `git` | `git` |
| **Fast venv** *(opt)* | `uv` | [astral.sh/uv](https://astral.sh/uv) | `uv` | `uv` |
| **Multi-agent skills** *(opt)* | Node.js / `npx` | `nodejs npm` | `nodejs npm` | `nodejs npm` |

### Quick Package Installation

- **Ubuntu / Debian**:
  ```bash
  sudo apt update && sudo apt install -y qemu-system-x86 quickemu spicy genisoimage python3 python3-venv git
  sudo usermod -aG kvm $USER
  ```
- **Arch Linux**:
  ```bash
  sudo pacman -S --needed qemu-desktop quickemu spice-gtk cdrtools python git
  sudo usermod -aG kvm $USER
  ```
- **Fedora**:
  ```bash
  sudo dnf install -y qemu-kvm quickemu spice-gtk genisoimage python3 git
  sudo usermod -aG kvm $USER
  ```

> [!NOTE]
> Ensure `/dev/kvm` is enabled in your BIOS/UEFI. After adding your user to the `kvm` group, log out and back in for permissions to take effect.

## Documentation index

- [SETUP.md](SETUP.md) - public setup guide for Quickemu, Windows media, VirtIO, the guest agent, MCP clients, and tool updates.
- [MCP.md](MCP.md) - MCP registration, lease workflow, file transfer, execution, and recovery.
- [tools/README.md](tools/README.md) - third-party tool provenance, licensing boundaries, and update policy.
- [examples/windows-11-ctf.conf](examples/windows-11-ctf.conf) - portable Quickemu configuration template with local media placeholders.

The repository also includes [requirements.txt](requirements.txt), which lists the Python dependency needed by the MCP server.

Run commands from this directory:

```bash
bin/winvm gui       # Start or attach using the local SPICE viewer
bin/winvm headless  # Start without a viewer; SPICE remains on a local Unix socket
bin/winvm poweroff  # Request a graceful shutdown
bin/win-agent ping
bin/win-agent run 'C:\Windows\System32\cmd.exe' /c ver
bin/win-agent put ./sample.exe 'C:\Users\Quickemu\Desktop\sample.exe'
bin/win-agent get 'C:\Users\Quickemu\Desktop\result.txt' ./result.txt
```

`win-agent` uses the QEMU guest agent socket, which is enabled in SPICE mode and requires the VirtIO guest agent service to be installed and running. Commands run in the guest agent service's security context, not in the interactive desktop; GUI programs may not be visible. `run --timeout 60` changes the wait limit, but a timeout does not stop the guest process. The guest agent may truncate captured output; the client reports this. `get` refuses to overwrite an existing host file; `put` overwrites the guest destination. Socket access grants control of the guest to local processes that can access it.

The network is disabled for analysis, and host directories are not automatically shared. GUI integrations such as clipboard sharing require additional SPICE guest tools, which are not included here. Do not treat a VM as a complete security boundary for hostile samples. Take a clean backup with the VM powered off before testing; preserve the disk, EFI variables and TPM state together. Quickemu's disk snapshots alone do not necessarily capture firmware and TPM state. Windows activation and tool licenses remain the user's responsibility.

For shared access from MCP-compatible agents, see [MCP.md](MCP.md) and [SETUP.md](SETUP.md). MCP registration is separate for each client; its process must have filesystem and KVM permissions. The MCP lease coordinates only operations through the server, not direct Quickemu or guest-agent commands.

Assistant-only browser files, caches and unused download fragments are kept in `assistant-work/`. Project configuration, tools, VM data and the Python environment remain in place.

On hosts without `/dev/dri/renderD128`, the configuration explicitly sets `gl="off"`; this keeps SPICE/QEMU usable without GPU rendering. For long-lived runs, start `bin/winvm headless` from the repository root and connect to the generated local SPICE socket with `spicy`.
