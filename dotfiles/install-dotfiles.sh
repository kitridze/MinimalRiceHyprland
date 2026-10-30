#!/usr/bin/env bash
# Installs / upgrades the dotfiles in $HOME.
#   ./install-dotfiles.sh          SAFE mode (default): never overwrites your own rice.json, hyprland.conf or
#                                  hypridle.conf; if they exist, the new version is saved next to them as *.new
#   ./install-dotfiles.sh --force  overwrite everything (fresh install look); your old files are still backed up
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1
BK="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
PRESERVE=" .config/rice/rice.json .config/hypr/hyprland.conf .config/hypr/hypridle.conf "
mkdir -p "$BK"
for item in .config/hypr .config/rice .config/spicetify .local/bin; do
  if [ -e "$HOME/$item" ]; then mkdir -p "$BK/$(dirname "$item")"; cp -a "$HOME/$item" "$BK/$item"; fi
  while IFS= read -r -d '' f; do
    rel="${f#"$SRC"/}"; dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    if [ "$FORCE" = 0 ] && [ -e "$dest" ] && [[ "$PRESERVE" == *" $rel "* ]]; then
      if ! cmp -s "$f" "$dest"; then cp "$f" "$dest.new"; echo "kept yours : ~/$rel   (new default saved as ~/$rel.new)"; fi
    else
      cp -a "$f" "$dest"
    fi
  done < <(find "$SRC/$item" -type f -print0)
done
chmod +x "$HOME/.local/bin/rice" "$HOME/.local/bin/rice-settings"
mkdir -p "$HOME/.config/chromium" "$HOME/Pictures"
[ -f "$HOME/.config/chromium-flags.conf" ] || printf '%s\n' '--ozone-platform=wayland' > "$HOME/.config/chromium-flags.conf"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bash_profile"; export PATH="$HOME/.local/bin:$PATH";; esac
echo
echo "System files (run with sudo; safe to repeat):"
echo "  sudo install -Dm644 $SRC/etc/tlp.d/10-rice.conf /etc/tlp.d/10-rice.conf"
echo "  sudo install -Dm644 $SRC/etc/NetworkManager/conf.d/wifi-powersave.conf /etc/NetworkManager/conf.d/wifi-powersave.conf"
rice apply || true
echo
echo "Done. Backup of replaced files: $BK"
echo "Next: run 'rice setup' once, and check any *.new files (see the Upgrading section of the guide)."
