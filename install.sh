#!/bin/bash
# ============================================================
#   ReconBay Installer
#   Author : Nipun Dilshan
#   Purpose: Install all dependencies for ReconBay
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

CONFIG_DIR="$HOME/.reconbay"
CONFIG_FILE="$CONFIG_DIR/config"

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'BANNER'
 ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗██████╗  █████╗ ██╗   ██╗
 ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔══██╗╚██╗ ██╔╝
 ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║██████╔╝███████║ ╚████╔╝
 ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║██╔══██╗██╔══██║  ╚██╔╝
 ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║██████╔╝██║  ██║   ██║
 ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝   ╚═╝
BANNER
    echo -e "${NC}"
    echo -e "${MAGENTA}${BOLD}        ★  Ultimate Recon Framework  |  Author: Nipun Dilshan  ★${NC}"
    echo -e "${YELLOW}        ════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                        [ INSTALLER v1.0 ]${NC}"
    echo ""
}

log_info()    { echo -e "${BLUE}[*]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[✔]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✘]${NC} $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}══════════ $1 ══════════${NC}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Please run the installer with sudo: sudo bash install.sh"
        exit 1
    fi
}

install_go() {
    log_section "Go Language"
    if command -v go &>/dev/null; then
        log_ok "Go already installed: $(go version)"
        return
    fi
    log_info "Installing Go..."
    GO_VERSION="1.22.3"
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && GOARCH="amd64" || GOARCH="arm64"
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    log_ok "Go $GO_VERSION installed"
}

install_go_tool() {
    local name="$1"
    local pkg="$2"
    if command -v "$name" &>/dev/null; then
        log_ok "$name already installed"
    else
        log_info "Installing $name..."
        go install "$pkg" 2>/dev/null
        if command -v "$name" &>/dev/null; then
            log_ok "$name installed"
        else
            # try copying from GOPATH
            cp "$HOME/go/bin/$name" /usr/local/bin/ 2>/dev/null && log_ok "$name installed" || log_warn "$name install failed — install manually"
        fi
    fi
}

install_apt_tools() {
    log_section "System Packages"
    apt-get update -qq
    for pkg in curl wget git jq nmap dnsutils python3 python3-pip unzip; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_ok "$pkg already present"
        else
            log_info "Installing $pkg..."
            apt-get install -y -qq "$pkg" && log_ok "$pkg installed" || log_warn "Failed: $pkg"
        fi
    done
}

install_go_tools() {
    log_section "Go-based Recon Tools"
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    GOPATH=${GOPATH:-$HOME/go}

    install_go_tool "subfinder"          "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    install_go_tool "httpx"              "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    install_go_tool "dnsx"              "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    install_go_tool "katana"            "github.com/projectdiscovery/katana/cmd/katana@latest"
    install_go_tool "nuclei"            "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    install_go_tool "chaos"             "github.com/projectdiscovery/chaos-client/cmd/chaos@latest"
    install_go_tool "assetfinder"       "github.com/tomnomnom/assetfinder@latest"
    install_go_tool "waybackurls"       "github.com/tomnomnom/waybackurls@latest"
    install_go_tool "gau"               "github.com/lc/gau/v2/cmd/gau@latest"
    install_go_tool "anew"              "github.com/tomnomnom/anew@latest"
    install_go_tool "puredns"           "github.com/d3mondev/puredns/v2@latest"
    install_go_tool "github-subdomains" "github.com/gwen001/github-subdomains@latest"
    install_go_tool "gowitness"         "github.com/sensepost/gowitness@latest"
    install_go_tool "naabu"             "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    install_go_tool "tlsx"              "github.com/projectdiscovery/tlsx/cmd/tlsx@latest"
    install_go_tool "shuffledns"        "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
    install_go_tool "uncover"           "github.com/projectdiscovery/uncover/cmd/uncover@latest"

    # Symlink httpx to httpx-toolkit if not present
    if ! command -v httpx-toolkit &>/dev/null && command -v httpx &>/dev/null; then
        ln -sf "$(which httpx)" /usr/local/bin/httpx-toolkit
        log_ok "httpx-toolkit symlink created"
    fi
}

install_python_tools() {
    log_section "Python Tools"
    pip3 install -q theHarvester 2>/dev/null && log_ok "theHarvester installed" || log_warn "theHarvester failed — install manually"
}

fetch_resolvers() {
    log_section "DNS Resolvers"
    RESOLVERS_PATH="$CONFIG_DIR/resolvers.txt"
    if [[ -f "$RESOLVERS_PATH" ]] && [[ $(wc -l < "$RESOLVERS_PATH") -gt 100 ]]; then
        log_ok "Resolvers already present ($(wc -l < "$RESOLVERS_PATH") entries)"
    else
        log_info "Fetching fresh public resolvers..."
        curl -s "https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt" -o "$RESOLVERS_PATH" 2>/dev/null
        if [[ -s "$RESOLVERS_PATH" ]]; then
            log_ok "Downloaded $(wc -l < "$RESOLVERS_PATH") resolvers"
        else
            # Fallback minimal list
            cat > "$RESOLVERS_PATH" << 'RESOLVERS'
8.8.8.8
8.8.4.4
1.1.1.1
1.0.0.1
9.9.9.9
149.112.112.112
208.67.222.222
208.67.220.220
64.6.64.6
77.88.8.8
RESOLVERS
            log_warn "Using fallback resolvers (10 entries)"
        fi
    fi
}

collect_tokens() {
    log_section "API Tokens & Configuration"
    mkdir -p "$CONFIG_DIR"

    # Load existing config if present
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

    echo ""
    echo -e "${BOLD}${YELLOW}  GitHub tokens dramatically improve subdomain discovery.${NC}"
    echo -e "  Create tokens at: ${CYAN}https://github.com/settings/tokens${NC}"
    echo -e "  Required scope  : ${GREEN}read:org, public_repo${NC}"
    echo ""

    # --- GitHub tokens (support multiple) ---
    echo -e "${BOLD}  Current GitHub tokens: ${GREEN}${GITHUB_TOKENS:-none}${NC}"
    read -rp "  Enter GitHub token(s) [comma-separated, Enter to keep existing]: " INPUT_TOKENS
    if [[ -n "$INPUT_TOKENS" ]]; then
        GITHUB_TOKENS="$INPUT_TOKENS"
    fi

    # --- Chaos API key ---
    echo ""
    echo -e "  ${BOLD}Chaos (ProjectDiscovery) API key${NC} — https://chaos.projectdiscovery.io"
    echo -e "  Current: ${GREEN}${CHAOS_KEY:-none}${NC}"
    read -rp "  Enter Chaos API key [Enter to keep existing]: " INPUT_CHAOS
    [[ -n "$INPUT_CHAOS" ]] && CHAOS_KEY="$INPUT_CHAOS"

    # --- Shodan API key ---
    echo ""
    echo -e "  ${BOLD}Shodan API key${NC} — https://account.shodan.io"
    echo -e "  Current: ${GREEN}${SHODAN_KEY:-none}${NC}"
    read -rp "  Enter Shodan API key [Enter to keep/skip]: " INPUT_SHODAN
    [[ -n "$INPUT_SHODAN" ]] && SHODAN_KEY="$INPUT_SHODAN"

    # Save config
    cat > "$CONFIG_FILE" << CONF
# ReconBay Configuration — Author: Nipun Dilshan
GITHUB_TOKENS="${GITHUB_TOKENS}"
CHAOS_KEY="${CHAOS_KEY}"
SHODAN_KEY="${SHODAN_KEY}"
CONF
    chmod 600 "$CONFIG_FILE"
    log_ok "Configuration saved to $CONFIG_FILE"
}

make_executable() {
    log_section "Finalizing"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    chmod +x "$SCRIPT_DIR/reconbay.sh"

    # Create global symlink
    if [[ -f "$SCRIPT_DIR/reconbay.sh" ]]; then
        ln -sf "$SCRIPT_DIR/reconbay.sh" /usr/local/bin/reconbay
        log_ok "reconbay command available globally"
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║        ReconBay Installation Complete! ✔          ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Run the tool:${NC}  ${BOLD}reconbay${NC}  or  ${BOLD}bash reconbay.sh${NC}"
    echo -e "  ${CYAN}Config file :${NC}  $CONFIG_FILE"
    echo -e "  ${CYAN}Resolvers   :${NC}  $CONFIG_DIR/resolvers.txt"
    echo ""
    echo -e "${YELLOW}  Happy Hacking! — Nipun Dilshan${NC}"
    echo ""
}

# ─── MAIN ───────────────────────────────────────────────────
print_banner
check_root
install_apt_tools
install_go
install_go_tools
install_python_tools
fetch_resolvers
collect_tokens
make_executable
print_summary
