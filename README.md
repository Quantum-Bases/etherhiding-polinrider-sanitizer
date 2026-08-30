# etherhiding-sanitizer

**Automated Zero-Trust Incident Response Toolkit**

A comprehensive security automation script designed to detect, sanitize, and eradicate `EtherHiding / PolinRider` supply-chain malware across GitHub organizations and repositories without requiring local code execution.

---

## 🚨 Threat Overview

**EtherHiding** (also known as **PolinRider**) is a sophisticated supply-chain malware that:

- Injects obfuscated C2 (Command & Control) payloads into JavaScript/TypeScript files
- Embeds rogue Font Asset files (WOFF, TTF, OTF) with malicious payloads
- Modifies VS Code task configurations to auto-execute malicious scripts
- Creates persistence mechanisms via `.bat` files and `require()` loaders
- Targets development environments and CI/CD pipelines
- Chains multiple evasion techniques including hex encoding and variable obfuscation

### Attack Toolchain Diagram

![EtherHiding Attack Toolchain](https://www.cyber.gc.ca/sites/default/files/images/etherhiding-trojan-toolchain-fig1-e-800x641.png)

*Source: Canadian Centre for Cyber Security - Supply Chain Attack Analysis*

---

## 📁 Documentation Structure

This repository includes three key documents:

| Document | Purpose | When to Read |
|----------|---------|-------------|
| **README.md** | Tool overview, usage, installation | Getting started |
| **[INCIDENT_REPORT.md](INCIDENT_REPORT.md)** | Technical incident analysis & details | Understanding the threat |
| **[PREVENTION.md](PREVENTION.md)** | Future attack prevention strategies | Long-term defense |

For **technical incident details** from the Gemini security analysis, see [INCIDENT_REPORT.md](INCIDENT_REPORT.md).

For **prevention** strategies to protect against future attacks, see [PREVENTION.md](PREVENTION.md).

---

## 📚 Quick Reference: Two Scripts

| Feature | `verify.sh` | `sanitize.sh` |
|---------|-----------|--------------|
| **Purpose** | Audit-only (detect threats) | Cleanup (remove threats) |
| **Modifications** | None | Yes (commits & pushes) |
| **Use Case** | Pre-incident assessment | Post-incident remediation |
| **Speed** | Faster (shallow clone) | Slower (full processing) |
| **Risk Level** | None | Medium (write access needed) |
| **Recommended Order** | Run first (1️⃣) | Run second (2️⃣) |

---

## ✨ Key Features

✅ **Automated Detection & Removal** - Scans all repositories in GitHub organizations  
✅ **Multi-Branch Processing** - Cleans all branches: main, develop, feature branches, etc.  
✅ **Cross-Platform Compatible** - Works on macOS and Linux  
✅ **Non-Destructive** - Creates commits documenting all removals  
✅ **Zero Local Code Execution** - Uses GitHub API for authentication and verification  
✅ **Comprehensive Pattern Matching** - Detects multiple malware variants and obfuscation techniques  

---

## 📋 Prerequisites

Before running this script, ensure you have:

### 1. **GitHub CLI Installation**
```bash
# macOS (using Homebrew)
brew install gh

# Ubuntu/Debian
sudo apt-get install gh

# Other OS - visit: https://github.com/cli/cli/releases
```

### 2. **GitHub Authentication**
Authenticate with GitHub CLI using a Personal Access Token (PAT):
```bash
gh auth login
```

You'll need these **scopes** on your PAT:
- `repo` - Full control of repositories
- `admin:org_hook` - For organization-level access (if managing org repos)

### 3. **Git Installation**
```bash
# macOS
brew install git

# Ubuntu/Debian
sudo apt-get install git

# Verify installation
git --version
```

### 4. **Bash Shell**
- Minimum version: `bash 4.0`
- Check with: `bash --version`

### 5. **Write Access**
- Must have write permissions to all target repositories
- Must have admin access to the GitHub organizations

---

## 🚀 Installation & Setup

### Step 1: Clone This Repository
```bash
git clone https://github.com/your-username/ethbider-polinrider-sanitizer.git
cd ethbider-polinrider-sanitizer
chmod +x sanitize.sh verify.sh
```

### Step 2: Configure Target Organizations
Edit **both** scripts and update the `TARGETS` array with your organizations:

```bash
# Line 6 in sanitize.sh and verify.sh
TARGETS=("my-org-1" "my-org-2" "my-username" "company-github")
```

### Step 3: Review Security Settings
Before running:
- Ensure you have write access to all target repositories (for sanitize.sh)
- Backup critical repositories if needed
- Test in a non-production environment first
- Consider running `verify.sh` first for audit

### Step 4a: Audit with Verification Script (Recommended First Step)
```bash
# Run audit-only (no modifications)
./verify.sh
```

### Step 4b: Execute Sanitization Script
```bash
# Run sanitization (makes modifications and commits)
./sanitize.sh
```

---

## 🔧 How It Works

### Execution Flow

The script processes repositories in this order:

```
1. Create temporary workspace directory
│
2. For each target organization:
   ├── List all repositories (up to 300) via GitHub API
   │
   └── For each repository:
       ├── Clone the repository to temp directory
       ├── Fetch all remote branches
       │
       └── For each remote branch:
           ├── Checkout the branch locally
           ├── Remove malicious files
           ├── Strip C2 payloads
           ├── Clean configuration files
           ├── Commit all changes
           └── Push sanitized branch back to remote
       │
       └── Delete temporary clone
│
3. Delete temporary workspace (cleanup)
```

### Key Implementation Details

- **Temporary Cloning**: Repositories are cloned to a temporary directory (`/tmp/...`) for processing
- **No Permanent Local Copies**: After processing each repository, the local clone is deleted
- **Remote Processing**: All changes are committed and pushed back to GitHub remote branches
- **Branch-by-Branch**: Each branch is checked out locally, cleaned, and pushed individually
- **Cleanup**: The entire temporary workspace is removed after all organizations are processed

This approach ensures:
✅ No lingering local copies on the system  
✅ All modifications are tracked in git history  
✅ Remote branches are updated with cleaned code  
✅ Failed/inaccessible repos don't block entire run

### Removal Strategy

The script removes malware in **6 stages**:

#### **Stage 1: Purge Rogue Fonts & Asset Directories**
- Removes font files: `*.woff`, `*.woff2`, `*.eot`, `*.svg`, `*.ttf`, `*.otf`
- Targets files matching patterns: `fa-*.js`, `*banner*`, `*solid*`
- Removes font metadata: `README`, `LICENSE`, `OFL` files in font directories

```bash
# Removes files like:
# - fonts/fa-solid-400.woff2
# - assets/banner-fa.svg
# - lib/solid-icons.eot
```

#### **Stage 2: Eradicate VS Code Auto-Tasks & Settings**
- Detects and removes `.vscode/tasks.json` containing suspicious task definitions
- Removes auto-task enablement from `.vscode/settings.json`
- Targets patterns: `fa-solid-400`, `eslint-check`, `folderOpen` commands

```bash
# Removes auto-executing tasks that invoke:
# - C2 communication payloads
# - Rogue npm/node commands
# - Persistence mechanisms
```

#### **Stage 3: Strip Obfuscated C2 Payloads & Loaders**
Removes embedded command-and-control code:

- **Hex-encoded Global Variables**: `global.i["A8-..."]` patterns
- **Obfuscated Functions**: `_0x[a-f0-9]+=_0x[a-f0-9]+` declarations
- **Module Loaders**: `createRequire()` import statements
- **Dynamic Require Assignments**: `const require = createRequire(...)`

```bash
# Removes lines like:
#
# const _0x3847a=_0x928fa8;
# import { createRequire } from 'module';
```

#### **Stage 4: Remove Dropper Persistence Files**
Deletes files used for persistence and lateral movement:
- `temp_auto_push.bat` - Windows batch persistence
- `temp_interactive_push.bat` - Interactive push automation
- `branch_structure.json` - Branch enumeration data
- `.pnp.loader.mjs` - Node.js loader hook

#### **Stage 5: Clean .gitignore Modifications**
Removes entries added by malware to hide persistence:
- `branch_structure.json`
- `temp_auto_push.bat`
- `temp_interactive_push.bat`

Prevents re-hiding of malware if `.gitignore` is reset.

#### **Stage 6: Commit and Push Clean Branch**
- Stages all changes using `git add -A`
- Creates audit commit: "security: eradicate EthBider rogue font payloads and C2 loaders"
- Pushes to remote with author name: "Security Sanitizer"
- If changes were made, branch is marked clean with confirmation

---

## 📊 Output & Logging

### Console Output Format

```
==================================================
🚀 Processing Target: my-org
==================================================
----------------------------------------
🔍 Auditing: my-org/repo-1
🧹 Purging .vscode/tasks.json from my-org/repo-1 [main]
🚨 Purged infected files on [main]. Pushing...
✅ Branch [main] cleaned.
----------------------------------------
🔍 Auditing: my-org/repo-2
⚠️ Skipping my-org/repo-2 (empty or inaccessible)
```

### Status Indicators

- 🚀 = Starting processing of organization
- 🔍 = Scanning repository
- 🧹 = Removing malicious files
- 🚨 = Infected files found and removed
- ✅ = Branch successfully cleaned
- ⚠️ = Warning/skipped (inaccessible repo)

### Audit Trail

Each sanitized repository will have:
- Git commit with timestamp and security message
- Full git history showing before/after
- Author marked as "Security Sanitizer" for identification

---

## 🔍 Verification & Audit (`verify.sh`)

The `verify.sh` script provides **read-only incident detection** without making any modifications. Use this to identify EtherHiding / PolinRider-infected repositories before running the sanitizer.

### Features

✅ **Non-Destructive** - No files are modified or deleted  
✅ **Audit Mode** - Scan-only, perfect for assessment and reporting  
✅ **Threat Counting** - Reports total number of threat instances detected  
✅ **Detailed Output** - Shows exact file locations and branch information  
✅ **Shallow Cloning** - Uses `--depth=1` for faster scanning  

### Usage

```bash
# 1. Configure target organizations (same as sanitize.sh)
# Edit line 6 in verify.sh:
TARGETS=("my-org-1" "my-org-2" "my-username")

# 2. Run verification
./verify.sh

# 3. Review output report
```

### Output Example

```
==================================================
🔍 STARTING DEEP INCIDENT AUDIT (EtherHiding / PolinRider)
==================================================
Auditing Target: my-org...
❌ [THREAT FOUND] Rogue Font in my-org/repo-1 [main]:
./fonts/fa-solid-400.woff2
❌ [THREAT FOUND] Malicious VS Code Task in my-org/repo-1 [main]
❌ [THREAT FOUND] Injected C2 Code in my-org/repo-2 [develop]:
./src/index.js:15:
==================================================
⚠️ Audit detected 3 threat instances.
==================================================
```

### Detection Stages

#### **Detection 1: Rogue Font Assets**
Scans for malicious font files:
- `fa-solid-400.woff2`
- `fa-solid-900.*`
- `fa-regular-400.*`
- `fa-brands-400.*`

These fonts often contain embedded malware payloads.

#### **Detection 2: Malicious VS Code Tasks**
Searches `.vscode/tasks.json` for auto-executing tasks with patterns:
- `fa-solid-400` - Font references
- `woff2` - Font format
- `folderOpen` - Auto-open triggers
- `command -v node` - Node execution
- `eslint-check` - Build-time execution hooks

#### **Detection 3: Injected C2 Payloads**
Searches all code files for command-and-control indicators:
- `
- `global[.i]` variants - Obfuscated global access
- `branch_structure.json` - Branch enumeration artifact
- `temp_auto_push.bat` - Persistence batch file

**Excludes:** `.git`, `node_modules`, `dist`, `build`, `.next` + binary files

### Workflow: Verify → Sanitize

**Recommended incident response workflow:**

```bash
# Step 1: Verify/Audit
./verify.sh > audit_report.txt 2>&1

# Step 2: Review threats
cat audit_report.txt

# Step 3: If threats found, sanitize
./sanitize.sh

# Step 4: Verify cleanup
./verify.sh

# Expected: ✅ 100% CLEAN! message
```

### Comparing Before & After

```bash
# Before sanitization
$ ./verify.sh
⚠️ Audit detected 15 threat instances.

# After sanitization
$ ./verify.sh
✅ 100% CLEAN! Zero malware signatures, rogue tasks, or C2 loaders found.
```

### Performance

- **Speed**: 2-5 seconds per repository (shallow clone)
- **Faster than sanitize**: Uses `--depth=1` shallow clone
- **No modifications**: Only reads, no push operations
- **Low bandwidth**: Minimal data transfer required

---

## ⚙️ Configuration Guide

### Customizing Target Organizations

Edit line 6 in both scripts:

```bash
# sanitize.sh or verify.sh - Line 6
# Default
TARGETS=("Your-Org-1" "Your-Org-2" "Your-Username")

# Example: Multi-organization setup
TARGETS=("github" "microsoft" "google" "my-company" "my-username")
```

### Repository Limit

Modify line 27 to scan more/fewer repositories:

```bash
# Current: 300 repositories per organization
REPOS=$(gh repo list "$TARGET" --limit 300 ...)

# To scan only 50 repositories
REPOS=$(gh repo list "$TARGET" --limit 50 ...)

# To scan all repositories (may take time)
REPOS=$(gh repo list "$TARGET" --limit 1000 ...)
```

This setting is common to both `sanitize.sh` and `verify.sh`.

### Custom Commit Message

Modify the commit message on line 97:

```bash
# Current
git commit -m "security: eradicate EtherHiding / PolinRider rogue font payloads and C2 loaders"

# Custom example
git commit -m "security: patch EthBider/PolinRider supply-chain malware [URGENT]"
```

### Git User Configuration

Update author information on lines 95-96:

```bash
git config user.name "Security Sanitizer"
git config user.email "security@example.com"
```

---

## 🛡️ Safety Considerations

### What This Script Does

✅ **Safe Operations:**
- Only removes known malware patterns
- Creates git commits for audit trail
- Skips inaccessible repositories
- Works on cloned copies (doesn't touch local repos)
- Runs git hooks in sandbox (no local execution)

### What This Script Does NOT Do

❌ **Won't:**
- Delete entire repositories
- Modify repository settings/permissions
- Execute code locally
- Backup repositories (you should do this separately)
- Modify .git configuration

### Backup Recommendations

Before running on production:

```bash
# 1. Create local backups
for org in "org1" "org2"; do
  gh repo list "$org" --limit 300 --json url -q '.[].url' | \
  xargs -I {} git clone {} ~/backups/{}
done

# 2. Test on a single repository first
# 3. Run during low-traffic periods
# 4. Have git pushes reviewed by team
```

---

## 📟 Usage Examples

### Verifying Clean State (Read-Only Audit)
```bash
./verify.sh
# Output: ✅ 100% CLEAN! Zero malware signatures...
# Output: ⚠️ Audit detected X threat instances.
```

### Basic Sanitization - Single Organization
```bash
./sanitize.sh
# With TARGETS=("my-org")
# Cleans all repositories in my-org
```

### Full Incident Response Workflow
```bash
# Step 1: Verify current state
./verify.sh > pre-audit.txt

# Step 2: Review threats
cat pre-audit.txt

# Step 3: Run sanitization
./sanitize.sh

# Step 4: Verify cleanup
./verify.sh > post-audit.txt

# Step 5: Compare results
diff pre-audit.txt post-audit.txt
```

### Multiple Organizations
```bash
# Edit verify.sh or sanitize.sh
TARGETS=("org-1" "org-2" "org-3" "personal-username")

# Verify all
./verify.sh

# Sanitize all
./sanitize.sh
```

### Test Run (Dry-Run Alternative)
```bash
# Clone a single test repo manually
git clone https://github.com/my-org/test-repo.git
cd test-repo
git fetch --all

# Run individual cleanup commands on a branch
# Then review before pushing
```

### Checking Results
```bash
# View commits made by Security Sanitizer
git log --author="Security Sanitizer" --oneline

# Compare before/after
git log -p --author="Security Sanitizer"
```

### Generating Audit Reports
```bash
# Save verification report
./verify.sh > audit_report_$(date +%Y%m%d).txt

# Save sanitization log
./sanitize.sh 2>&1 | tee sanitize_log_$(date +%Y%m%d).txt
```

---

## 🐛 Troubleshooting

### Issue: "gh: command not found"
**Solution:**
```bash
# Install GitHub CLI
brew install gh  # macOS
sudo apt-get install gh  # Ubuntu/Debian

# Verify installation
which gh
gh version
```

### Issue: "Error: authentication required"
**Solution:**
```bash
# Re-authenticate with GitHub
gh auth logout
gh auth login

# Select: GitHub.com
# Select: HTTPS
# Provide Personal Access Token with repo + admin:org_hook scopes
```

### Issue: "Permission denied" on repositories
**Solution:**
```bash
# Verify your GitHub user has write access
gh repo list --limit 1

# Check if you have organization admin rights
# Contact organization admin if access is missing
```

### Issue: "fatal: could not read Username"
**Solution:**
```bash
# Ensure git credentials are cached
git config --global credential.helper store
gh auth setup-git
```

### Issue: "Skipping repository (empty or inaccessible)"
**Causes:**
- Repository requires authentication
- Repository is being deleted/archived
- GitHub API rate limit exceeded

**Solution:**
```bash
# Check rate limit
gh rate-limit

# If rate-limited, wait 1 hour or:
gh auth refresh --scopes repo,admin:org_hook
```

---

## 📊 Performance & Runtime

- **Typical speed**: 10-20 seconds per repository
- **Slower factors**:
  - Large repositories (100+ MB)
  - Many branches (50+)
  - Network latency
  - GitHub API rate limiting

### Estimated Runtime

```
Total Time = (Number of Orgs) × (Repos per Org) × (Branches per Repo) × (20 seconds)

Example:
- 2 organizations
- 100 repos per org
- 5 branches average
- = 2 × 100 × 5 × 20sec = 16,666 seconds ≈ 4.6 hours
```

---

## 🔍 What Gets Detected & Removed

### Malicious Patterns Removed

| Pattern | Detection | Example |
|---------|-----------|---------|
| Font Files | WOFF/TTF payloads | `fa-solid-400.woff2` |
| Global Variables | C2 identifiers | `global.i["A8-abc123"]` |
| Obfuscated Functions | Hidden loaders | `const _0x3847a=_0x928fa8;` |
| Module Imports | `createRequire()` | `import { createRequire } from 'module'` |
| Batch Scripts | Persistence files | `temp_auto_push.bat` |
| VS Code Tasks | Auto-execution | `.vscode/tasks.json` |

---

## 📝 Commit Information

All sanitized branches will show commits like:

```
commit 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
Author: Security Sanitizer <security@cleanup.local>
Date:   Thu Aug 28 10:15:00 2026 -0700

    security: eradicate EthBider rogue font payloads and C2 loaders
    
    Removed files:
    - .vscode/tasks.json
    - fonts/fa-solid-400.woff2
    - src/loaders/index.js (stripped C2 payload)
```

---

## 🤝 Contributing

Found additional malware patterns? Submit improvements:

1. Test new patterns locally
2. Document the malware signature
3. Add pattern to appropriate stage in script
4. Submit pull request with test cases

---

## 📄 License

See [LICENSE](LICENSE) file for details.

---

## ⚠️ Disclaimer

This tool is provided as-is for incident response purposes. Users are responsible for:
- Verifying repository backups
- Testing in non-production first
- Compliance with organizational policies
- Audit and review of all changes
- Legal implications of code modifications

**Always verify changes before production deployment.**

---

## 📞 Support & Questions

For issues or questions:
1. Check [Troubleshooting](#-troubleshooting) section
2. Review GitHub issues in this repository
3. Verify GitHub CLI installation and authentication
4. Check repository access permissions

---

**Last Updated:** August 28, 2026  
**Threat Level:** CRITICAL  
**Status:** Actively maintained
