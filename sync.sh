#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-pull}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-~}"
GEMINI_DIR="$HOME_DIR/.gemini"

if [ "$CMD" = "pull" ]; then
    echo "=== zero-g Sync: Pull ==="
    cd "$REPO_DIR"
    git pull --ff-only
    echo ""
    echo "Running installer preview (dry-run):"
    "$REPO_DIR/install.sh"
    echo ""
    read -r -p "Apply incoming zero-g changes now? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        "$REPO_DIR/install.sh" --apply
    else
        echo "Aborted. No local files were modified."
    fi

elif [ "$CMD" = "push" ]; then
    echo "=== zero-g Sync: Push ==="
    
    cd "$REPO_DIR"

    # 0. Commit identity guard
    USER_EMAIL="$(git -C "$REPO_DIR" config user.email 2>/dev/null || echo "")"
    case "$USER_EMAIL" in
        *@users.noreply.github.com)
            ;;
        *)
            echo "IDENTITY ALERT: git config user.email ('$USER_EMAIL') is not a GitHub noreply address."
            echo "Set the repo-local noreply email before pushing:"
            echo '  git config user.email "<id>+<login>@users.noreply.github.com"'
            echo "  (Find your id via: gh api user --jq .id)"
            exit 1
            ;;
    esac

    # Sync live files back into repo
    LIVE_GEMINI="$GEMINI_DIR/GEMINI.md"
    if [ -f "$LIVE_GEMINI" ]; then
        cp "$LIVE_GEMINI" "$REPO_DIR/rules/GEMINI.md"
    fi
    
    for s_path in "$REPO_DIR"/skills/*; do
        if [ -d "$s_path" ]; then
            s_name="$(basename "$s_path")"
            live_skill="$GEMINI_DIR/antigravity/skills/$s_name"
            if [ -d "$live_skill" ]; then
                cp -r "$live_skill/"* "$s_path/"
            fi
        fi
    done
    
    # List untracked files before staging
    UNTRACKED=$(git ls-files --others --exclude-standard)
    if [ -n "$UNTRACKED" ]; then
        echo "Untracked files detected:"
        echo "$UNTRACKED"
        echo ""
    fi
    
    # Stage everything to scan full incoming content
    git add -A
    
    echo "Running Public-Readiness Check on staged diff..."
    
    # Pathspec exclusion: scan general files vs sync scripts separately
    DIFF_GENERAL=$(git diff --cached -- . ':(exclude)sync.sh' ':(exclude)sync.ps1')
    DIFF_SCRIPTS=$(git diff --cached -- sync.sh sync.ps1)
    
    # 1. Secrets check
    GEN_SECRETS_REGEX='(ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z]{10,}|BEGIN [A-Z ]*PRIVATE KEY|(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,})'
    SECRETS_MATCHES_GEN=""
    if [ -n "$DIFF_GENERAL" ]; then
        SECRETS_MATCHES_GEN=$(echo "$DIFF_GENERAL" | grep -iE "$GEN_SECRETS_REGEX" || true)
    fi

    SCRIPT_SECRETS_REGEX='(ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[0-9A-Za-z]{10,})'
    SECRETS_MATCHES_SCRIPTS=""
    if [ -n "$DIFF_SCRIPTS" ]; then
        SECRETS_MATCHES_SCRIPTS=$(echo "$DIFF_SCRIPTS" | grep -iE "$SCRIPT_SECRETS_REGEX" || true)
    fi

    if [ -n "$SECRETS_MATCHES_GEN" ] || [ -n "$SECRETS_MATCHES_SCRIPTS" ]; then
        echo "SECURITY ALERT: Potential secrets detected in staged diff:"
        if [ -n "$SECRETS_MATCHES_GEN" ]; then echo "$SECRETS_MATCHES_GEN"; fi
        if [ -n "$SECRETS_MATCHES_SCRIPTS" ]; then echo "$SECRETS_MATCHES_SCRIPTS"; fi
        echo "Resetting staged changes and aborting push."
        git reset
        exit 1
    fi
    
    # 2. Personal data check (whole-word usernames, /home/<user>, non-noreply emails)
    LOCAL_USER="$(whoami 2>/dev/null || echo "")"
    GH_USER="$(gh api user --jq .login 2>/dev/null || echo "")"
    
    USER_PATTERNS=()
    if [ -n "$LOCAL_USER" ]; then USER_PATTERNS+=("$LOCAL_USER"); fi
    if [ -n "$GH_USER" ]; then USER_PATTERNS+=("$GH_USER"); fi
    
    USER_REGEX=""
    if [ ${#USER_PATTERNS[@]} -gt 0 ]; then
        USER_REGEX="$(IFS='|'; echo "${USER_PATTERNS[*]}")"
    fi

    HOME_MATCHES_GEN=""
    USER_MATCHES_GEN=""
    EMAIL_MATCHES_GEN=""
    if [ -n "$DIFF_GENERAL" ]; then
        HOME_MATCHES_GEN=$(echo "$DIFF_GENERAL" | grep -iE "/home/[a-zA-Z0-9_-]+" || true)
        if [ -n "$USER_REGEX" ]; then
            USER_MATCHES_GEN=$(echo "$DIFF_GENERAL" | grep -vE "https://github\.com/[^/]+/zero-g" | grep -iwE "$USER_REGEX" || true)
        fi
        EMAIL_MATCHES_GEN=$(echo "$DIFF_GENERAL" | grep -E "[a-zA-Z0-9_.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+" | grep -vE "[0-9]+\+[a-zA-Z0-9_-]+@users\.noreply\.github\.com" || true)
    fi

    HOME_MATCHES_SCRIPTS=""
    USER_MATCHES_SCRIPTS=""
    EMAIL_MATCHES_SCRIPTS=""
    if [ -n "$DIFF_SCRIPTS" ]; then
        HOME_MATCHES_SCRIPTS=$(echo "$DIFF_SCRIPTS" | grep -iE "/home/[a-zA-Z0-9_]" || true)
        if [ -n "$USER_REGEX" ]; then
            USER_MATCHES_SCRIPTS=$(echo "$DIFF_SCRIPTS" | grep -vE '(\+.*echo.*user\.email|\+.*Write-Host.*user\.email)' | grep -iwE "$USER_REGEX" || true)
        fi
        EMAIL_MATCHES_SCRIPTS=$(echo "$DIFF_SCRIPTS" | grep -E "[a-zA-Z0-9_.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+" | grep -vE '(@users\.noreply\.github\.com|[0-9]+\+[a-zA-Z0-9_-]+@users\.noreply\.github\.com)' || true)
    fi

    if [ -n "$HOME_MATCHES_GEN" ] || [ -n "$USER_MATCHES_GEN" ] || [ -n "$EMAIL_MATCHES_GEN" ] || [ -n "$HOME_MATCHES_SCRIPTS" ] || [ -n "$USER_MATCHES_SCRIPTS" ] || [ -n "$EMAIL_MATCHES_SCRIPTS" ]; then
        echo "PRIVACY ALERT: Potential personal data detected in staged diff:"
        if [ -n "$HOME_MATCHES_GEN" ]; then echo "$HOME_MATCHES_GEN"; fi
        if [ -n "$USER_MATCHES_GEN" ]; then echo "$USER_MATCHES_GEN"; fi
        if [ -n "$EMAIL_MATCHES_GEN" ]; then echo "$EMAIL_MATCHES_GEN"; fi
        if [ -n "$HOME_MATCHES_SCRIPTS" ]; then echo "$HOME_MATCHES_SCRIPTS"; fi
        if [ -n "$USER_MATCHES_SCRIPTS" ]; then echo "$USER_MATCHES_SCRIPTS"; fi
        if [ -n "$EMAIL_MATCHES_SCRIPTS" ]; then echo "$EMAIL_MATCHES_SCRIPTS"; fi
        echo "Resetting staged changes and aborting push."
        git reset
        exit 1
    fi
    
    echo "Public-readiness check PASSED."
    echo ""
    echo "Staged changes summary:"
    git diff --cached --stat
    echo ""
    read -r -p "Commit and push these changes to remote? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        read -r -p "Commit message: " msg
        git commit -m "$msg"
        git push
        echo "Pushed successfully."
    else
        echo "Push cancelled. Resetting staged changes."
        git reset
    fi

else
    echo "Usage: ./sync.sh [pull|push]"
    exit 1
fi
