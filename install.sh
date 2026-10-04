#!/usr/bin/env bash
set -euo pipefail

APPLY=false
NO_RULES=false
for arg in "$@"; do
    if [ "$arg" = "--apply" ]; then
        APPLY=true
    elif [ "$arg" = "--no-rules" ]; then
        NO_RULES=true
    fi
done

DATE=$(date +%Y%m%d_%H%M%S)
HOME_DIR="${HOME:-~}"
GEMINI_DIR="$HOME_DIR/.gemini"
CONFIG_DIR="$GEMINI_DIR/config"
CONFIG_SKILLS="$CONFIG_DIR/skills"
GLOBAL_SKILLS="$GEMINI_DIR/antigravity/skills"
BACKUPS_DIR="$GEMINI_DIR/antigravity/skills-archive/backups"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== zero-g Installer ==="
if [ "$APPLY" = false ]; then
    echo "MODE: DRY-RUN (Pass --apply to make changes)"
else
    echo "MODE: APPLY (Executing changes with backups)"
fi
if [ "$NO_RULES" = true ]; then
    echo "OPTION: --no-rules active (Skipping GEMINI.md)"
fi
echo ""

if [ "$APPLY" = true ]; then
    mkdir -p "$CONFIG_SKILLS" "$GLOBAL_SKILLS"
fi

# Track results
declare -a TABLE_ROWS

backup_if_exists() {
    local target="$1"
    if [ -f "$target" ] || [ -d "$target" ]; then
        if [ "$APPLY" = true ]; then
            cp -r "$target" "${target}.bak-${DATE}"
        fi
        return 0
    fi
    return 1
}

# 1. Rules installation
RULES_SRC="$REPO_DIR/rules/GEMINI.md"
RULES_DST="$GEMINI_DIR/GEMINI.md"

if [ "$NO_RULES" = true ]; then
    TABLE_ROWS+=("rules/GEMINI.md | skipped | Skipped via --no-rules")
elif [ -f "$RULES_SRC" ]; then
    if [ -f "$RULES_DST" ]; then
        if [ "$APPLY" = true ]; then
            backup_if_exists "$RULES_DST"
            cp "$RULES_SRC" "$RULES_DST"
            TABLE_ROWS+=("rules/GEMINI.md | backed up & installed | Installed to $RULES_DST")
        else
            TABLE_ROWS+=("rules/GEMINI.md | would back up & install | Target: $RULES_DST")
        fi
    else
        if [ "$APPLY" = true ]; then
            mkdir -p "$(dirname "$RULES_DST")"
            cp "$RULES_SRC" "$RULES_DST"
            TABLE_ROWS+=("rules/GEMINI.md | installed | Installed to $RULES_DST")
        else
            TABLE_ROWS+=("rules/GEMINI.md | would install | Target: $RULES_DST")
        fi
    fi
fi

# 2. Custom skills installation
for s_path in "$REPO_DIR"/skills/*; do
    if [ -d "$s_path" ]; then
        s_name="$(basename "$s_path")"
        g_dst="$GLOBAL_SKILLS/$s_name"
        c_link="$CONFIG_SKILLS/$s_name"
        
        if [ -d "$g_dst" ] && [ ! -f "$g_dst/.zero-g-managed" ]; then
            if [ "$APPLY" = true ]; then
                mkdir -p "$BACKUPS_DIR"
                mv "$g_dst" "$BACKUPS_DIR/${s_name}.bak-${DATE}"
                mkdir -p "$g_dst"
                cp -r "$s_path/"* "$g_dst/"
                touch "$g_dst/.zero-g-managed"
                if [ -L "$c_link" ]; then rm "$c_link"; fi
                if [ ! -e "$c_link" ]; then ln -s "$g_dst" "$c_link"; fi
                TABLE_ROWS+=("skills/$s_name | backed up unmanaged & installed | Moved unmanaged to $BACKUPS_DIR/${s_name}.bak-${DATE}")
            else
                TABLE_ROWS+=("skills/$s_name | would back up unmanaged & install | Target: $g_dst (unmanaged will move to backups)")
            fi
        else
            if [ "$APPLY" = true ]; then
                mkdir -p "$g_dst"
                cp -r "$s_path/"* "$g_dst/"
                touch "$g_dst/.zero-g-managed"
                if [ -L "$c_link" ]; then rm "$c_link"; fi
                if [ ! -e "$c_link" ]; then ln -s "$g_dst" "$c_link"; fi
                TABLE_ROWS+=("skills/$s_name | installed | Linked to $c_link")
            else
                TABLE_ROWS+=("skills/$s_name | would install | Target: $g_dst and link in $CONFIG_SKILLS")
            fi
        fi
    fi
done

# 3. Third-party skills from skills.lock.json
LOCK_FILE="$REPO_DIR/skills.lock.json"
if [ -f "$LOCK_FILE" ] && command -v python3 >/dev/null 2>&1; then
    TEMP_CLONES_DIR="$GEMINI_DIR/antigravity/scratch/zero_g_clones"
    if [ "$APPLY" = true ]; then
        mkdir -p "$TEMP_CLONES_DIR"
    fi
    
    LOCK_PLAN_TMP="$(mktemp -t zero_g_lock_plan.XXXXXX)"
    python3 - "$LOCK_FILE" << 'PYEOF' > "$LOCK_PLAN_TMP"
import json, sys
lock_file = sys.argv[1]
with open(lock_file) as f:
    data = json.load(f)
for name, meta in data.get("skills", {}).items():
    print(f"{name}\t{meta['repo']}\t{meta['commit']}\t{meta['path']}")
PYEOF

    FAILED_REPOS=" "

    while IFS=$'\t' read -r s_name s_repo s_commit s_path; do
        target_skill="$CONFIG_SKILLS/$s_name"
        agents_skill="$HOME_DIR/.agents/skills/$s_name"
        
        if [ -e "$target_skill" ] || [ -e "$agents_skill" ]; then
            TABLE_ROWS+=("lock:$s_name | skipped | Already present in discovery path")
        else
            if [ "$APPLY" = true ]; then
                case "$FAILED_REPOS" in
                    *" $s_repo "*)
                        TABLE_ROWS+=("lock:$s_name | failed | Repository checkout failed previously")
                        continue
                        ;;
                esac

                repo_slug="$(echo "$s_repo" | sed 's|https://github.com/||; s|\.git||; s|/|_|g')"
                clone_path="$TEMP_CLONES_DIR/$repo_slug"

                if [ ! -d "$clone_path" ]; then
                    if ! git clone --quiet "$s_repo" "$clone_path"; then
                        FAILED_REPOS="${FAILED_REPOS}${s_repo} "
                        TABLE_ROWS+=("lock:$s_name | failed | Clone failed for $s_repo")
                        continue
                    fi
                fi

                if ! (cd "$clone_path" && git checkout --quiet "$s_commit"); then
                    FAILED_REPOS="${FAILED_REPOS}${s_repo} "
                    TABLE_ROWS+=("lock:$s_name | failed | Checkout failed for $s_commit")
                    continue
                fi

                current_sha="$(git -C "$clone_path" rev-parse HEAD)"
                if [ "$current_sha" != "$s_commit" ]; then
                    FAILED_REPOS="${FAILED_REPOS}${s_repo} "
                    TABLE_ROWS+=("lock:$s_name | failed | HEAD SHA mismatch: expected $s_commit, got $current_sha")
                    continue
                fi

                src_folder="$clone_path/$s_path"
                if [ -d "$src_folder" ]; then
                    dst_folder="$GLOBAL_SKILLS/$s_name"
                    if [ -d "$dst_folder" ] && [ ! -f "$dst_folder/.zero-g-managed" ]; then
                        mkdir -p "$BACKUPS_DIR"
                        mv "$dst_folder" "$BACKUPS_DIR/${s_name}.bak-${DATE}"
                    fi
                    mkdir -p "$dst_folder"
                    cp -r "$src_folder/"* "$dst_folder/"
                    touch "$dst_folder/.zero-g-managed"
                    ln -s "$dst_folder" "$target_skill"
                    TABLE_ROWS+=("lock:$s_name | installed | Pinned at ${s_commit:0:7}")
                else
                    TABLE_ROWS+=("lock:$s_name | failed | Subfolder $s_path not in clone")
                fi
            else
                TABLE_ROWS+=("lock:$s_name | would install | Missing; will clone and pin to ${s_commit:0:7}")
            fi
        fi
    done < "$LOCK_PLAN_TMP"
    rm -f "$LOCK_PLAN_TMP"
fi

echo "Item | Status | Notes"
echo "---|---|---"
for row in "${TABLE_ROWS[@]}"; do
    echo "$row"
done
echo ""

if [ "$APPLY" = false ]; then
    echo "Dry-run complete. Run with './install.sh --apply' to execute these changes."
else
    echo "Installation complete. Backups preserved with suffix .bak-$DATE."
fi
