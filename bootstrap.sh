#!/usr/bin/env bash
# mac-setup bootstrap — Tej Infomedia
#
# Usage (keeps the terminal attached so Homebrew can ask for the password):
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/barungh/mac-setup/main/bootstrap.sh)"
#
# Safe to re-run: existing configs are moved to ~/.config-backup/<timestamp>/
# before being replaced with symlinks into ~/.mac-setup.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/barungh/mac-setup.git}"   # <-- change this
DEST="${DEST:-$HOME/.mac-setup}"
BACKUP="$HOME/.config-backup/$(date +%Y%m%d-%H%M%S)"
COURSE_DIR="${COURSE_DIR:-$HOME/PythonCourse}"

bold=$'\e[1m'; green=$'\e[32m'; yellow=$'\e[33m'; red=$'\e[31m'; reset=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$bold$green" "$*" "$reset"; }
warn() { printf '%s!!  %s%s\n' "$yellow" "$*" "$reset"; }
die()  { printf '%sxx  %s%s\n' "$red" "$*" "$reset" >&2; exit 1; }

# ---------------------------------------------------------------- preflight
[[ $(uname -s) == Darwin ]] || die "This script is for macOS only."
[[ $EUID -ne 0 ]] || die "Run as the normal user, not with sudo."

macos_ver=$(sw_vers -productVersion)
(( ${macos_ver%%.*} >= 13 )) || warn "macOS $macos_ver detected: Ghostty needs 13+; some casks may fail."
printf 'macOS %s on %s\n' "$macos_ver" "$(uname -m)"

# ---------------------------------------------------------------- Homebrew
step "Homebrew (also installs Xcode Command Line Tools)"
if [[ ! -x /opt/homebrew/bin/brew && ! -x /usr/local/bin/brew ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
else eval "$(/usr/local/bin/brew shellenv)"; fi
brew update

# ---------------------------------------------------------------- repo
step "Fetching config repo -> $DEST"
if [[ -d $DEST/.git ]]; then git -C "$DEST" pull --ff-only
else git clone --depth 1 "$REPO_URL" "$DEST"; fi

# ---------------------------------------------------------------- packages
step "Installing packages from Brewfile"
brew bundle --file="$DEST/Brewfile" \
  || warn "Some packages failed. Re-run later: brew bundle --file=$DEST/Brewfile"

# Homebrew's share dirs are group-writable, which makes compinit complain.
chmod -R go-w "$(brew --prefix)/share/zsh" 2>/dev/null || true

# ---------------------------------------------------------------- zsh plugin not in Homebrew
step "fzf-tab"
if [[ ! -d $HOME/.zsh/plugins/fzf-tab ]]; then
  git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$HOME/.zsh/plugins/fzf-tab"
else
  git -C "$HOME/.zsh/plugins/fzf-tab" pull --ff-only || true
fi

# ---------------------------------------------------------------- dotfiles
link() {  # link <source-in-repo> <target>
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then return; fi
  if [[ -e $dst || -L $dst ]]; then
    local rel=${dst#"$HOME"/}
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$dst" "$BACKUP/$rel"
    warn "backed up ~/$rel"
  fi
  ln -s "$src" "$dst"
  printf '    linked ~/%s\n' "${dst#"$HOME"/}"
}

step "Linking configs"
link "$DEST/zsh/zshrc"               "$HOME/.zshrc"
link "$DEST/starship/starship.toml"  "$HOME/.config/starship.toml"
link "$DEST/ghostty/config"          "$HOME/.config/ghostty/config"
link "$DEST/zed/settings.json"       "$HOME/.config/zed/settings.json"
link "$DEST/zed/keymap.json"         "$HOME/.config/zed/keymap.json"
link "$DEST/zed/tasks.json"          "$HOME/.config/zed/tasks.json"

# ---------------------------------------------------------------- Neovim (LazyVim)
step "Neovim + LazyVim"
if [[ -e $HOME/.config/nvim ]]; then
  warn "$HOME/.config/nvim already exists; leaving it alone."
else
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "Plugin sync incomplete; open nvim once to finish."
fi

# ---------------------------------------------------------------- Python (uv)
step "Python via uv"
# --default also installs `python`/`python3` shims in ~/.local/bin (first on PATH)
uv python install --default --preview 2>/dev/null || uv python install
export PATH="$HOME/.local/bin:$PATH"

if [[ ! -d $COURSE_DIR ]]; then
  uv init --app --vcs none --name python-course "$COURSE_DIR"
  rm -f "$COURSE_DIR/main.py"
  cat > "$COURSE_DIR/01_hello.py" <<'PY'
# Your first program. Press Cmd+R in Zed to run it.
name = input("What's your name? ")
print(f"Hello, {name}! Welcome to Python.")
PY
  (cd "$COURSE_DIR" && uv sync)
  printf '    created %s\n' "$COURSE_DIR"
else
  warn "$COURSE_DIR exists; skipping."
fi

# ---------------------------------------------------------------- done
step "Done"
cat <<EOF
  Next:
    1. Open ${bold}Ghostty${reset} (Applications) — it picks up the new config and zsh.
    2. Student: ${bold}zed $COURSE_DIR${reset}, open 01_hello.py, press Cmd+R.
    3. In nvim, run :LazyExtras and enable lang.python; then :checkhealth.
    4. git is not configured — set name/email per person:
         git config --global user.name "..." ; git config --global user.email "..."
  Backups (if any): $BACKUP
EOF
