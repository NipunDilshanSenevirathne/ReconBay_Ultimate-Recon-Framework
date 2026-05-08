#!/bin/bash
# ============================================================
#   ReconBay — Ultimate Recon Framework
#   Author  : Nipun Dilshan
#   Version : 2.0
#   License : For authorized penetration testing only
# ============================================================

# ── Colors & Styles ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Configuration ────────────────────────────────────────────
CONFIG_DIR="$HOME/.reconbay"
CONFIG_FILE="$CONFIG_DIR/config"
RESOLVERS="$CONFIG_DIR/resolvers.txt"
START_TIME=$(date +%s)
VERSION="2.0"

# ── Load saved config ─────────────────────────────────────────
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# ── Logging helpers ──────────────────────────────────────────
ts()         { date '+%H:%M:%S'; }
log_info()   { echo -e "${BLUE}[$(ts)][*]${NC} $1"; }
log_ok()     { echo -e "${GREEN}[$(ts)][✔]${NC} $1"; }
log_warn()   { echo -e "${YELLOW}[$(ts)][!]${NC} $1"; }
log_error()  { echo -e "${RED}[$(ts)][✘]${NC} $1"; }
log_data()   { echo -e "${MAGENTA}[$(ts)][+]${NC} $1"; }
log_skip()   { echo -e "${DIM}[$(ts)][-] $1${NC}"; }

section() {
    echo ""
    echo -e "${CYAN}${BOLD}  ┌──────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}  │  $1$(printf '%*s' $((46 - ${#1})) '')│${NC}"
    echo -e "${CYAN}${BOLD}  └──────────────────────────────────────────────┘${NC}"
    echo ""
}

count_lines() { [[ -f "$1" ]] && wc -l < "$1" || echo 0; }
tool_ok()     { command -v "$1" &>/dev/null; }

# ── Banner ────────────────────────────────────────────────────
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
    echo -e "${MAGENTA}${BOLD}      ★  Ultimate Recon Framework  |  Author: Nipun Dilshan  ★${NC}"
    echo -e "${YELLOW}      ════════════════════════════════════════════════════${NC}"
    printf "      ${DIM}Version: %-10s Platform: %-15s Mode: Active${NC}\n" "$VERSION" "$(uname -s)/$(uname -m)"
    echo ""
}

# ── Domain Input ─────────────────────────────────────────────
get_domain() {
    echo -e "${BOLD}${WHITE}  ┌─ Target Configuration ─────────────────────────────┐${NC}"
    echo -ne "  ${BOLD}│  Enter target domain ${CYAN}(e.g. example.com)${NC}${BOLD}: ${NC}"
    read -r DOMAIN
    DOMAIN="${DOMAIN,,}"                         # lowercase
    DOMAIN="${DOMAIN#https://}"                 # strip https://
    DOMAIN="${DOMAIN#http://}"                  # strip http://
    DOMAIN="${DOMAIN%%/*}"                      # strip trailing path

    if [[ -z "$DOMAIN" ]]; then
        log_error "No domain entered. Exiting."
        exit 1
    fi

    echo -ne "  ${BOLD}│  Threads for httpx/naabu ${CYAN}[default: 150]${NC}${BOLD}: ${NC}"
    read -r THREADS
    THREADS="${THREADS:-150}"

    echo -ne "  ${BOLD}│  Enable port scanning? ${CYAN}[Y/n]${NC}${BOLD}: ${NC}"
    read -r DO_PORTS
    DO_PORTS="${DO_PORTS:-Y}"

    echo -ne "  ${BOLD}│  Enable screenshots (gowitness)? ${CYAN}[y/N]${NC}${BOLD}: ${NC}"
    read -r DO_SCREENSHOTS
    DO_SCREENSHOTS="${DO_SCREENSHOTS:-N}"

    echo -ne "  ${BOLD}│  Enable URL crawling (katana/gau)? ${CYAN}[Y/n]${NC}${BOLD}: ${NC}"
    read -r DO_CRAWL
    DO_CRAWL="${DO_CRAWL:-Y}"

    echo -e "  ${BOLD}└────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ── Output Directory ──────────────────────────────────────
    DESKTOP="$HOME/Desktop"
    [[ ! -d "$DESKTOP" ]] && DESKTOP="$HOME"       # fallback if no Desktop
    RECON_BASE="$DESKTOP/ReconBay"
    OUT_DIR="$RECON_BASE/$DOMAIN"
    mkdir -p "$OUT_DIR"/{subdomains,dns,http,ports,urls,js,vulns,screenshots,github,osint}

    log_ok "Output directory: ${CYAN}$OUT_DIR${NC}"
    log_ok "Target domain   : ${CYAN}$DOMAIN${NC}"
}

# ── Tool Check ────────────────────────────────────────────────
check_tools() {
    section "Tool Availability Check"
    TOOLS=(subfinder assetfinder httpx dnsx puredns naabu waybackurls gau katana
           github-subdomains gowitness nuclei tlsx shuffledns anew nmap curl jq)
    for t in "${TOOLS[@]}"; do
        if tool_ok "$t"; then
            log_ok "$t"
        else
            log_warn "$t — NOT FOUND (some modules will be skipped)"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 1: PASSIVE SUBDOMAIN ENUMERATION
# ═══════════════════════════════════════════════════════════════
module_passive_subdomains() {
    section "MODULE 1 │ Passive Subdomain Enumeration"
    RAW="$OUT_DIR/subdomains/raw_all.txt"
    > "$RAW"

    # 1a — Subfinder (all sources, recursive)
    if tool_ok subfinder; then
        log_info "subfinder → all sources + recursive..."
        subfinder -d "$DOMAIN" -all -recursive -silent -o "$OUT_DIR/subdomains/subfinder.txt" 2>/dev/null
        cat "$OUT_DIR/subdomains/subfinder.txt" >> "$RAW"
        log_ok "subfinder: $(count_lines "$OUT_DIR/subdomains/subfinder.txt") results"
    fi

    # 1b — Assetfinder
    if tool_ok assetfinder; then
        log_info "assetfinder..."
        assetfinder --subs-only "$DOMAIN" 2>/dev/null | grep "\.$DOMAIN$" | sort -u > "$OUT_DIR/subdomains/assetfinder.txt"
        cat "$OUT_DIR/subdomains/assetfinder.txt" >> "$RAW"
        log_ok "assetfinder: $(count_lines "$OUT_DIR/subdomains/assetfinder.txt") results"
    fi

    # 1c — crt.sh (certificate transparency)
    log_info "crt.sh certificate transparency..."
    curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null \
        | jq -r '.[].name_value' 2>/dev/null \
        | sed 's/\*\.//g' \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/crtsh.txt"
    cat "$OUT_DIR/subdomains/crtsh.txt" >> "$RAW"
    log_ok "crt.sh: $(count_lines "$OUT_DIR/subdomains/crtsh.txt") results"

    # 1d — certspotter
    log_info "certspotter..."
    curl -s "https://certspotter.com/api/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names" 2>/dev/null \
        | jq -r '.[].dns_names[]' 2>/dev/null \
        | sed 's/\*\.//g' \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/certspotter.txt"
    cat "$OUT_DIR/subdomains/certspotter.txt" >> "$RAW"
    log_ok "certspotter: $(count_lines "$OUT_DIR/subdomains/certspotter.txt") results"

    # 1e — HackerTarget
    log_info "hackertarget..."
    curl -s "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" 2>/dev/null \
        | cut -d',' -f1 \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/hackertarget.txt"
    cat "$OUT_DIR/subdomains/hackertarget.txt" >> "$RAW"
    log_ok "hackertarget: $(count_lines "$OUT_DIR/subdomains/hackertarget.txt") results"

    # 1f — RapidDNS
    log_info "rapiddns..."
    curl -s "https://rapiddns.io/subdomain/$DOMAIN?full=1" 2>/dev/null \
        | grep -oP "(?<=<td>)[a-zA-Z0-9._-]+\.$DOMAIN(?=</td>)" \
        | sort -u > "$OUT_DIR/subdomains/rapiddns.txt"
    cat "$OUT_DIR/subdomains/rapiddns.txt" >> "$RAW"
    log_ok "rapiddns: $(count_lines "$OUT_DIR/subdomains/rapiddns.txt") results"

    # 1g — jldc.me
    log_info "jldc.me..."
    curl -s "https://jldc.me/anubis/subdomains/$DOMAIN" 2>/dev/null \
        | jq -r '.[]' 2>/dev/null \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/jldc.txt"
    cat "$OUT_DIR/subdomains/jldc.txt" >> "$RAW"
    log_ok "jldc: $(count_lines "$OUT_DIR/subdomains/jldc.txt") results"

    # 1h — urlscan.io
    log_info "urlscan.io..."
    curl -s "https://urlscan.io/api/v1/search/?q=domain:$DOMAIN&size=200" 2>/dev/null \
        | jq -r '.results[].page.domain' 2>/dev/null \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/urlscan.txt"
    cat "$OUT_DIR/subdomains/urlscan.txt" >> "$RAW"
    log_ok "urlscan.io: $(count_lines "$OUT_DIR/subdomains/urlscan.txt") results"

    # 1i — Wayback Machine subdomains
    log_info "Wayback Machine..."
    curl -s "http://web.archive.org/cdx/search/cdx?url=*.$DOMAIN&output=text&fl=original&collapse=urlkey&limit=50000" 2>/dev/null \
        | grep -oP "https?://[a-zA-Z0-9._-]+\.$DOMAIN" \
        | grep -oP "[a-zA-Z0-9._-]+\.$DOMAIN" \
        | sort -u > "$OUT_DIR/subdomains/wayback.txt"
    cat "$OUT_DIR/subdomains/wayback.txt" >> "$RAW"
    log_ok "wayback: $(count_lines "$OUT_DIR/subdomains/wayback.txt") results"

    # 1j — Alienvault OTX
    log_info "AlienVault OTX..."
    curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$DOMAIN/passive_dns" 2>/dev/null \
        | jq -r '.passive_dns[].hostname' 2>/dev/null \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/otx.txt"
    cat "$OUT_DIR/subdomains/otx.txt" >> "$RAW"
    log_ok "AlienVault OTX: $(count_lines "$OUT_DIR/subdomains/otx.txt") results"

    # 1k — ThreatCrowd
    log_info "ThreatCrowd..."
    curl -s "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=$DOMAIN" 2>/dev/null \
        | jq -r '.subdomains[]' 2>/dev/null \
        | grep "\.$DOMAIN$\|^$DOMAIN$" \
        | sort -u > "$OUT_DIR/subdomains/threatcrowd.txt"
    cat "$OUT_DIR/subdomains/threatcrowd.txt" >> "$RAW"
    log_ok "ThreatCrowd: $(count_lines "$OUT_DIR/subdomains/threatcrowd.txt") results"

    # 1l — Chaos (ProjectDiscovery) — if API key present
    if [[ -n "$CHAOS_KEY" ]] && tool_ok chaos; then
        log_info "Chaos (ProjectDiscovery)..."
        chaos -d "$DOMAIN" -key "$CHAOS_KEY" -silent 2>/dev/null \
            | sort -u > "$OUT_DIR/subdomains/chaos.txt"
        cat "$OUT_DIR/subdomains/chaos.txt" >> "$RAW"
        log_ok "chaos: $(count_lines "$OUT_DIR/subdomains/chaos.txt") results"
    else
        log_skip "Chaos — no API key"
    fi

    # 1m — Shodan (if key present)
    if [[ -n "$SHODAN_KEY" ]]; then
        log_info "Shodan..."
        curl -s "https://api.shodan.io/dns/domain/$DOMAIN?key=$SHODAN_KEY" 2>/dev/null \
            | jq -r '.subdomains[]' 2>/dev/null \
            | sed "s/$/ .$DOMAIN/" \
            | awk '{print $1"."$2}' \
            | sort -u > "$OUT_DIR/subdomains/shodan.txt"
        cat "$OUT_DIR/subdomains/shodan.txt" >> "$RAW"
        log_ok "Shodan: $(count_lines "$OUT_DIR/subdomains/shodan.txt") results"
    else
        log_skip "Shodan — no API key"
    fi

    # ── Deduplicate ──────────────────────────────────────────
    sort -u "$RAW" | grep -E "^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$" \
        > "$OUT_DIR/subdomains/all_subdomains.txt"

    log_data "Total unique subdomains (passive): ${GREEN}$(count_lines "$OUT_DIR/subdomains/all_subdomains.txt")${NC}"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 2: GITHUB SUBDOMAIN ENUMERATION
# ═══════════════════════════════════════════════════════════════
module_github() {
    section "MODULE 2 │ GitHub Subdomain & Secret Enumeration"

    if [[ -z "$GITHUB_TOKENS" ]]; then
        log_warn "No GitHub tokens configured — skipping GitHub recon"
        log_warn "Run install.sh to add tokens for maximum coverage"
        return
    fi

    if tool_ok github-subdomains; then
        log_info "Running github-subdomains (all configured tokens)..."
        IFS=',' read -ra TOKEN_ARRAY <<< "$GITHUB_TOKENS"
        > "$OUT_DIR/github/github_raw.txt"

        for TOKEN in "${TOKEN_ARRAY[@]}"; do
            TOKEN=$(echo "$TOKEN" | tr -d ' ')
            [[ -z "$TOKEN" ]] && continue
            log_info "  Using token: ${TOKEN:0:8}..."
            github-subdomains -d "$DOMAIN" -t "$TOKEN" -o /tmp/gh_tmp.txt 2>/dev/null
            [[ -f /tmp/gh_tmp.txt ]] && cat /tmp/gh_tmp.txt >> "$OUT_DIR/github/github_raw.txt"
            rm -f /tmp/gh_tmp.txt
        done

        sort -u "$OUT_DIR/github/github_raw.txt" > "$OUT_DIR/github/github_subdomains.txt"
        cat "$OUT_DIR/github/github_subdomains.txt" >> "$OUT_DIR/subdomains/all_subdomains.txt"
        log_ok "GitHub: $(count_lines "$OUT_DIR/github/github_subdomains.txt") subdomains"
    else
        log_warn "github-subdomains not installed — doing manual GitHub API search..."

        IFS=',' read -ra TOKEN_ARRAY <<< "$GITHUB_TOKENS"
        TOKEN="${TOKEN_ARRAY[0]}"
        TOKEN=$(echo "$TOKEN" | tr -d ' ')

        if [[ -n "$TOKEN" ]]; then
            # GitHub code search for domain mentions
            QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$DOMAIN'))")
            curl -s -H "Authorization: token $TOKEN" \
                "https://api.github.com/search/code?q=$QUERY&per_page=100" 2>/dev/null \
                | jq -r '.items[].html_url' 2>/dev/null \
                > "$OUT_DIR/github/github_code_urls.txt"
            log_ok "GitHub code search: $(count_lines "$OUT_DIR/github/github_code_urls.txt") results"

            # Extract subdomains from GitHub results
            grep -oP "[a-zA-Z0-9._-]+\.$DOMAIN" "$OUT_DIR/github/github_code_urls.txt" 2>/dev/null \
                | sort -u > "$OUT_DIR/github/github_subdomains.txt"
            cat "$OUT_DIR/github/github_subdomains.txt" >> "$OUT_DIR/subdomains/all_subdomains.txt"
            log_ok "GitHub subdomains extracted: $(count_lines "$OUT_DIR/github/github_subdomains.txt")"
        fi
    fi

    # Re-deduplicate after adding github results
    sort -u "$OUT_DIR/subdomains/all_subdomains.txt" -o "$OUT_DIR/subdomains/all_subdomains.txt"
    log_data "Total unique subdomains (after GitHub): ${GREEN}$(count_lines "$OUT_DIR/subdomains/all_subdomains.txt")${NC}"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 3: DNS RESOLUTION & WILDCARD FILTERING
# ═══════════════════════════════════════════════════════════════
module_dns() {
    section "MODULE 3 │ DNS Resolution & Wildcard Filtering"

    ALL_SUBS="$OUT_DIR/subdomains/all_subdomains.txt"

    if [[ ! -s "$ALL_SUBS" ]]; then
        log_warn "No subdomains to resolve. Skipping."
        return
    fi

    # 3a — puredns (wildcard-aware resolver)
    if tool_ok puredns && [[ -s "$RESOLVERS" ]]; then
        log_info "puredns → resolving $(count_lines "$ALL_SUBS") subdomains (wildcard filtered)..."
        puredns resolve "$ALL_SUBS" \
            -r "$RESOLVERS" \
            --rate-limit 3000 \
            --wildcard-tests 5 \
            --wildcard-batch 1000000 \
            -q \
            -w "$OUT_DIR/dns/resolved.txt" 2>/dev/null
        log_ok "puredns resolved: $(count_lines "$OUT_DIR/dns/resolved.txt") live subdomains"
    else
        # Fallback: dnsx
        log_warn "puredns not available — falling back to dnsx"
        if tool_ok dnsx; then
            dnsx -l "$ALL_SUBS" -silent -r "$RESOLVERS" -t 200 -o "$OUT_DIR/dns/resolved.txt" 2>/dev/null
            log_ok "dnsx resolved: $(count_lines "$OUT_DIR/dns/resolved.txt") subdomains"
        else
            cp "$ALL_SUBS" "$OUT_DIR/dns/resolved.txt"
            log_warn "No DNS resolver available — using raw list"
        fi
    fi

    # 3b — Full DNS records with dnsx
    if tool_ok dnsx; then
        log_info "Fetching full DNS records (A, CNAME, MX, TXT, NS)..."
        dnsx -l "$OUT_DIR/dns/resolved.txt" \
            -a -cname -mx -txt -ns \
            -silent -r "$RESOLVERS" \
            -json \
            -o "$OUT_DIR/dns/dns_records.json" 2>/dev/null

        # Extract IPs
        jq -r '.a[]?' "$OUT_DIR/dns/dns_records.json" 2>/dev/null | sort -u > "$OUT_DIR/dns/ip_addresses.txt"
        # Extract CNAMEs (potential takeovers)
        jq -r '.cname[]?' "$OUT_DIR/dns/dns_records.json" 2>/dev/null | sort -u > "$OUT_DIR/dns/cnames.txt"
        # TXT records (SPF, DKIM, secrets)
        jq -r '.txt[]?' "$OUT_DIR/dns/dns_records.json" 2>/dev/null | sort -u > "$OUT_DIR/dns/txt_records.txt"

        log_ok "IPs collected  : $(count_lines "$OUT_DIR/dns/ip_addresses.txt")"
        log_ok "CNAMEs found   : $(count_lines "$OUT_DIR/dns/cnames.txt")"
        log_ok "TXT records    : $(count_lines "$OUT_DIR/dns/txt_records.txt")"
    fi

    # 3c — TLSX — TLS certificate data
    if tool_ok tlsx; then
        log_info "tlsx → extracting subdomains from TLS certificates..."
        cat "$OUT_DIR/dns/resolved.txt" | tlsx -san -cn -silent 2>/dev/null \
            | grep "\.$DOMAIN$\|^$DOMAIN$" \
            | sort -u > "$OUT_DIR/dns/tlsx_subdomains.txt"
        cat "$OUT_DIR/dns/tlsx_subdomains.txt" >> "$OUT_DIR/subdomains/all_subdomains.txt"
        sort -u "$OUT_DIR/subdomains/all_subdomains.txt" -o "$OUT_DIR/subdomains/all_subdomains.txt"
        log_ok "TLS cert subdomains: $(count_lines "$OUT_DIR/dns/tlsx_subdomains.txt")"
    fi

    # 3d — Subdomain takeover fingerprint check (CNAMEs)
    if [[ -s "$OUT_DIR/dns/cnames.txt" ]]; then
        log_info "Checking for potential subdomain takeovers..."
        TAKEOVER_PATTERNS=(
            "github.io" "herokuapp.com" "azurewebsites.net" "cloudfront.net"
            "s3.amazonaws.com" "storage.googleapis.com" "netlify.com" "surge.sh"
            "shopify.com" "fastly.net" "pantheonsite.io" "tumblr.com"
            "wpengine.com" "freshdesk.com" "helpscout.net" "intercom.io"
        )
        > "$OUT_DIR/dns/potential_takeovers.txt"
        while IFS= read -r CNAME; do
            for PATTERN in "${TAKEOVER_PATTERNS[@]}"; do
                if echo "$CNAME" | grep -qi "$PATTERN"; then
                    echo "[POTENTIAL TAKEOVER] $CNAME → $PATTERN" >> "$OUT_DIR/dns/potential_takeovers.txt"
                fi
            done
        done < "$OUT_DIR/dns/cnames.txt"
        TAKEOVER_COUNT=$(count_lines "$OUT_DIR/dns/potential_takeovers.txt")
        if [[ $TAKEOVER_COUNT -gt 0 ]]; then
            log_warn "⚠  Potential subdomain takeovers: $TAKEOVER_COUNT — see dns/potential_takeovers.txt"
        else
            log_ok "No obvious takeover candidates found"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 4: LIVE HOST DETECTION
# ═══════════════════════════════════════════════════════════════
module_http_probe() {
    section "MODULE 4 │ HTTP/S Live Host Detection"

    RESOLVED="$OUT_DIR/dns/resolved.txt"
    [[ ! -s "$RESOLVED" ]] && RESOLVED="$OUT_DIR/subdomains/all_subdomains.txt"

    if ! tool_ok httpx && ! tool_ok httpx-toolkit; then
        log_warn "httpx not found — skipping live host detection"
        return
    fi

    HTTPX_BIN="httpx"
    tool_ok httpx-toolkit && HTTPX_BIN="httpx-toolkit"

    log_info "Probing live hosts on ports 80,443,8080,8000,8443,8888,3000,4443 ..."
    $HTTPX_BIN \
        -l "$RESOLVED" \
        -ports 80,443,8080,8000,8443,8888,3000,4443 \
        -threads "$THREADS" \
        -silent \
        -status-code \
        -title \
        -tech-detect \
        -server \
        -content-length \
        -follow-redirects \
        -rate-limit 150 \
        -json \
        -o "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null

    # Plain list of live URLs
    jq -r '.url' "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null | sort -u > "$OUT_DIR/http/live_hosts.txt"

    # Interesting status codes
    jq -r 'select(.status_code == 200) | .url' "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null \
        | sort -u > "$OUT_DIR/http/status_200.txt"
    jq -r 'select(.status_code >= 301 and .status_code <= 308) | "\(.status_code) \(.url)"' \
        "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null > "$OUT_DIR/http/redirects.txt"
    jq -r 'select(.status_code == 403) | .url' "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null \
        | sort -u > "$OUT_DIR/http/status_403.txt"
    jq -r 'select(.status_code == 401) | .url' "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null \
        | sort -u > "$OUT_DIR/http/status_401.txt"
    jq -r 'select(.status_code == 500) | .url' "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null \
        | sort -u > "$OUT_DIR/http/status_500.txt"

    # Technology summary
    jq -r 'select(.technologies != null) | "\(.url)\t\(.technologies | join(", "))"' \
        "$OUT_DIR/http/live_hosts_full.json" 2>/dev/null > "$OUT_DIR/http/tech_stack.txt"

    log_ok "Live hosts         : ${GREEN}$(count_lines "$OUT_DIR/http/live_hosts.txt")${NC}"
    log_ok "200 OK             : $(count_lines "$OUT_DIR/http/status_200.txt")"
    log_ok "Redirects (3xx)    : $(count_lines "$OUT_DIR/http/redirects.txt")"
    log_ok "Forbidden (403)    : $(count_lines "$OUT_DIR/http/status_403.txt")"
    log_ok "Unauthorised (401) : $(count_lines "$OUT_DIR/http/status_401.txt")"
    log_ok "Errors (500)       : $(count_lines "$OUT_DIR/http/status_500.txt")"
    log_ok "Tech fingerprints  : $(count_lines "$OUT_DIR/http/tech_stack.txt")"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 5: PORT SCANNING
# ═══════════════════════════════════════════════════════════════
module_ports() {
    [[ "${DO_PORTS,,}" == "n" ]] && { log_skip "Port scanning skipped by user"; return; }
    section "MODULE 5 │ Smart Port Scanning"

    IPS="$OUT_DIR/dns/ip_addresses.txt"
    TARGETS="$OUT_DIR/dns/resolved.txt"

    # 5a — naabu (fast port scanner)
    if tool_ok naabu; then
        log_info "naabu → top 1000 ports across all IPs..."
        SCAN_INPUT="$IPS"
        [[ ! -s "$SCAN_INPUT" ]] && SCAN_INPUT="$TARGETS"

        naabu \
            -l "$SCAN_INPUT" \
            -top-ports 1000 \
            -rate 1000 \
            -silent \
            -o "$OUT_DIR/ports/naabu_ports.txt" 2>/dev/null
        log_ok "naabu: $(count_lines "$OUT_DIR/ports/naabu_ports.txt") open ports"

        # Service detection with nmap on discovered ports
        if tool_ok nmap && [[ -s "$OUT_DIR/ports/naabu_ports.txt" ]]; then
            log_info "nmap service/version detection on discovered open ports..."
            # Extract unique IPs with ports for nmap
            awk -F: '{print $1}' "$OUT_DIR/ports/naabu_ports.txt" | sort -u > /tmp/rb_ips.txt
            PORTS_LIST=$(awk -F: '{print $2}' "$OUT_DIR/ports/naabu_ports.txt" | sort -un | paste -sd,)
            nmap -sV -sC \
                --open \
                -p "$PORTS_LIST" \
                -iL /tmp/rb_ips.txt \
                -T4 \
                --script=http-title,http-headers,ssl-cert,banner \
                -oN "$OUT_DIR/ports/nmap_services.txt" \
                -oX "$OUT_DIR/ports/nmap_services.xml" 2>/dev/null
            log_ok "nmap service scan complete"
        fi
    elif tool_ok nmap; then
        log_info "nmap → common port scan (no naabu)..."
        SCAN_INPUT="$IPS"
        [[ ! -s "$SCAN_INPUT" ]] && SCAN_INPUT="$TARGETS"
        nmap -sV --open -T4 \
            --top-ports 500 \
            -iL "$SCAN_INPUT" \
            -oN "$OUT_DIR/ports/nmap_ports.txt" 2>/dev/null
        log_ok "nmap: complete"
    else
        log_warn "No port scanner available (install naabu or nmap)"
    fi

    # 5b — Interesting ports highlight
    log_info "Extracting interesting ports..."
    INTERESTING_PORTS="21,22,23,25,53,110,143,445,1433,1521,3306,3389,5432,5900,6379,8080,8443,9200,27017"
    grep -E ":($(echo $INTERESTING_PORTS | tr ',' '|'))$" \
        "$OUT_DIR/ports/naabu_ports.txt" 2>/dev/null \
        > "$OUT_DIR/ports/interesting_ports.txt"
    [[ $(count_lines "$OUT_DIR/ports/interesting_ports.txt") -gt 0 ]] && \
        log_warn "⚠  Interesting ports: $(count_lines "$OUT_DIR/ports/interesting_ports.txt") — check ports/interesting_ports.txt"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 6: URL HARVESTING
# ═══════════════════════════════════════════════════════════════
module_urls() {
    [[ "${DO_CRAWL,,}" == "n" ]] && { log_skip "URL crawling skipped by user"; return; }
    section "MODULE 6 │ URL Harvesting & Crawling"

    LIVE="$OUT_DIR/http/live_hosts.txt"
    [[ ! -s "$LIVE" ]] && LIVE="$OUT_DIR/dns/resolved.txt"

    # 6a — Waybackurls
    if tool_ok waybackurls; then
        log_info "waybackurls → fetching archived URLs..."
        cat "$OUT_DIR/subdomains/all_subdomains.txt" \
            | waybackurls 2>/dev/null \
            | sort -u > "$OUT_DIR/urls/wayback_urls.txt"
        log_ok "waybackurls: $(count_lines "$OUT_DIR/urls/wayback_urls.txt") URLs"
    fi

    # 6b — gau (GetAllUrls)
    if tool_ok gau; then
        log_info "gau → fetching from multiple sources..."
        echo "$DOMAIN" | gau \
            --threads 5 \
            --providers wayback,commoncrawl,otx,urlscan \
            --blacklist png,jpg,gif,jpeg,woff,svg,eot,ttf,css \
            2>/dev/null \
            | sort -u > "$OUT_DIR/urls/gau_urls.txt"
        log_ok "gau: $(count_lines "$OUT_DIR/urls/gau_urls.txt") URLs"
    fi

    # 6c — Katana (active crawl)
    if tool_ok katana && [[ -s "$LIVE" ]]; then
        log_info "katana → actively crawling live hosts..."
        katana \
            -list "$LIVE" \
            -d 3 \
            -jc \
            -kf all \
            -silent \
            -nc \
            -c 50 \
            -ef png,jpg,gif,jpeg,woff,svg,eot,ttf,css,ico \
            -o "$OUT_DIR/urls/katana_urls.txt" 2>/dev/null
        log_ok "katana: $(count_lines "$OUT_DIR/urls/katana_urls.txt") URLs"
    fi

    # 6d — Merge & deduplicate all URLs
    cat "$OUT_DIR/urls/"*.txt 2>/dev/null | sort -u > "$OUT_DIR/urls/all_urls.txt"
    log_ok "Total unique URLs: ${GREEN}$(count_lines "$OUT_DIR/urls/all_urls.txt")${NC}"

    # 6e — Interesting parameter discovery
    log_info "Extracting interesting parameters..."
    grep -E "[\?&](id|user|file|path|url|redirect|next|return|goto|back|page|query|search|q|debug|test|api|key|token|secret|pass|admin|ref)=" \
        "$OUT_DIR/urls/all_urls.txt" 2>/dev/null \
        | sort -u > "$OUT_DIR/urls/interesting_params.txt"
    log_ok "Interesting params: $(count_lines "$OUT_DIR/urls/interesting_params.txt")"

    # 6f — Categorize endpoints
    grep -iE "\.(php|asp|aspx|jsp|cfm|cgi|pl|py|rb)(\?|$)" \
        "$OUT_DIR/urls/all_urls.txt" 2>/dev/null | sort -u > "$OUT_DIR/urls/dynamic_endpoints.txt"
    grep -iE "(api|graphql|rest|v1|v2|v3)/" \
        "$OUT_DIR/urls/all_urls.txt" 2>/dev/null | sort -u > "$OUT_DIR/urls/api_endpoints.txt"
    grep -iE "\.(xml|json|yaml|yml|env|config|conf|bak|backup|sql|gz|zip|tar|log|txt)(\?|$)" \
        "$OUT_DIR/urls/all_urls.txt" 2>/dev/null | sort -u > "$OUT_DIR/urls/sensitive_files.txt"

    log_ok "Dynamic endpoints : $(count_lines "$OUT_DIR/urls/dynamic_endpoints.txt")"
    log_ok "API endpoints     : $(count_lines "$OUT_DIR/urls/api_endpoints.txt")"
    log_ok "Sensitive files   : $(count_lines "$OUT_DIR/urls/sensitive_files.txt")"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 7: JAVASCRIPT FILE ANALYSIS
# ═══════════════════════════════════════════════════════════════
module_js() {
    section "MODULE 7 │ JavaScript File Collection"

    # Extract JS URLs
    grep -iE "\.js(\?|$)" "$OUT_DIR/urls/all_urls.txt" 2>/dev/null \
        | sort -u > "$OUT_DIR/js/js_files.txt"
    log_ok "JS files found: $(count_lines "$OUT_DIR/js/js_files.txt")"

    # Download & scan JS for secrets/endpoints
    if [[ -s "$OUT_DIR/js/js_files.txt" ]]; then
        log_info "Scanning JS files for secrets & endpoints..."
        mkdir -p "$OUT_DIR/js/downloaded"
        > "$OUT_DIR/js/js_endpoints.txt"
        > "$OUT_DIR/js/js_secrets.txt"

        # Secret patterns to hunt
        SECRET_PATTERNS=(
            "apikey\|api_key\|apiKey"
            "secret\|SECRET"
            "password\|passwd\|PASSWORD"
            "token\|TOKEN"
            "authorization\|Authorization"
            "aws_access\|AKIA[0-9A-Z]{16}"
            "-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----"
            "firebase\|firebaseio"
            "bucket\|s3\.amazonaws"
        )

        # Sample first 100 JS files (avoid overwhelming)
        head -100 "$OUT_DIR/js/js_files.txt" | while IFS= read -r JS_URL; do
            JS_FILE=$(echo "$JS_URL" | md5sum | cut -d' ' -f1).js
            curl -s -L --max-time 10 "$JS_URL" \
                -o "$OUT_DIR/js/downloaded/$JS_FILE" 2>/dev/null

            if [[ -f "$OUT_DIR/js/downloaded/$JS_FILE" ]]; then
                # Extract relative endpoints
                grep -oP '["'"'"'`](/[a-zA-Z0-9_/.-]+)['"'"'"`]' \
                    "$OUT_DIR/js/downloaded/$JS_FILE" 2>/dev/null \
                    | grep -v "\.png\|\.jpg\|\.svg\|\.gif\|\.ico\|\.css\|\.woff" \
                    | sed 's/[\"'"'"'`]//g' \
                    | sort -u >> "$OUT_DIR/js/js_endpoints.txt"

                # Scan for secret patterns
                for PATTERN in "${SECRET_PATTERNS[@]}"; do
                    MATCHES=$(grep -iP "$PATTERN" "$OUT_DIR/js/downloaded/$JS_FILE" 2>/dev/null | head -5)
                    if [[ -n "$MATCHES" ]]; then
                        echo "=== $JS_URL ===" >> "$OUT_DIR/js/js_secrets.txt"
                        echo "$MATCHES" >> "$OUT_DIR/js/js_secrets.txt"
                        echo "" >> "$OUT_DIR/js/js_secrets.txt"
                    fi
                done
            fi
        done

        sort -u "$OUT_DIR/js/js_endpoints.txt" -o "$OUT_DIR/js/js_endpoints.txt"
        SECRET_COUNT=$(grep -c "^===" "$OUT_DIR/js/js_secrets.txt" 2>/dev/null || echo 0)
        log_ok "JS endpoints extracted: $(count_lines "$OUT_DIR/js/js_endpoints.txt")"
        [[ $SECRET_COUNT -gt 0 ]] && \
            log_warn "⚠  Potential secrets in JS: $SECRET_COUNT files — check js/js_secrets.txt"
    fi
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 8: OSINT
# ═══════════════════════════════════════════════════════════════
module_osint() {
    section "MODULE 8 │ OSINT & Infrastructure Info"

    # 8a — WHOIS
    log_info "WHOIS lookup..."
    whois "$DOMAIN" 2>/dev/null > "$OUT_DIR/osint/whois.txt"
    log_ok "WHOIS data saved"

    # 8b — DNS zone / nameservers
    log_info "Name server enumeration..."
    dig NS "$DOMAIN" +short 2>/dev/null | sort -u > "$OUT_DIR/osint/nameservers.txt"
    dig MX "$DOMAIN" +short 2>/dev/null | sort -u > "$OUT_DIR/osint/mx_records.txt"
    log_ok "Nameservers: $(count_lines "$OUT_DIR/osint/nameservers.txt")"

    # 8c — Zone transfer attempt
    log_info "DNS zone transfer attempt (AXFR)..."
    while IFS= read -r NS; do
        NS_CLEAN=$(echo "$NS" | sed 's/\.$//')
        dig AXFR "$DOMAIN" "@$NS_CLEAN" 2>/dev/null >> "$OUT_DIR/osint/zone_transfer.txt"
    done < "$OUT_DIR/osint/nameservers.txt"
    if grep -q "Transfer failed\|connection refused" "$OUT_DIR/osint/zone_transfer.txt" 2>/dev/null; then
        log_ok "Zone transfer: Blocked (expected)"
    elif [[ -s "$OUT_DIR/osint/zone_transfer.txt" ]]; then
        log_warn "⚠  Zone transfer may have succeeded — check osint/zone_transfer.txt"
    fi

    # 8d — Email addresses via HackerTarget
    log_info "Email harvesting..."
    curl -s "https://api.hackertarget.com/emailfinder/?q=$DOMAIN" 2>/dev/null \
        | grep "@$DOMAIN" | sort -u > "$OUT_DIR/osint/emails.txt"
    log_ok "Emails found: $(count_lines "$OUT_DIR/osint/emails.txt")"

    # 8e — theHarvester
    if tool_ok theHarvester; then
        log_info "theHarvester (passive sources)..."
        theHarvester -d "$DOMAIN" \
            -b all \
            -f "$OUT_DIR/osint/theharvester" 2>/dev/null
        log_ok "theHarvester complete"
    fi

    # 8f — Reverse IP / shared hosting
    log_info "Reverse IP lookup..."
    if [[ -s "$OUT_DIR/dns/ip_addresses.txt" ]]; then
        head -5 "$OUT_DIR/dns/ip_addresses.txt" | while IFS= read -r IP; do
            echo "=== Reverse IP: $IP ===" >> "$OUT_DIR/osint/reverse_ip.txt"
            curl -s "https://api.hackertarget.com/reverseiplookup/?q=$IP" 2>/dev/null \
                >> "$OUT_DIR/osint/reverse_ip.txt"
            echo "" >> "$OUT_DIR/osint/reverse_ip.txt"
        done
        log_ok "Reverse IP: $(count_lines "$OUT_DIR/osint/reverse_ip.txt") lines"
    fi

    # 8g — ASN / IP range
    log_info "ASN lookup..."
    FIRST_IP=$(head -1 "$OUT_DIR/dns/ip_addresses.txt" 2>/dev/null)
    if [[ -n "$FIRST_IP" ]]; then
        curl -s "https://ipinfo.io/$FIRST_IP/json" 2>/dev/null \
            | jq . > "$OUT_DIR/osint/asn_info.json" 2>/dev/null
        log_ok "ASN info saved"
    fi

    # 8h — Shodan summary (free tier)
    if [[ -n "$SHODAN_KEY" ]]; then
        log_info "Shodan domain info..."
        curl -s "https://api.shodan.io/dns/domain/$DOMAIN?key=$SHODAN_KEY" 2>/dev/null \
            | jq . > "$OUT_DIR/osint/shodan_domain.json" 2>/dev/null
        log_ok "Shodan info saved"
    fi
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 9: SCREENSHOTS
# ═══════════════════════════════════════════════════════════════
module_screenshots() {
    [[ "${DO_SCREENSHOTS,,}" != "y" ]] && { log_skip "Screenshots skipped"; return; }
    section "MODULE 9 │ Screenshots (gowitness)"

    if ! tool_ok gowitness; then
        log_warn "gowitness not found — skipping"
        return
    fi

    LIVE="$OUT_DIR/http/live_hosts.txt"
    [[ ! -s "$LIVE" ]] && { log_warn "No live hosts to screenshot"; return; }

    log_info "Taking screenshots of $(count_lines "$LIVE") live hosts..."
    gowitness file \
        --file-path "$LIVE" \
        --screenshot-path "$OUT_DIR/screenshots/" \
        --threads 10 \
        --timeout 10 2>/dev/null

    SHOT_COUNT=$(find "$OUT_DIR/screenshots" -name "*.png" 2>/dev/null | wc -l)
    log_ok "Screenshots taken: $SHOT_COUNT"

    # Generate HTML report
    gowitness report generate \
        --screenshot-path "$OUT_DIR/screenshots/" \
        --destination "$OUT_DIR/screenshots/report.html" 2>/dev/null
    [[ -f "$OUT_DIR/screenshots/report.html" ]] && log_ok "HTML report: screenshots/report.html"
}

# ═══════════════════════════════════════════════════════════════
#  MODULE 10: NUCLEI VULNERABILITY SCAN
# ═══════════════════════════════════════════════════════════════
module_nuclei() {
    section "MODULE 10 │ Nuclei Vulnerability Templates"

    if ! tool_ok nuclei; then
        log_warn "nuclei not found — skipping"
        return
    fi

    LIVE="$OUT_DIR/http/live_hosts.txt"
    [[ ! -s "$LIVE" ]] && { log_warn "No live hosts for nuclei scan"; return; }

    log_info "Updating nuclei templates..."
    nuclei -update-templates -silent 2>/dev/null

    log_info "Running nuclei (critical + high severity)..."
    nuclei \
        -l "$LIVE" \
        -severity critical,high,medium \
        -tags cve,misconfig,exposure,takeover,token \
        -rate-limit 50 \
        -timeout 10 \
        -silent \
        -nc \
        -o "$OUT_DIR/vulns/nuclei_results.txt" 2>/dev/null

    log_ok "Nuclei findings: ${RED}$(count_lines "$OUT_DIR/vulns/nuclei_results.txt")${NC}"

    # Separate by severity
    grep "\[critical\]" "$OUT_DIR/vulns/nuclei_results.txt" 2>/dev/null > "$OUT_DIR/vulns/critical.txt"
    grep "\[high\]"     "$OUT_DIR/vulns/nuclei_results.txt" 2>/dev/null > "$OUT_DIR/vulns/high.txt"
    grep "\[medium\]"   "$OUT_DIR/vulns/nuclei_results.txt" 2>/dev/null > "$OUT_DIR/vulns/medium.txt"

    [[ $(count_lines "$OUT_DIR/vulns/critical.txt") -gt 0 ]] && \
        log_warn "🔴 CRITICAL: $(count_lines "$OUT_DIR/vulns/critical.txt") — check vulns/critical.txt"
    [[ $(count_lines "$OUT_DIR/vulns/high.txt") -gt 0 ]] && \
        log_warn "🟠 HIGH    : $(count_lines "$OUT_DIR/vulns/high.txt") — check vulns/high.txt"
}

# ═══════════════════════════════════════════════════════════════
#  FINAL REPORT
# ═══════════════════════════════════════════════════════════════
generate_report() {
    section "Generating Final Report"

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    HOURS=$((ELAPSED / 3600))
    MINUTES=$(( (ELAPSED % 3600) / 60 ))
    SECONDS_REM=$((ELAPSED % 60))

    REPORT="$OUT_DIR/RECONBAY_REPORT.txt"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$REPORT" << REPORT_EOF
╔══════════════════════════════════════════════════════════════════╗
║              ReconBay — Final Recon Report                       ║
║              Author: Nipun Dilshan  |  v$VERSION                        ║
╚══════════════════════════════════════════════════════════════════╝

  Target      : $DOMAIN
  Timestamp   : $TIMESTAMP
  Elapsed     : ${HOURS}h ${MINUTES}m ${SECONDS_REM}s
  Output Dir  : $OUT_DIR

══════════════════════════════════════════════════════════════════
  SUBDOMAIN ENUMERATION
══════════════════════════════════════════════════════════════════
  Raw (all sources)       : $(count_lines "$OUT_DIR/subdomains/raw_all.txt")
  After deduplication     : $(count_lines "$OUT_DIR/subdomains/all_subdomains.txt")
  DNS resolved            : $(count_lines "$OUT_DIR/dns/resolved.txt")
  IPs discovered          : $(count_lines "$OUT_DIR/dns/ip_addresses.txt")
  CNAMEs                  : $(count_lines "$OUT_DIR/dns/cnames.txt")
  Potential takeovers     : $(count_lines "$OUT_DIR/dns/potential_takeovers.txt")
  GitHub subdomains       : $(count_lines "$OUT_DIR/github/github_subdomains.txt")

  Source breakdown:
    subfinder             : $(count_lines "$OUT_DIR/subdomains/subfinder.txt")
    assetfinder           : $(count_lines "$OUT_DIR/subdomains/assetfinder.txt")
    crt.sh                : $(count_lines "$OUT_DIR/subdomains/crtsh.txt")
    certspotter           : $(count_lines "$OUT_DIR/subdomains/certspotter.txt")
    hackertarget          : $(count_lines "$OUT_DIR/subdomains/hackertarget.txt")
    rapiddns              : $(count_lines "$OUT_DIR/subdomains/rapiddns.txt")
    jldc                  : $(count_lines "$OUT_DIR/subdomains/jldc.txt")
    urlscan.io            : $(count_lines "$OUT_DIR/subdomains/urlscan.txt")
    wayback               : $(count_lines "$OUT_DIR/subdomains/wayback.txt")
    otx                   : $(count_lines "$OUT_DIR/subdomains/otx.txt")
    chaos                 : $(count_lines "$OUT_DIR/subdomains/chaos.txt")
    github                : $(count_lines "$OUT_DIR/github/github_subdomains.txt")
    tlsx                  : $(count_lines "$OUT_DIR/dns/tlsx_subdomains.txt")

══════════════════════════════════════════════════════════════════
  HTTP ANALYSIS
══════════════════════════════════════════════════════════════════
  Live hosts              : $(count_lines "$OUT_DIR/http/live_hosts.txt")
  200 OK                  : $(count_lines "$OUT_DIR/http/status_200.txt")
  Redirects (3xx)         : $(count_lines "$OUT_DIR/http/redirects.txt")
  Forbidden (403)         : $(count_lines "$OUT_DIR/http/status_403.txt")
  Unauthorized (401)      : $(count_lines "$OUT_DIR/http/status_401.txt")
  Server Errors (500)     : $(count_lines "$OUT_DIR/http/status_500.txt")
  Tech fingerprints       : $(count_lines "$OUT_DIR/http/tech_stack.txt")

══════════════════════════════════════════════════════════════════
  URL & ENDPOINT DISCOVERY
══════════════════════════════════════════════════════════════════
  Total URLs              : $(count_lines "$OUT_DIR/urls/all_urls.txt")
  Interesting params      : $(count_lines "$OUT_DIR/urls/interesting_params.txt")
  Dynamic endpoints       : $(count_lines "$OUT_DIR/urls/dynamic_endpoints.txt")
  API endpoints           : $(count_lines "$OUT_DIR/urls/api_endpoints.txt")
  Sensitive files         : $(count_lines "$OUT_DIR/urls/sensitive_files.txt")
  JS files                : $(count_lines "$OUT_DIR/js/js_files.txt")
  JS endpoints            : $(count_lines "$OUT_DIR/js/js_endpoints.txt")

══════════════════════════════════════════════════════════════════
  VULNERABILITIES (Nuclei)
══════════════════════════════════════════════════════════════════
  Critical                : $(count_lines "$OUT_DIR/vulns/critical.txt")
  High                    : $(count_lines "$OUT_DIR/vulns/high.txt")
  Medium                  : $(count_lines "$OUT_DIR/vulns/medium.txt")
  Total findings          : $(count_lines "$OUT_DIR/vulns/nuclei_results.txt")

══════════════════════════════════════════════════════════════════
  OUTPUT FILES
══════════════════════════════════════════════════════════════════
  subdomains/all_subdomains.txt   — All discovered subdomains
  dns/resolved.txt                — DNS-verified live subdomains
  dns/ip_addresses.txt            — Discovered IP addresses
  dns/cnames.txt                  — CNAME records
  dns/potential_takeovers.txt     — Takeover candidates
  http/live_hosts.txt             — HTTP/S live hosts
  http/tech_stack.txt             — Technology fingerprints
  urls/all_urls.txt               — All harvested URLs
  urls/interesting_params.txt     — Potential injection points
  urls/sensitive_files.txt        — Exposed sensitive files
  js/js_files.txt                 — JavaScript file list
  js/js_secrets.txt               — Potential secrets in JS
  vulns/nuclei_results.txt        — All nuclei findings
  osint/whois.txt                 — WHOIS data
  osint/emails.txt                — Harvested emails
  github/github_subdomains.txt    — GitHub-sourced subdomains

══════════════════════════════════════════════════════════════════

  ReconBay — Author: Nipun Dilshan
  This tool is for authorized penetration testing only.

REPORT_EOF

    log_ok "Full report saved: ${CYAN}$REPORT${NC}"
}

# ── Final Summary Display ─────────────────────────────────────
print_final() {
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    echo ""
    echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                  ReconBay Complete!  ✔                    ║${NC}"
    echo -e "${GREEN}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Target   : ${CYAN}$DOMAIN${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Out Dir  : ${CYAN}$OUT_DIR${NC}"
    printf "${GREEN}${BOLD}║${NC}  Elapsed  : %02d:%02d:%02d\n" $((ELAPSED/3600)) $(( (ELAPSED%3600)/60 )) $((ELAPSED%60))
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Subdomains  : ${WHITE}$(count_lines "$OUT_DIR/subdomains/all_subdomains.txt")${NC}   Live Hosts: ${WHITE}$(count_lines "$OUT_DIR/http/live_hosts.txt")${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  URLs        : ${WHITE}$(count_lines "$OUT_DIR/urls/all_urls.txt")${NC}   Nuclei   : ${RED}$(count_lines "$OUT_DIR/vulns/nuclei_results.txt")${NC} findings"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  ${YELLOW}Report → $OUT_DIR/RECONBAY_REPORT.txt${NC}"
    echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${DIM}  Happy Hacking — Nipun Dilshan  |  Authorized Use Only${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
#  MAIN ENTRY POINT
# ═══════════════════════════════════════════════════════════════
main() {
    print_banner
    get_domain
    check_tools

    module_passive_subdomains
    module_github
    module_dns
    module_http_probe
    module_ports
    module_urls
    module_js
    module_osint
    module_screenshots
    module_nuclei

    generate_report
    print_final
}

# ── Trap for clean exit ───────────────────────────────────────
trap 'echo -e "\n${YELLOW}[!] ReconBay interrupted. Partial results saved to: $OUT_DIR${NC}"; exit 1' INT TERM

main "$@"
