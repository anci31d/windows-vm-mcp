#!/usr/bin/env bash
set -euo pipefail

# Windows VM MCP & Skill Uninstaller
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

AUTO_YES=false
for arg in "$@"; do
    case "$arg" in
        -y|--yes) AUTO_YES=true ;;
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

echo -e "${BOLD}=== Windows VM MCP & Agent Skill Uninstaller ===${NC}\n"

# 1. Deregister MCP from Agents
if command -v agy >/dev/null 2>&1; then
    info "Removing MCP server from Antigravity (agy)..."
    agy mcp remove windows-ctf 2>/dev/null || true
    success "Removed from agy."
fi

if command -v codex >/dev/null 2>&1; then
    info "Removing MCP server from Codex..."
    codex mcp remove windows-ctf 2>/dev/null || true
    success "Removed from codex."
fi

if command -v claude >/dev/null 2>&1; then
    info "Removing MCP server from Claude Code..."
    claude mcp remove -s user windows-ctf 2>/dev/null || true
    success "Removed from claude."
fi

# 2. Remove Skills
info "Removing agent skills..."
if command -v npx >/dev/null 2>&1; then
    npx -y skills remove windows-vm-mcp -g -y 2>/dev/null || true
fi

for skill_dir in "$HOME/.gemini/skills/windows-vm-mcp" "$HOME/.claude/skills/windows-vm-mcp" "$HOME/.codex/skills/windows-vm-mcp"; do
    if [[ -L "$skill_dir" || -d "$skill_dir" ]]; then
        rm -rf "$skill_dir"
        info "Removed $skill_dir"
    fi
done

success "Agent skills removed."

# 3. Optional cleanup of virtualenv
ROOT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
if [[ -d "$ROOT_DIR/.venv" ]]; then
    answer=$(prompt_user "Remove Python virtual environment ($ROOT_DIR/.venv)? [y/N]: " "n")
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$ROOT_DIR/.venv"
        success "Removed .venv."
    fi
fi

echo
success "Uninstallation completed. VM disks and project files remain intact."
