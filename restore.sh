#!/usr/bin/env bash
# restore.sh — Rebuild system from a fresh Omarchy install
#
# Usage:
#   ./restore.sh           interactive step selection
#   ./restore.sh --auto    run all steps, skip confirms
#
# Bootstrap (fresh install):
#   git clone https://github.com/matrix9180/dotfiles ~/dotfiles && ~/dotfiles/restore.sh

set -euo pipefail

REPO="https://github.com/matrix9180/dotfiles"
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config"

AUTO=false
[[ "${1:-}" == "--auto" ]] && AUTO=true

# ── helpers ──────────────────────────────────────────────────────────────────

need() { command -v "$1" &>/dev/null || { gum log --level error "$1 not found"; exit 1; }; }

header() {
  echo
  gum style --border double --padding "0 3" --bold --foreground 10 "$1"
  echo
}

step() { gum style --bold --foreground 12 "  ▸ $*"; }
ok()   { gum log --level info "$*"; }
warn() { gum log --level warn "$*"; }
err()  { gum log --level error "$*"; }

confirm() {
  [[ $AUTO == true ]] && return 0
  gum confirm "$1" || return 1
}

spin() {
  local title="$1"; shift
  gum spin --spinner dot --title "$title" -- "$@"
}

# ── preflight ─────────────────────────────────────────────────────────────────

if ! command -v gum &>/dev/null; then
  echo "Installing gum..."
  sudo pacman -S --noconfirm gum 2>/dev/null \
    || { echo "Install gum manually: sudo pacman -S gum"; exit 1; }
fi

header "MATRIX9180 SYSTEM RESTORE"
gum style --foreground 8 "  Omarchy $(omarchy version 2>/dev/null || echo '?') · $(uname -r)"
echo

# ── step selection ────────────────────────────────────────────────────────────

if [[ $AUTO == true ]]; then
  STEPS="dotfiles packages devtools gitconfig auth services omarchy localbins"
else
  mapfile -t CHOSEN < <(gum choose --no-limit \
    --header "Select steps to run (space to toggle, enter to confirm):" \
    "dotfiles   — apply configs from repo to ~/.config" \
    "packages   — install extra pacman + AUR packages" \
    "devtools   — mise runtimes (ruby/node/go), rustup, uv" \
    "gitconfig  — restore global git config" \
    "auth       — gh auth + SSH key instructions" \
    "services   — enable systemd user + system services" \
    "omarchy    — set theme (Retro 82) + font (JetBrainsMono Nerd Font)" \
    "localbins  — restore custom scripts to ~/.local/bin")
  STEPS="${CHOSEN[*]:-}"
fi

should_run() { [[ "$STEPS" == *"$1"* ]]; }

# ── steps ─────────────────────────────────────────────────────────────────────

restore_dotfiles() {
  step "Dotfiles"

  if [[ ! -d "$DOTFILES/.git" ]]; then
    spin "Cloning dotfiles..." git clone "$REPO" "$DOTFILES"
  else
    spin "Pulling latest dotfiles..." git -C "$DOTFILES" pull --ff-only
  fi

  local dirs=(hypr waybar alacritty kitty ghostty mako swayosd omarchy walker uwsm)
  for dir in "${dirs[@]}"; do
    if [[ -d "$DOTFILES/$dir" ]]; then
      mkdir -p "$CONFIG/$dir"
      rsync -a --no-links "$DOTFILES/$dir/" "$CONFIG/$dir/"
    fi
  done

  [[ -f "$DOTFILES/starship.toml" ]] && cp "$DOTFILES/starship.toml" "$CONFIG/starship.toml"

  ok "Configs applied to ~/.config"
}

install_packages() {
  step "Packages"
  need yay

  declare -A GROUPS=(
    ["core"]="neovim zed tree usbutils gdb zenity sshpass"
    ["amd-gpu"]="vulkan-radeon rocm-smi-lib qsv"
    ["virtualization"]="qemu-full libvirt virt-manager virt-viewer edk2-ovmf dnsmasq podman virtualbox"
    ["snapshots"]="snapper limine-snapper-sync"
    ["dev-extras"]="zig openblas vulkan-headers hyprshade blueprint-compiler"
    ["media"]="handbrake handbrake-cli gst-plugin-pipewire"
    ["apps"]="discord steam inkscape transmission-gtk firefox cliphist"
    ["php"]="php php-sqlite xdebug composer"
    ["nix"]="nix perl-nix"
    ["misc"]="pandoc-cli mariadb-clients wireguard-tools tk"
    ["aur"]="amf-amdgpu-pro ghostty-runed-debug ghostty-runed-terminfo nix-debug snapper-gui-git"
  )

  local group_list
  mapfile -t group_list < <(printf '%s\n' "${!GROUPS[@]}" | sort)

  if [[ $AUTO == true ]]; then
    selected=("${group_list[@]}")
  else
    mapfile -t selected < <(gum choose --no-limit \
      --header "Select package groups:" \
      "${group_list[@]}")
  fi

  for group in "${selected[@]}"; do
    local pkgs="${GROUPS[$group]}"
    if [[ "$group" == "aur" ]]; then
      spin "AUR: $pkgs" yay -S --noconfirm --needed $pkgs \
        && ok "Installed AUR group: $group" \
        || warn "Some AUR packages failed: $group"
    else
      spin "pacman: $pkgs" sudo pacman -S --noconfirm --needed $pkgs \
        && ok "Installed: $group" \
        || warn "Some packages failed: $group"
    fi
  done
}

setup_devtools() {
  step "Dev tools"

  # mise runtimes
  if command -v mise &>/dev/null; then
    spin "mise: ruby (latest)..." mise use -g ruby@latest
    spin "mise: node (latest)..." mise use -g node@latest
    spin "mise: go (latest)..."   mise use -g go@latest
    ok "mise runtimes installed"
  else
    warn "mise not found — install via omarchy or https://mise.jdx.dev"
  fi

  # rustup
  if ! command -v rustup &>/dev/null; then
    spin "Installing rustup..." \
      bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --no-modify-path"
    ok "rustup installed (stable)"
  else
    spin "Updating rust stable..." rustup update stable
    ok "rust stable up to date"
  fi

  # uv (Python)
  if [[ ! -f "$HOME/.local/bin/uv" ]]; then
    spin "Installing uv..." bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
    ok "uv installed"
  else
    ok "uv already present"
  fi
}

setup_git() {
  step "Git config"

  git config --global user.name        "Matrix9180"
  git config --global user.email       "matrix9180@proton.me"
  git config --global alias.co         checkout
  git config --global alias.br         branch
  git config --global alias.ci         commit
  git config --global alias.st         status
  git config --global init.defaultBranch         master
  git config --global pull.rebase               true
  git config --global push.autoSetupRemote      true
  git config --global diff.algorithm            histogram
  git config --global diff.colorMoved           plain
  git config --global diff.mnemonicPrefix       true
  git config --global commit.verbose            true
  git config --global column.ui                 auto
  git config --global branch.sort               -committerdate
  git config --global tag.sort                  -version:refname
  git config --global rerere.enabled            true
  git config --global rerere.autoupdate         true
  git config --global credential.https://github.com.helper      ''
  git config --global --add credential.https://github.com.helper \
    '!/usr/bin/gh auth git-credential'
  git config --global credential.https://gist.github.com.helper ''
  git config --global --add credential.https://gist.github.com.helper \
    '!/usr/bin/gh auth git-credential'

  ok "Global git config applied"
}

setup_auth() {
  step "Auth"

  echo
  if gh auth status &>/dev/null; then
    ok "GitHub: already authenticated as $(gh api user --jq .login 2>/dev/null || echo '?')"
  else
    warn "Not logged in to GitHub. Running gh auth login..."
    gh auth login --web --git-protocol ssh
  fi

  echo
  gum style --border normal --padding "0 2" --foreground 3 \
"SSH KEY — manual step required

Restore ~/.ssh/id_ed25519 + id_ed25519.pub from your encrypted backup, then:

  chmod 600 ~/.ssh/id_ed25519
  ssh-add ~/.ssh/id_ed25519

Add the public key at: https://github.com/settings/ssh/new"
  echo
}

enable_services() {
  step "Services"

  local user_svcs=(elephant swayosd-server wireplumber xdg-user-dirs)
  local user_timers=(hyprsunset-refresh.timer omarchy-battery-monitor.timer)
  local sys_svcs=(avahi-daemon iwd libvirtd power-profiles-daemon sddm ufw)
  local sys_sockets=(docker.socket libvirtd.socket)
  local sys_timers=(snapper-cleanup.timer snapper-timeline.timer)

  for svc in "${user_svcs[@]}"; do
    systemctl --user enable --now "$svc" 2>/dev/null \
      && ok "User service enabled: $svc" \
      || warn "Not found, skipped: $svc"
  done

  for timer in "${user_timers[@]}"; do
    systemctl --user enable --now "$timer" 2>/dev/null \
      && ok "User timer enabled: $timer" \
      || warn "Not found, skipped: $timer"
  done

  for svc in "${sys_svcs[@]}"; do
    sudo systemctl enable --now "$svc" 2>/dev/null \
      && ok "System service enabled: $svc" \
      || warn "Not found, skipped: $svc"
  done

  for sock in "${sys_sockets[@]}"; do
    sudo systemctl enable --now "$sock" 2>/dev/null \
      && ok "Socket enabled: $sock" \
      || warn "Not found, skipped: $sock"
  done

  for timer in "${sys_timers[@]}"; do
    sudo systemctl enable --now "$timer" 2>/dev/null \
      && ok "System timer enabled: $timer" \
      || warn "Snapper timers not available — configure snapper first"
  done

  warn "openclaw-gateway: reinstall openclaw via npm, then: systemctl --user enable --now openclaw-gateway"
}

setup_omarchy() {
  step "Omarchy theme + font"

  spin "Setting theme: Retro 82..." bash -c "omarchy theme set 'Retro 82'"
  spin "Setting font: JetBrainsMono Nerd Font..." bash -c "omarchy font set 'JetBrainsMono Nerd Font'"
  ok "Theme and font applied"
}

install_local_bins() {
  step "Custom scripts"
  mkdir -p "$HOME/.local/bin"

  if [[ -d "$DOTFILES/local-bin" ]]; then
    for script in "$DOTFILES/local-bin/"*; do
      local name; name="$(basename "$script")"
      cp "$script" "$HOME/.local/bin/$name"
      chmod +x "$HOME/.local/bin/$name"
    done
    ok "Scripts installed to ~/.local/bin"
  else
    warn "local-bin not found in dotfiles repo"
  fi
}

# ── run ───────────────────────────────────────────────────────────────────────

should_run "dotfiles"  && restore_dotfiles
should_run "packages"  && install_packages
should_run "devtools"  && setup_devtools
should_run "gitconfig" && setup_git
should_run "auth"      && setup_auth
should_run "services"  && enable_services
should_run "omarchy"   && setup_omarchy
should_run "localbins" && install_local_bins

# ── summary ───────────────────────────────────────────────────────────────────

echo
header "DONE"
gum style --foreground 8 \
"Manual steps remaining:
  • Restore ~/.ssh/id_ed25519 from encrypted backup
  • Install openclaw: npm i -g openclaw; systemctl --user enable --now openclaw-gateway
  • Sign in to: 1Password, Spotify, Obsidian, Discord, Signal
  • Snapper config: sudo snapper -c root create-config /
  • Reboot: sudo reboot"
