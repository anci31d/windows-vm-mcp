# Setup Guide: Windows 11 VM for Agent Analysis

This guide describes how to prepare the host environment, install the MCP server and agent skill, set up the required Windows VM files, and run the unattended Windows 11 installation.

---

## 1. Automated Agent Setup (One-Line Installer)

The installer configures the Python virtual environment (`.venv`), registers the `windows-ctf` MCP server in all detected agent CLIs (`agy`, `codex`, `claude`), and links the agent skill (`windows-vm-mcp`).

```bash
curl -fsSL https://raw.githubusercontent.com/anci31d/windows-vm-mcp/master/install.sh | bash
```

Or from a local repository clone:

```bash
./install.sh
```

To view all system dependencies from the installer at any time:

```bash
./install.sh --deps
```

To remove all MCP registrations and agent skills:

```bash
./uninstall.sh
```

---

## 2. System Dependencies

Before running the virtual machine, ensure the host system meets the following requirements:

- **OS / Architecture**: Linux x86_64 with KVM virtualization enabled in BIOS/UEFI.
- **KVM Permissions**: `/dev/kvm` must be accessible by your user (`sudo usermod -aG kvm $USER`).
- **QEMU**: `qemu-system-x86_64` (full system emulator with KVM support).
- **Quickemu**: Quickemu v4.9+ (`quickemu` and `quickget` commands).
- **SPICE Client**: `spicy` (from `spice-client-gtk` or `spice-gtk`).
- **ISO Tools**: `genisoimage` or `mkisofs` (from `genisoimage` or `cdrtools`, used to build ISOs).
- **Python**: Python 3.10+ with standard library venv (or `uv`).
- **Git**: `git` client.

### Package Installation Commands

- **Ubuntu / Debian**:
  ```bash
  sudo apt update
  sudo apt install -y qemu-system-x86 quickemu spicy genisoimage python3 python3-venv git
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
> If you just added your user to the `kvm` group, log out and log back in (or restart your session) for group permissions to apply.

---

## 3. Required VM Directory Layout

The virtual machine is configured by `windows-11-English-International.conf`. All VM runtime and media files reside in the subdirectory `windows-11-English-International/`:

```text
windows-11-English-International/
├── windows-11.iso          # Windows 11 x64 installer ISO
├── virtio-win.iso          # Red Hat / Fedora VirtIO drivers + QEMU guest agent
├── tools.iso               # x64dbg.zip and install-tools.ps1
├── unattended/
│   └── autounattend.xml    # Answer file for unattended setup
├── unattended.iso          # ISO containing autounattend.xml
└── disk.qcow2              # 80 GiB thin-provisioned virtual disk (created on first boot)
```

---

## 4. Step-by-Step Media & File Preparation

### Step 4.1: Download Windows 11 ISO & VirtIO ISO

#### Method A: Using `quickget` (Recommended)

Quickemu provides `quickget`, which automatically downloads the official Microsoft Windows 11 ISO, downloads the VirtIO drivers, generates `unattended/autounattend.xml`, and creates `unattended.iso`:

```bash
mkdir -p windows-11-English-International
cd windows-11-English-International
quickget windows 11
cd ..
```

This downloads:
- `windows-11.iso` (~9 GiB)
- `virtio-win.iso` (~800 MiB)
- Generates `unattended/autounattend.xml` and builds `unattended.iso`.

#### Method B: Manual Download

If downloading manually or copying from an existing archive:
1. **Windows 11 ISO**: Download Windows 11 (English International, x64) from Microsoft's official download page. Save it as `windows-11-English-International/windows-11.iso`.
2. **VirtIO ISO**: Download the latest stable VirtIO driver ISO from the Fedora project:
   ```bash
   curl -fLo windows-11-English-International/virtio-win.iso \
     https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
   ```
3. **Unattended Answer File (`autounattend.xml`)**:
   The repository already includes a complete, pre-configured answer file at `windows-11-English-International/unattended/autounattend.xml`.
   - **Editing is NOT required**: it is completely ready out of the box. It automatically partitions the virtual drive, selects Windows Pro, enables auto-logon for the user `Quickemu` (password: `quickemu`), disables UAC, and installs the QEMU Guest Agent and VirtIO drivers.
   - **Optional customization**: If you wish to change the username or password, modify the `<UserAccounts>` and `<AutoLogon>` tags inside `autounattend.xml`.
   
   Build `unattended.iso`:
   ```bash
   genisoimage -quiet -J -o windows-11-English-International/unattended.iso windows-11-English-International/unattended/
   ```

---

### Step 4.2: Build `tools.iso`

The VM configuration attaches a CD-ROM drive containing `tools.iso` (`extra_args="-drive media=cdrom,index=3,file=windows-11-English-International/tools.iso,readonly=on"`). This provides x64dbg and the tool extraction script directly inside the guest without network access.

Run the project builder:

```bash
bin/build-tools-iso
```

This packages `tools/x64dbg.zip` and `tools/install-tools.ps1` into `windows-11-English-International/tools.iso`.

---

## 5. First Boot & Unattended Windows Installation

Once the files (`windows-11.iso`, `virtio-win.iso`, `unattended.iso`, `tools.iso`) are in place, start the VM:

### On a local desktop (with SPICE GUI):
```bash
bin/winvm gui
```

### On a headless remote server (VPS / SSH):
```bash
bin/winvm headless
```

### What happens automatically:
1. Quickemu allocates the 80 GiB thin-provisioned disk (`disk.qcow2`).
2. Windows Setup boots using `autounattend.xml`.
3. Partitions the disk and loads the VirtIO storage drivers.
4. Installs Windows 11 Pro without prompting.
5. Skips OOBE setup and privacy questions.
6. Creates local administrator `Quickemu` (password: `quickemu`) with automatic logon.
7. Executes `FirstLogonCommands`: automatically installs the **QEMU Guest Agent** (`qemu-ga-x86_64.msi`) and video driver (`viogpudo.inf`).

The entire install takes approximately 5–15 minutes depending on CPU and disk performance.

---

## 6. Verification & Guest Operations

### 6.1 Check Guest Agent Connectivity
Once installation finishes, test communication through the QEMU guest agent socket:

```bash
bin/win-agent ping
```
When ready, the command returns successfully.

### 6.2 Run Commands in the Guest
```bash
bin/win-agent run 'C:\Windows\System32\cmd.exe' /c ver
```

### 6.3 Transfer Files
```bash
# Push sample to guest Desktop
bin/win-agent put ./malware.exe 'C:\Users\Quickemu\Desktop\sample.exe'

# Retrieve analysis output
bin/win-agent get 'C:\Users\Quickemu\Desktop\report.txt' ./report.txt
```

### 6.4 Install x64dbg Inside Windows
In Windows, the `tools.iso` drive contains `install-tools.ps1`. You can trigger installation remotely via `bin/win-agent`:

```bash
bin/win-agent run 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' \
  -ExecutionPolicy Bypass -Command \
  'Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path (Join-Path $_.Root "install-tools.ps1") } | ForEach-Object { & (Join-Path $_.Root "install-tools.ps1") }'
```
This extracts x64dbg to `C:\CTF-Tools\x64dbg`.

---

## 7. Graceful Shutdown & Clean Backups

Always shut down the VM cleanly before creating backups or snapshots:

```bash
bin/winvm poweroff
```

### Creating a Golden Snapshot:
Create a backup of the powered-off VM state:
```bash
cp windows-11-English-International/disk.qcow2 windows-11-English-International/disk.qcow2.clean
cp windows-11-English-International/OVMF_VARS.fd windows-11-English-International/OVMF_VARS.fd.clean
```
To reset the VM after a malware or CTF analysis run:
```bash
bin/winvm poweroff
cp windows-11-English-International/disk.qcow2.clean windows-11-English-International/disk.qcow2
cp windows-11-English-International/OVMF_VARS.fd.clean windows-11-English-International/OVMF_VARS.fd
```
