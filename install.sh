#!/usr/bin/env bash
set -euo pipefail

# Windows VM MCP & Skill One-Line Installer
# Repository: https://github.com/anci31d/windows-vm-mcp

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$*"
}

success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$*"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
}

print_full_dependencies() {
    echo -e "\n${BOLD}=== Full List of Dependencies ===${NC}"
    echo -e "${BOLD}1. Host & Virtualization (Required):${NC}"
    echo "  - OS:           Linux x86_64"
    echo "  - KVM:          /dev/kvm enabled in BIOS/UEFI and writable by user ($USER)"
    echo "  - QEMU:         qemu-system-x86_64 (emulator with KVM support)"
    echo "  - Quickemu:     quickemu (CLI VM orchestrator, v4.9+)"
    echo "  - SPICE client: spicy (from spice-client-gtk / spice-gtk)"
    echo
    echo -e "${BOLD}2. Runtime & Tools (Required):${NC}"
    echo "  - Python:       python3 (version 3.10+) with python3-venv"
    echo "  - Git:          git"
    echo
    echo -e "${BOLD}3. Optional / Recommended:${NC}"
    echo "  - Fast Python:  uv (replaces python3-venv for near-instant setups)"
    echo "  - Node / npx:   nodejs & npx (for universal skill registration)"
    echo "  - AI Agents:    agy (Antigravity), codex (Codex CLI), claude (Claude Code)"
    echo "  - VM Media:     Windows 11 ISO + VirtIO ISO (downloadable via 'quickget windows 11')"
    echo
    echo -e "${BOLD}Install commands for your distribution:${NC}"
    echo -e "  ${BOLD}Ubuntu / Debian:${NC}"
    echo "    sudo apt update"
    echo "    sudo apt install -y qemu-system-x86 quickemu spicy python3 python3-venv git"
    echo "    sudo usermod -aG kvm \$USER"
    echo
    echo -e "  ${BOLD}Arch Linux:${NC}"
    echo "    sudo pacman -S --needed qemu-desktop quickemu spice-gtk python git"
    echo "    sudo usermod -aG kvm \$USER"
    echo
    echo -e "  ${BOLD}Fedora:${NC}"
    echo "    sudo dnf install -y qemu-kvm quickemu spice-gtk python3 git"
    echo "    sudo usermod -aG kvm \$USER"
    echo -e "  ${YELLOW}* Note: log out and back in after adding your user to the kvm group.${NC}\n"
}

AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_YES=true ;;
        --deps|--dependencies)
            print_full_dependencies
            exit 0
            ;;
        -h|--help)
            echo "Usage: $0 [-y|--yes] [--deps|--dependencies] [-h|--help]"
            echo "  -y, --yes          Non-interactive mode (default answers)"
            echo "  --deps             Display full list of dependencies and package manager commands"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
    esac
done

prompt_user() {
    local prompt_msg="$1"
    local default_val="$2"
    local ans=""
    if [[ "$AUTO_YES" == "true" ]]; then
        echo "$default_val"
        return
    fi
    if [ -t 0 ]; then
        read -r -p "$prompt_msg" ans || ans="$default_val"
    elif [ -e /dev/tty ] && [ -r /dev/tty ]; then
        read -r -p "$prompt_msg" ans < /dev/tty || ans="$default_val"
    else
        ans="$default_val"
    fi
    echo "${ans:-$default_val}"
}

# 1. Determine Repository Directory
if [[ -f "./bin/windows-vm-mcp" && -f "./requirements.txt" ]]; then
    REPO_DIR="$(cd . && pwd)"
    info "Installing from current repository: $REPO_DIR"
elif [[ -n "${WINDOWS_VM_DIR:-}" && -f "$WINDOWS_VM_DIR/bin/windows-vm-mcp" ]]; then
    REPO_DIR="$(cd "$WINDOWS_VM_DIR" && pwd)"
    info "Installing from WINDOWS_VM_DIR: $REPO_DIR"
else
    BRANCH="${WINDOWS_VM_BRANCH:-feature/one-line-installer}"
    DEFAULT_TARGET="${WINDOWS_VM_DIR:-$HOME/.local/share/windows-vm-mcp}"
    if [[ -d "$DEFAULT_TARGET/.git" ]]; then
        info "Updating existing repository at $DEFAULT_TARGET..."
        git -C "$DEFAULT_TARGET" fetch origin "$BRANCH"
        git -C "$DEFAULT_TARGET" checkout "$BRANCH"
        git -C "$DEFAULT_TARGET" pull --ff-only origin "$BRANCH"
    else
        info "Cloning windows-vm-mcp ($BRANCH) to $DEFAULT_TARGET..."
        mkdir -p "$(dirname "$DEFAULT_TARGET")"
        git clone -b "$BRANCH" https://github.com/anci31d/windows-vm-mcp.git "$DEFAULT_TARGET"
    fi
    REPO_DIR="$DEFAULT_TARGET"
fi

cd "$REPO_DIR"

# 2. Prerequisites Check
info "Checking system prerequisites..."
preq_has_issues=false
os_type="$(uname -s)"
arch_type="$(uname -m)"

if [[ "$os_type" != "Linux" || "$arch_type" != "x86_64" ]]; then
    warn "This VM environment is designed for Linux x86_64 (KVM). Detected: $os_type $arch_type."
    preq_has_issues=true
fi

if [[ -e /dev/kvm ]]; then
    if [[ -w /dev/kvm ]]; then
        info "KVM hardware acceleration is available and writable (/dev/kvm)."
    else
        warn "/dev/kvm exists but is not writable by $USER. Run: sudo usermod -aG kvm $USER (and re-login)."
        preq_has_issues=true
    fi
else
    warn "/dev/kvm not found! Ensure hardware virtualization (VT-x/AMD-V) is enabled in BIOS/UEFI."
    preq_has_issues=true
fi

missing_pkgs=()
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    missing_pkgs+=("qemu-system-x86_64")
fi
if ! command -v quickemu >/dev/null 2>&1; then
    missing_pkgs+=("quickemu")
fi
if ! command -v spicy >/dev/null 2>&1; then
    missing_pkgs+=("spicy (spice-client-gtk)")
fi
if ! command -v python3 >/dev/null 2>&1; then
    missing_pkgs+=("python3")
fi
if ! command -v git >/dev/null 2>&1; then
    missing_pkgs+=("git")
fi

if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
    warn "Missing required/recommended packages: ${missing_pkgs[*]}"
    preq_has_issues=true
fi

if [[ "$preq_has_issues" == "true" ]]; then
    warn "System prerequisite check encountered warnings or missing components."
    print_full_dependencies
fi

# 3. Setup Python Virtual Environment
info "Configuring Python virtual environment..."
if command -v uv >/dev/null 2>&1; then
    info "Using uv for fast environment setup..."
    uv venv --allow-existing "$REPO_DIR/.venv"
    uv pip install --python "$REPO_DIR/.venv/bin/python" -r "$REPO_DIR/requirements.txt"
else
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python 3 is required but not found in PATH."
        exit 1
    fi
    python3 -m venv "$REPO_DIR/.venv"
    "$REPO_DIR/.venv/bin/pip" install --quiet -r "$REPO_DIR/requirements.txt"
fi

chmod +x "$REPO_DIR/bin/"*
success "Python virtual environment ready."

# 4. MCP Server Registration (Skip if harness CLI not found)
MCP_EXEC="$REPO_DIR/bin/windows-vm-mcp"
registered_count=0

if command -v agy >/dev/null 2>&1; then
    info "Registering MCP server in Antigravity (agy)..."
    agy mcp add windows-ctf "$MCP_EXEC"
    registered_count=$((registered_count + 1))
    success "Registered with Antigravity (agy)."
else
    info "Antigravity CLI (agy) not found; skipping agy registration."
fi

if command -v codex >/dev/null 2>&1; then
    info "Registering MCP server in Codex..."
    codex mcp add windows-ctf -- "$MCP_EXEC"
    registered_count=$((registered_count + 1))
    success "Registered with Codex."
else
    info "Codex CLI not found; skipping codex registration."
fi

if command -v claude >/dev/null 2>&1; then
    info "Registering MCP server in Claude Code..."
    claude mcp remove -s user windows-ctf >/dev/null 2>&1 || true
    claude mcp add -s user windows-ctf -- "$MCP_EXEC"
    registered_count=$((registered_count + 1))
    success "Registered with Claude Code."
else
    info "Claude CLI not found; skipping claude registration."
fi

# 5. Agent Skill Installation
info "Installing agent skill (windows-vm-mcp)..."
if command -v npx >/dev/null 2>&1; then
    info "Syncing skill via npx skills..."
    npx -y skills add "$REPO_DIR" -g -y --all >/dev/null 2>&1 || true
fi

SKILL_SRC="$REPO_DIR/skills/windows-vm-mcp"
if [[ -d "$SKILL_SRC" ]]; then
    for skill_dir in "$HOME/.gemini/skills" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
        parent_dir="$(dirname "$skill_dir")"
        if [[ -d "$parent_dir" ]]; then
            mkdir -p "$skill_dir"
            ln -sfn "$SKILL_SRC" "$skill_dir/windows-vm-mcp"
            info "Linked skill to $skill_dir/windows-vm-mcp"
        fi
    done
fi
success "Agent skill installation completed."

# 6. Run Self-Verification Tests
info "Running self-verification tests..."
"$REPO_DIR/.venv/bin/python" -m unittest discover -s "$REPO_DIR/tests" -v
success "Self-verification tests passed!"

# 7. Interactive ISO Download Prompt
vm_dir="$REPO_DIR/windows-11-English-International"
windows_iso="$vm_dir/windows-11.iso"
virtio_iso="$vm_dir/virtio-win.iso"

if [[ ! -f "$windows_iso" || ! -f "$virtio_iso" ]]; then
    echo
    answer=$(prompt_user "Windows 11 VM ISOs not found. Download now using quickget? [y/N]: " "n")

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        if command -v quickget >/dev/null 2>&1; then
            info "Downloading Windows 11 with quickget..."
            mkdir -p "$vm_dir"
            (cd "$vm_dir" && quickget windows 11)
            success "ISO download finished."
        else
            warn "quickget command not found. Install quickemu first, then run 'quickget windows 11'."
        fi
    else
        info "Skipped ISO download. You can run 'quickget windows 11' later in $vm_dir."
    fi
else
    info "Windows 11 ISO files are already present."
fi

# 8. Finished
echo
success "windows-vm-mcp successfully installed!"
echo -e "  Location:      ${BOLD}$REPO_DIR${NC}"
echo -e "  MCP binary:    ${BOLD}$MCP_EXEC${NC}"
echo -e "  Registrations: $registered_count agent(s) configured"
echo -e "  To uninstall:  run ${BOLD}$REPO_DIR/uninstall.sh${NC}\n"
