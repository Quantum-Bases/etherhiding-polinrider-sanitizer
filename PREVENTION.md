# Preventing EtherHiding / PolinRider Supply Chain Attacks

**Comprehensive Prevention Guide for Future Protection**

---

## 📍 Quick Start: 5-Minute Defense

Apply these settings immediately to prevent most attacks:

### 1. Disable VS Code Auto-Tasks (1 minute)
Press **Cmd+Shift+P** (Mac) or **Ctrl+Shift+P** (Windows/Linux), then run "Preferences: Open User Settings (JSON)" and add:

```json
{
  "task.allowAutomaticTasks": "off",
  "security.workspace.trust.enabled": true
}
```

**⚠️ CRITICAL:** Do this in **all** VS Code forks:
- Cursor: `~/Library/Application Support/Cursor/User/settings.json`
- Windsurf: `~/Library/Application Support/Windsurf/User/settings.json`
- VSCodium: `~/.config/VSCodium/User/settings.json`

### 2. Add Global Gitignore (1 minute)
```bash
# Set up global gitignore (one-time)
git config --global core.excludesfile ~/.gitignore_global

# Add editor config that should never be committed
cat >> ~/.gitignore_global <<'EOF'
.vscode/
.idea/
.devcontainer/
*.code-workspace
EOF
```

### 3. Trust Intentionally, Not Reflexively (2 minutes)
- **Trust** repositories you maintain
- **Restrict** repositories you review
- Never click "Yes, I trust the authors" automatically

### 4. Pre-Open Inspection (1 minute before opening any repo)
```bash
# After cloning, before opening:
cat .vscode/tasks.json 2>/dev/null | grep -A3 folderOpen

# Before checking out a PR branch:
git diff main..review-branch -- .vscode/ .devcontainer/ package.json
```

---

## 🛡️ Defense Layers

### Layer 1: Editor Hardening (VS Code & Forks)

#### **Step 1A: Disable Automatic Task Execution**
This is the highest-impact change.

**Settings to add:**
```json
{
  "task.allowAutomaticTasks": "off",
  "security.workspace.trust.enabled": true,
  "security.workspace.trust.startupPrompt": "always"
}
```

**What this prevents:**
- Tasks running on folder open
- Silent code execution before you review
- Malicious npm install postinstall scripts
- Devcontainer initialization commands

**What this does NOT prevent:**
- Code execution after you explicitly trust the folder
- Manual task runs
- npm packages with actual vulnerabilities

#### **Step 1B: Verify Settings in ALL Editors**
Each VS Code fork keeps separate settings:

```bash
# Check which editors are installed
ls -la ~/Library/Application\ Support/ | grep -E "Code|Cursor|Windsurf|VSCodium"

# Apply settings to each
# macOS
cat >> ~/Library/Application\ Support/Code/User/settings.json <<'EOF'
  "task.allowAutomaticTasks": "off",
  "security.workspace.trust.enabled": true
EOF

cat >> ~/Library/Application\ Support/Cursor/User/settings.json <<'EOF'
  "task.allowAutomaticTasks": "off",
  "security.workspace.trust.enabled": true
EOF
```

#### **Step 1C: Disable Dangerous Extensions**
Some extensions auto-run code. Common risks:
- Pre-commit hooks runners
- Language servers without verification
- Typosquatted package names

**Mitigation:**
- Review installed extensions quarterly
- Uninstall unused extensions
- Use `.vscode/extensions.json` only with team codeowners

---

### Layer 2: Repository Security

#### **Step 2A: Block .vscode from Shared Repos**
Executive rule: **Never commit `.vscode/tasks.json` to shared repositories.**

**Option A: No .vscode at all**
```bash
# Add to repo's .gitignore
echo ".vscode/" >> .gitignore
```

**Option B: Shared settings only (with protections)**
```bash
# .github/CODEOWNERS - Require review for files that can execute
.vscode/          @your-org/platform-team
.devcontainer/    @your-org/platform-team
package.json      @your-org/platform-team
Dockerfile        @your-org/platform-team
docker-compose.yml @your-org/platform-team
```

#### **Step 2B: Code Review Security**

**Before reviewing a PR, check:**
```bash
git fetch origin pull/<PR>/head:review-pr

# Does it modify execution-path files?
git diff main..review-pr -- \
  .vscode/ \
  .devcontainer/ \
  .husky/ \
  package.json \
  Dockerfile \
  docker-compose.yml \
  Makefile \
  scripts/

# Red flags:
# - Changes to .vscode/tasks.json (suspicious)
# - Changes to package.json from typo fix PR (very suspicious)
# - Added .bat files or PowerShell scripts
# - New font/image files that are actually text
```

**Read from terminal, don't open in editor:**
```bash
# ❌ DON'T DO THIS:
code repo/  # If suspicious, don't open

# ✅ DO THIS:
cat repo/.vscode/tasks.json
git show HEAD:.vscode/tasks.json
file repo/fonts/fa-solid-400.woff2  # Check if it's really a font
```

**Close immediately if you spot:**
- Suspicious .vscode modifications
- Auto-execute tasks
- New persistence files
- Unexpected npm/build commands

#### **Step 2C: Check for Hidden Threats**
```bash
# Find "fonts" that are actually executable code
find . -name '*.woff2' -o -name '*.ttf' -o -name '*.otf' | while read f; do
  file "$f" | grep -q 'ASCII text' && echo "⚠️ SUSPECT: $f is text, not binary!"
done

# Look for suspicious .bat files
find . -name '*.bat' -o -name '*.ps1' | grep -v node_modules

# Check for git hook manipulation
cat .git/config | grep hooksPath

# Search for obfuscated variable patterns
grep -r 'global\.i\|_0x[a-f0-9]\|A8-' . --exclude-dir=node_modules --exclude-dir=.git
```

---

### Layer 3: Dependency Security

#### **Step 3A: npm Install Safely**
```bash
# Don't run postinstall scripts from untrusted sources
npm install --ignore-scripts

# Only run if you've reviewed package.json
npm install  # After code review
```

**In package.json, always review:**
```json
{
  "devDependencies": {},
  "scripts": {
    "postinstall": "← REVIEW THIS",
    "preinstall": "← REVIEW THIS",
    "prepare": "← REVIEW THIS"
  }
}
```

#### **Step 3B: Lock Files Matter**
- **Commit** `package-lock.json` and `yarn.lock`
- **Verify** checksums haven't changed unexpectedly
- **Review** major version bumps in deps

```bash
# Check what changed in dependencies
git diff main -- package.json package-lock.json

# Verify integrity
npm audit
```

#### **Step 3C: Dependency Scanning**
```bash
# Check for known vulnerabilities
npm audit

# List all installed packages
npm list --depth=0

# Verify package integrity
npm verify
```

---

### Layer 4: Git Security

#### **Step 4A: Disable Auto-Running Git Hooks**
EthBider creates `.husky/` hooks that auto-execute.

```bash
# Check what hooks are configured
ls -la .git/hooks/
ls -la .husky/ 2>/dev/null

# Verify core.hooksPath isn't malicious
git config --global core.hooksPath

# Before running scripts
cat .husky/pre-commit
cat .husky/post-checkout
```

#### **Step 4B: Review Before Pulling**
```bash
# See what changed before pulling
git fetch origin

# Check for suspicious additions
git diff main..origin/main -- .husky/ .github/workflows/ scripts/

# Only then pull if safe
git pull
```

---

### Layer 5: Development Environment

#### **Step 5A: Environment Variable Protection**
Create a `.env.example` (always committed) and `.env` (never committed):

```bash
# .env (add to .gitignore)
npm_token=xxxxx
github_token=xxxxx
aws_access_key=xxxxx

# .env.example (in git)
npm_token=CHANGEME
github_token=CHANGEME
aws_access_key=CHANGEME
```

**Why:** If malware runs, it grabs tokens from `.env`, not the example.

#### **Step 5B: SSH Key Hardening**
```bash
# Use SSH keys with passphrases
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Add key with passphrase
ssh-add ~/.ssh/id_ed25519

# Use SSH config for key management
cat ~/.ssh/config
```

#### **Step 5C: Git Credentials Config**
Don't use plaintext credentials:
```bash
# Use SSH instead of HTTPS
git remote set-url origin git@github.com:owner/repo.git

# Or use credential helper with encrypted storage
git config --global credential.helper osxkeychain  # macOS
git config --global credential.helper pass         # Linux
```

---

### Layer 6: Team & Organizational Practices

#### **Step 6A: Supply Chain Policy**
Create a security policy for your organization:

```markdown
## GitHub Organization Security Policy

### Required Settings
- [ ] Two-factor authentication (2FA) required
- [ ] Protected branches: require code review
- [ ] No direct pushes to main/develop
- [ ] Branch protection rules enforced
- [ ] Signed commits required (for critical repos)

### Code Review Requirements
- [ ] Two reviewers for main branch
- [ ] Security team reviews if .vscode changes
- [ ] Platform team reviews if CI/CD changes
- [ ] Automated scanning enabled

### Developer Requirements
- [ ] Disable auto-tasks in VS Code
- [ ] Global .gitignore configured
- [ ] 2FA enabled on GitHub account
- [ ] SSH keys with passphrases
- [ ] Credential rotation quarterly
```

#### **Step 6B: Onboarding Checklist**
When new team members join:

```bash
#!/bin/bash
# New developer security setup

echo "🔒 Developer Security Onboarding"

# 1. VS Code hardening
echo "1. Configuring VS Code..."
mkdir -p ~/Library/Application\ Support/Code/User
cat >> ~/Library/Application\ Support/Code/User/settings.json <<EOF
  "task.allowAutomaticTasks": "off",
  "security.workspace.trust.enabled": true
EOF

# 2. Global gitignore
echo "2. Setting up global gitignore..."
git config --global core.excludesfile ~/.gitignore_global
cat >> ~/.gitignore_global <<'EOF'
.vscode/
.idea/
.devcontainer/
*.code-workspace
EOF

# 3. SSH key generation
echo "3. Generate SSH key..."
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# 4. 2FA setup
echo "4. Enable GitHub 2FA"
echo "Visit: https://github.com/settings/security/two-factor-authentication"

echo "✅ Setup complete!"
```

#### **Step 6C: Regular Audits**
```bash
# Monthly: Audit all repos for suspicious patterns
./verify.sh > monthly_audit_$(date +%Y%m%d).txt

# Quarterly: Review dependencies
npm audit fix
npm outdated

# Quarterly: Rotate credentials
# - npm tokens
# - GitHub PATs
# - SSH keys
# - Cloud credentials

# Annually: Security training
# - Supply chain attacks
# - Social engineering
# - Insider threats
```

#### **Step 6D: Incident Response Plan**
When a developer thinks they opened something malicious:

```bash
# 1. STOP - Don't delete anything, don't panic
# 2. Isolate: Disconnect from internet if critically exposed
# 3. Check: See what ran and what changed
ls -la ~/Library/LaunchAgents/     # macOS
crontab -l
tail -20 ~/.zshrc ~/.bashrc
cat ~/.ssh/authorized_keys
grep -r "A8-" ~/ --exclude-dir=.git 2>/dev/null

# 4. ROTATE credentials immediately
# Priority order (highest blast radius first):
#   1. Cloud credentials (AWS, Azure, GCP)
#   2. GitHub/GitLab tokens with push access
#   3. npm registry tokens
#   4. SSH keys
#   5. Database credentials

# 5. NOTIFY: Tell security/platform team if:
#   - Machine can reach production
#   - Credentials touched production systems
#   - Malware propagated to other machines
```

---

## 🔍 Detection: What to Watch For

### Files That Should Never Be Committed

```bash
# Font files that are actually scripts
*.woff2, *.ttf, *.otf (if text content)

# Batch scripts
*.bat, *.cmd, *.ps1

# Suspicious loader files
.pnp.loader.mjs
temp_auto_push.bat
temp_interactive_push.bat
branch_structure.json

# Untracked .vscode/tasks.json additions
```

### Code Patterns That Signal Malware

```javascript
// ❌ Red flag: hex-encoded C2 identifier

global["i"]="A8-abc123xyz"

// ❌ Red flag: obfuscated variable declarations
const _0x3847a=_0x928fa8;

// ❌ Red flag: createRequire from node/module
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

// ❌ Red flag: executing random binary
command": "node ./public/fonts/fa-solid-400.woff2"
```

### Malicious Task Pattern

```json
{
  "label": "eslint-check",
  "type": "shell",
  "command": "node ./public/fonts/fa-solid-400.woff2",
  "hide": true,
  "presentation": { "reveal": "never", "close": true },
  "runOptions": { "runOn": "folderOpen" }
}
```

**Why it works:**
- `label`: Sounds legitimate
- `hide`: true: User never sees anything
- `runOn: folderOpen`: Runs immediately when folder opens
- `reveal: never`: Terminal window never appears
- `command`: Points to "font" that's actually JavaScript

---

## 📋 Prevention Checklist

### Individual Developer ✓
- [ ] Disable `task.allowAutomaticTasks` in VS Code
- [ ] Enable `security.workspace.trust.enabled`
- [ ] Set up global `.gitignore` with `.vscode/`
- [ ] Generate SSH key with passphrase
- [ ] Enable 2FA on GitHub
- [ ] Never click "trust authors" reflexively
- [ ] Inspect `.vscode/tasks.json` before opening
- [ ] Review PR diffs for `.vscode/` changes before checking out
- [ ] Use `npm install --ignore-scripts` for untrusted repos
- [ ] Rotate credentials quarterly

### Team Lead ✓
- [ ] Enforce 2FA for all team members
- [ ] Set up CODEOWNERS for critical files
- [ ] Require code review (2 reviewers minimum)
- [ ] Prohibit `.vscode/tasks.json` from repos
- [ ] Monthly: Run `verify.sh` on all repos
- [ ] Quarterly: Audit dependencies with `npm audit`
- [ ] Quarterly: Rotate team credentials
- [ ] Annually: Security training + threat updates
- [ ] Create incident response playbook
- [ ] Test incident response quarterly

### Organization ✓
- [ ] Document supply chain security policy
- [ ] Require branch protection rules
- [ ] Enable organization-wide 2FA requirement
- [ ] Set up SAML/SSO for access control
- [ ] Regular penetration testing
- [ ] Threat intelligence integration
- [ ] Incident response SOP documented
- [ ] Security audit trails enabled
- [ ] Monitoring + alerts configured
- [ ] Annual security assessment

---

## 🚨 Other Attack Vectors to Know

Besides VS Code tasks.json, EthBider also exploits:

### npm postinstall Scripts
```bash
# Dangerous:
npm install  # Runs postinstall

# Safe:
npm install --ignore-scripts  # Review first
npm ci --ignore-scripts        # Then run after review
```

### Git Hooks (.husky/)
```bash
# Check what hooks exist
ls -la .husky/

# Review before committing
cat .husky/pre-commit
cat .husky/post-checkout
```

### Devcontainers
```bash
# Can run commands on your HOST machine
cat .devcontainer/devcontainer.json | grep -A5 initializeCommand
```

### Recommended Extensions
```bash
# .vscode/extensions.json
# Check for typosquatted or malicious extensions before opening
```

---

## 📚 References & Further Reading

- **VS Code Task Attack:** https://zainmustafaaa.dev/blog/vscode-tasks-json-git-repo-attack-auto-run
- **OWASP Supply Chain:** https://owasp.org/www-community/Supply_Chain_Attack
- **npm Security:** https://docs.npmjs.com/cli/v8/commands/npm-audit
- **GitHub Security:** https://docs.github.com/en/code-security
- **Git Hooks Security:** https://githooks.com/

---

## ⚡ One-Liner Hardening Commands

```bash
# Add all protections in one go
git config --global core.excludesfile ~/.gitignore_global && \
cat >> ~/.gitignore_global <<'EOF'
.vscode/
.idea/
.devcontainer/
*.code-workspace
EOF

# Verify protections
echo "VS Code hardening:"
grep -c "task.allowAutomaticTasks" ~/Library/Application\ Support/Code/User/settings.json 2>/dev/null || echo "⚠️ Not configured"

echo "Global gitignore:"
git config --global core.excludesfile

echo "SSH keys:"
ls -la ~/.ssh/
```

---

## 🎯 Goal

The goal of prevention is simple:

**Code execution should never be automatic. It should always be intentional.**

Two settings, one habit, one gitignore line. That's the trade against a threat that costs an attacker a single committed file.

Make it your practice, and EtherHiding / PolinRider can't touch you.

---

**Last Updated:** August 28, 2026  
**Status:** Actively maintained  
**Questions?** See README.md for incident response tools
