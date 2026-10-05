# mac-setup

macOS workstation bootstrap: Ghostty + zsh (starship, fzf, fzf-tab, zoxide,
autosuggestions, syntax highlighting), eza, bat, rg, fd, yazi, lazygit,
Neovim (LazyVim), uv-managed Python, and Zed for the student.

## Run

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/barung/mac-setup/main/bootstrap.sh)"

Re-runnable. Existing configs go to `~/.config-backup/<timestamp>/`.
Configs are symlinked from `~/.mac-setup`, so `git -C ~/.mac-setup pull` updates them.
Machine-specific tweaks: `~/.zshrc.local`. Secrets: `~/.config/zsh/secrets.zsh` (chmod 600).
