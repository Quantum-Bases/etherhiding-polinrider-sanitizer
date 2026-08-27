#!/bin/bash
# This script sanitizes GitHub repositories by removing malicious payloads, C2 loaders, and infected files.

set -e
# Exit immediately if any command exits with a non-zero status

# Target GitHub orgs/users - Configure the list of organizations/users to scan
TARGETS=("Your-Org-1" "Your-Org-2" "Your-Username")

# Create temporary workspace directory for cloning repositories
TEMP_WORKSPACE=$(mktemp -d)

# Disable git hooks globally to prevent hooks from running during repository operations
git config --global core.hooksPath /dev/null

# Change to temporary workspace directory
cd "$TEMP_WORKSPACE"

# Define cross-platform sed helper function for in-place file editing
# macOS requires empty string parameter after -i flag, while Linux doesn't
sedi() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: use 'sed -i ""' syntax
    sed -i '' "$@"
  else
    # Linux: use 'sed -i' syntax
    sed -i "$@"
  fi
}

# Begin iterating through each target organization/user
for TARGET in "${TARGETS[@]}"; do
  # Print visual separator for each target
  echo "=================================================="
  # Display the current target being processed
  echo "🚀 Processing Target: $TARGET"
  # Print visual separator
  echo "=================================================="

  # Use GitHub CLI to list all repositories for the target with limit of 300
  # Extract just the nameWithOwner field (format: "owner/repo")
  REPOS=$(gh repo list "$TARGET" --limit 300 --json nameWithOwner -q '.[].nameWithOwner')

  # Begin iterating through each repository in the target
  for REPO in $REPOS; do
    # Print visual separator for each repository
    echo "----------------------------------------"
    # Display the current repository being audited
    echo "🔍 Auditing: $REPO"

    # Attempt to clone the repository; if it fails, skip to next repo
    # Suppress error output with 2>/dev/null
    if ! git clone "https://github.com/$REPO.git" repo_dir 2>/dev/null; then
      # Print warning and skip if repository is empty or inaccessible
      echo "⚠️ Skipping $REPO (empty or inaccessible)"
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

      # 1. Purge Rogue Fonts & Asset Directories
      find . -type f \( -name "fa-*.*" -o -name "*banner*.*" -o -name "*solid*.*" \) 2>/dev/null | grep -E '\.(woff|woff2|eot|svg|ttf|otf)$' | xargs rm -f 2>/dev/null || true
      find . -path "*/fonts/*" -type f \( -name "README*" -o -name "LICENSE*" -o -name "OFL*" -o -name "*.txt" -o -name "*.json" \) -delete 2>/dev/null || true

      # 2. Eradicate VS Code Auto-Tasks & Settings
      if [ -f .vscode/tasks.json ]; then
        if grep -qE "fa-solid-400|woff2|folderOpen|command -v node|eslint-check" .vscode/tasks.json; then
          echo "🧹 Purging .vscode/tasks.json from $REPO [$REMOTE_BRANCH]"
          rm -f .vscode/tasks.json
        fi
      fi

      if [ -f .vscode/settings.json ]; then
        sedi '/"task.allowAutomaticTasks"/d' .vscode/settings.json 2>/dev/null || true
      fi

      # 3. Strip Obfuscated C2 Payloads & Loaders (EH-*, #new, eval spawns)
      find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.mjs" -o -name "*.cjs" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" \) \
        ! -path "*/.git/*" \
        -exec sedi -E 's/[[:space:]]*global(\.i|\[.i\]|\x5b.i\x5d)="A8-[^"]*".*//g' {} + 2>/dev/null || true

      find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.mjs" -o -name "*.cjs" -o -name "*.jsx" -o -name "*.tsx" \) \
        ! -path "*/.git/*" \
        -exec sedi -E 's/[[:space:]]*const _0x[a-f0-9]+=_0x[a-f0-9]+;.*//g' {} + 2>/dev/null || true

      find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.mjs" -o -name "*.cjs" \) \
        ! -path "*/.git/*" \
        -exec sedi -E '/import \{ createRequire \} from .module.;/d' {} + 2>/dev/null || true

      find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.mjs" -o -name "*.cjs" \) \
        ! -path "*/.git/*" \
        -exec sedi -E '/const require = createRequire\(import\.meta\.url\);/d' {} + 2>/dev/null || true

      # 4. Remove Dropper Persistence Files
      rm -f temp_auto_push.bat temp_interactive_push.bat branch_structure.json .pnp.loader.mjs 2>/dev/null || true

      # 5. Clean .gitignore modifications
      if [ -f .gitignore ]; then
        sedi -E '/branch_structure\.json/d' .gitignore 2>/dev/null || true
        sedi -E '/temp_auto_push\.bat/d' .gitignore 2>/dev/null || true
        sedi -E '/temp_interactive_push\.bat/d' .gitignore 2>/dev/null || true
      fi

      # 6. Commit and Push Clean Branch
      if [ -n "$(git status --porcelain)" ]; then
        echo "🚨 Purged infected files on [$REMOTE_BRANCH]. Pushing..."
        git config user.name "Security Sanitizer"
        git config user.email "security@cleanup.local"
        git add -A
        git commit -m "security: eradicate EtherHiding / PolinRider rogue font payloads and C2 loaders"
        git push origin "$REMOTE_BRANCH" 2>/dev/null || echo "⚠️ Push failed/skipped for $REMOTE_BRANCH"
        echo "✅ Branch [$REMOTE_BRANCH] cleaned."
      fi
    done

    cd "$TEMP_WORKSPACE"
    rm -rf repo_dir
  done
done

rm -rf "$TEMP_WORKSPACE"
echo "=================================================="
echo "🎯 Organization Cleaned Across All Repositories!"
echo "=================================================="