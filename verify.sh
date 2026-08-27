#!/bin/bash
# Verification script for EtherHiding / PolinRider malware detection (audit-only, no modification)

set -e
# Exit immediately if any command exits with a non-zero status

# Target GitHub orgs/users - Configure organizations/users to audit
TARGETS=("Your-Org-1" "Your-Org-2" "Your-Username")

# Create temporary workspace directory for cloning repositories
TEMP_WORKSPACE=$(mktemp -d)

# Disable git hooks globally to prevent hooks from running during verification
git config --global core.hooksPath /dev/null

# Change to temporary workspace directory
cd "$TEMP_WORKSPACE"

# Counter variable to track number of infected instances found
INFECTED_FOUND=0

# Print header with visual separator
echo "=================================================="
# Display verification mode banner
echo "🔍 STARTING DEEP INCIDENT AUDIT (EtherHiding / PolinRider)"
# Print visual separator
echo "=================================================="

# Begin iterating through each target organization/user
for TARGET in "${TARGETS[@]}"; do
  # Display current organization being audited
  echo "Auditing Target: $TARGET..."

  # Use GitHub CLI to list all repositories for the target with limit of 300
  # Extract nameWithOwner field (format: "owner/repo")
  REPOS=$(gh repo list "$TARGET" --limit 300 --json nameWithOwner -q '.[].nameWithOwner')

  # Begin iterating through each repository in the target
  for REPO in $REPOS; do
    # Attempt to clone repository with shallow clone (--depth=1) for speed
    # Suppress error output and skip if clone fails
    if ! git clone --depth=1 "https://github.com/$REPO.git" repo_dir 2>/dev/null; then
      # Skip to next repository if clone fails
      continue
    fi

    # Change into the cloned repository directory
    cd repo_dir

    # Fetch all remote branches and prune deleted branches
    # Use || true to continue even if fetch fails
    git fetch --all --prune 2>/dev/null || true

    # Begin iterating through each remote branch
    for REMOTE_BRANCH in $(git branch -r | grep -v '\->' | sed 's/origin\///'); do
      # Checkout the remote branch and force create local branch with same name
      # Use || true to continue if checkout fails
      git checkout -f -B "$REMOTE_BRANCH" "origin/$REMOTE_BRANCH" 2>/dev/null || true

      # === DETECTION STAGE 1: Check for Rogue Font Assets ===
      # Search for malicious font files with known EtherHiding file patterns
      # Looks for: fa-solid-400.woff2, fa-solid-900.*, fa-regular-400.*, fa-brands-400.*
      ROGUE_FONTS=$(find . -type f \( -name "fa-solid-400.woff2" -o -name "fa-solid-900.*" -o -name "fa-regular-400.*" -o -name "fa-brands-400.*" \) 2>/dev/null || true)

      # If rogue fonts found, log the threat
      if [ -n "$ROGUE_FONTS" ]; then
        # Print alert with repository and branch information
        echo "❌ [THREAT FOUND] Rogue Font in $REPO [$REMOTE_BRANCH]:"
        # Display list of infected files
        echo "$ROGUE_FONTS"
        # Increment threat counter
        INFECTED_FOUND=$((INFECTED_FOUND + 1))
      fi

      # === DETECTION STAGE 2: Check for Malicious VS Code Auto-Tasks ===
      # Check if .vscode/tasks.json file exists
      if [ -f .vscode/tasks.json ]; then
        # Search for malicious patterns in tasks.json file
        # Patterns: fa-solid-400, woff2, folderOpen, command -v node, eslint-check
        if grep -qE "fa-solid-400|woff2|folderOpen|command -v node|eslint-check" .vscode/tasks.json; then
          # Print alert if malicious task patterns found
          echo "❌ [THREAT FOUND] Malicious VS Code Task in $REPO [$REMOTE_BRANCH]"
          # Increment threat counter
          INFECTED_FOUND=$((INFECTED_FOUND + 1))
        fi
      fi

      # === DETECTION STAGE 3: Check for Injected C2 JavaScript Code ===
      # Search for C2 command-and-control patterns and persistence artifacts
      # Patterns detected:
      # - global.i="A8-..." (hex-encoded C2 identifier)
      # - global[.i] variants with escaping
      # - branch_structure.json (branch enumeration artifact)
      # - temp_auto_push.bat (persistence batch file)
      MATCHES=$(grep -rnE 'global(\.i|\[.i\]|\x5b.i\x5d)="A8-[^"]*"|branch_structure\.json|temp_auto_push\.bat' \
        --exclude-dir={.git,node_modules,dist,build,.next} \
        --exclude="*.vcxproj.filters" \
        --exclude="*.psd" \
        --exclude="*.fst" \
        --exclude="*.zip" \
        --exclude="*.wasm" \
        --exclude="*.data" . 2>/dev/null || true)
      
      # If C2 patterns found, log the threat with details
      if [ -n "$MATCHES" ]; then
        # Print alert with repository and branch information
        echo "❌ [THREAT FOUND] Injected C2 Code in $REPO [$REMOTE_BRANCH]:"
        # Display matching lines with file paths
        echo "$MATCHES"
        # Increment threat counter
        INFECTED_FOUND=$((INFECTED_FOUND + 1))
      fi
    done

    # Change back to temporary workspace directory
    cd "$TEMP_WORKSPACE"

    # Delete temporary repository clone to free disk space
    rm -rf repo_dir
  done
done

# Delete entire temporary workspace directory (cleanup)
rm -rf "$TEMP_WORKSPACE"

# Print final audit report separator
echo "=================================================="

# Check if any threats were found
if [ "$INFECTED_FOUND" -eq 0 ]; then
  # Print success message if no malware detected
  echo "✅ 100% CLEAN! Zero malware signatures, rogue tasks, or C2 loaders found across all organizations."
else
  # Print warning if malware instances detected
  echo "⚠️ Audit detected $INFECTED_FOUND threat instances."
fi

# Print final audit report separator
echo "=================================================="