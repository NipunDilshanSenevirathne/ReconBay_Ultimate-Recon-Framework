# ReconBay 
### Ultimate Recon Framework | Author: Nipun Dilshan

```
 ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗██████╗  █████╗ ██╗   ██╗
 ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║██╔══██╗██╔══██╗╚██╗ ██╔╝
 ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║██████╔╝███████║ ╚████╔╝
 ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║██╔══██╗██╔══██║  ╚██╔╝
 ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║██████╔╝██║  ██║   ██║
 ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝   ╚═╝
```

> ⚠️ **For authorized penetration testing & bug bounty only.**

---

## Installation

```bash
git clone https://github.com/yourrepo/reconbay
cd reconbay
sudo bash install.sh
```

The installer will:
- Install all Go tools (subfinder, httpx, dnsx, puredns, naabu, katana, nuclei, gowitness, gau, waybackurls, tlsx, github-subdomains, anew, shuffledns, chaos, uncover …)
- Install system packages (nmap, curl, jq, python3 …)
- Download ~3,000 fresh public DNS resolvers
- **Ask for your GitHub token(s)** → stored in `~/.reconbay/config`
- Ask for optional Chaos / Shodan API keys
- Create a global `reconbay` command

---

## Usage

```bash
reconbay
# — or —
bash reconbay.sh
```

The tool will interactively ask:
| Prompt | Default |
|--------|---------|
| Target domain | — |
| Thread count | 150 |
| Enable port scanning? | Y |
| Enable screenshots? | N |
| Enable URL crawling? | Y |

All output is saved to: `~/Desktop/ReconBay/<domain>/`

---

## Modules

| # | Module | Tools Used |
|---|--------|------------|
| 1 | Passive Subdomain Enumeration | subfinder, assetfinder, crt.sh, certspotter, hackertarget, rapiddns, jldc, urlscan.io, Wayback, OTX, ThreatCrowd, Chaos, Shodan |
| 2 | GitHub Subdomain Recon | github-subdomains + GitHub API |
| 3 | DNS Resolution & Wildcard Filter | puredns, dnsx, tlsx |
| 4 | Live Host Detection | httpx (status codes, tech detection, headers) |
| 5 | Smart Port Scanning | naabu + nmap service detection |
| 6 | URL Harvesting | waybackurls, gau, katana (active crawl) |
| 7 | JavaScript Analysis | katana, curl + regex patterns |
| 8 | OSINT | WHOIS, zone transfer, email harvest, ASN, reverse IP |
| 9 | Screenshots | gowitness + HTML report |
| 10 | Vulnerability Scan | nuclei (critical/high/medium templates) |

---

## Output Folder Structure

```
~/Desktop/ReconBay/<domain>/
├── subdomains/
│   ├── all_subdomains.txt       ← all unique subdomains
│   ├── subfinder.txt
│   ├── assetfinder.txt
│   ├── crtsh.txt
│   └── … (one file per source)
├── dns/
│   ├── resolved.txt             ← DNS-verified live subs
│   ├── ip_addresses.txt
│   ├── cnames.txt
│   ├── txt_records.txt
│   └── potential_takeovers.txt  ← ⚠ takeover candidates
├── http/
│   ├── live_hosts.txt
│   ├── tech_stack.txt
│   ├── status_200/403/401/500.txt
│   └── live_hosts_full.json
├── ports/
│   ├── naabu_ports.txt
│   ├── nmap_services.txt
│   └── interesting_ports.txt
├── urls/
│   ├── all_urls.txt
│   ├── interesting_params.txt   ← ?id=, ?redirect=, etc.
│   ├── api_endpoints.txt
│   ├── dynamic_endpoints.txt
│   └── sensitive_files.txt
├── js/
│   ├── js_files.txt
│   ├── js_endpoints.txt
│   └── js_secrets.txt           ← ⚠ potential leaked secrets
├── vulns/
│   ├── nuclei_results.txt
│   ├── critical.txt
│   ├── high.txt
│   └── medium.txt
├── screenshots/
│   └── report.html
├── github/
│   └── github_subdomains.txt
├── osint/
│   ├── whois.txt
│   ├── emails.txt
│   ├── nameservers.txt
│   ├── zone_transfer.txt
│   └── asn_info.json
└── RECONBAY_REPORT.txt          ← Full summary report
```

---

## Configuration

Stored in `~/.reconbay/config`:

```bash
GITHUB_TOKENS="ghp_token1,ghp_token2"   # comma-separated
CHAOS_KEY="your-chaos-key"
SHODAN_KEY="your-shodan-key"
```

Re-run `sudo bash install.sh` anytime to update tokens.

---

## GitHub Tokens

GitHub recon dramatically improves subdomain coverage by scanning public code.

1. Go to https://github.com/settings/tokens
2. Create a **Classic Token** with scopes: `read:org`, `public_repo`
3. Add during `install.sh` or paste into `~/.reconbay/config`

You can add **multiple tokens** (comma-separated) to increase rate limits.

---

## Legal

This tool is built for **authorized** bug bounty programs and penetration tests only.  
Always ensure you have written permission before scanning any target.

---

*ReconBay v2.0 — Author: Nipun Dilshan*
