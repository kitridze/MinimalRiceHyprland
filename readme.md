# Arch Linux + Hyprland: a minimal pastel laptop rice (battery-first)

This guide takes you from a blank laptop and a live USB to a finished, themeable Hyprland desktop. Everything is plain text: shell commands, config files and one small Python manager (`rice`) that generates the configs from a theme file.

**Conventions.** `$` is a normal-user prompt, `#` is root (or prefix with `sudo`). Paths starting with `~` are inside your home folder. The dotfiles are delivered as `dotfiles.zip` next to this guide, and **every file is also printed in full in the Appendix**, so you can copy-paste if you have no zip.

**What you get**

- Hyprland + Waybar + foot + fuzzel + mako + hyprlock/hypridle: all light, Wayland-native, no always-on heavy daemons.
- **57 themes**: 9 originals (5 pastel, 4 neutral) plus **48 color themes** (blue, red, green, yellow, pink, purple, orange, brown × 3 variations × day/night). One file per theme; the day/night toggle moves between matching day and night versions; optional automatic switching.
- 7 ASCII-art backgrounds (including your Megumin art) rendered to an image in the current theme's colors, with screen-filling, softening and edge-fade options, plus an image-to-ASCII converter.
- 5 animation presets, from `off` to `smooth`.
- English / Russian / Georgian keyboard layouts.
- A hideable bar with CPU, RAM, temperature, network and a loud battery indicator.
- Matching themes for VS Code, Spotify (spicetify), Chromium and Obsidian.
- An **eyecare mode**: adjustable warm screen tint, optionally on a schedule.
- A Tk settings app (`rice-settings`).

> **Honesty note.** I could not boot Arch or Hyprland while writing this: the `rice` script, templates and themes were run and checked against a fake home directory (all 9 themes render, all JSON output parses), but Hyprland, Waybar and the third-party apps were not run. Config syntax follows current Hyprland (0.4x-0.5x era) and Waybar. If a Hyprland update renames an option, `hyprctl` shows a red error bar at the top of the screen naming the line; fix that line in `~/.config/hypr/hyprland.conf` or in the template `~/.config/rice/templates/hypr-theme.conf`. Package names (especially AUR ones) should be confirmed with `pacman -Ss` / `yay -Ss`.

---

## 1. Installation

### 1.1 Make the install USB

1. Download the ISO from <https://archlinux.org/download/> and verify the checksum or signature shown there.
2. Write it to a USB stick (8 GB+): `sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync` (double-check `sdX` with `lsblk`; it erases the stick), or use Ventoy / balenaEtcher / Rufus.
3. In the laptop's firmware: boot in **UEFI** mode and turn **Secure Boot off** (the stock archinstall flow does not sign the bootloader). Boot from the USB and pick "Arch Linux install medium".

### 1.2 Get online first

`archinstall` downloads packages, so you need internet before starting. Do **Chapter 2, section 2.1** now (it takes two minutes), then come back. Confirm UEFI mode and connectivity:

```bash
# ls /sys/firmware/efi/efivars >/dev/null && echo UEFI
# ping -c3 archlinux.org
```

Update the installer itself (the menu changes between versions):

```bash
# pacman -Sy archinstall
```

### 1.3 Run `archinstall`

```bash
# archinstall
```

Move with the arrow keys, Enter to select, and finish with **Install** at the bottom. Menu names vary slightly by version; the intent of each choice is below.

| Menu entry | Choose | Why |
|---|---|---|
| Archinstall language | English | |
| Locales | keyboard `us`, language `en_US.UTF-8` | Russian and Georgian layouts are added later inside Hyprland, not here. |
| Mirrors and repositories | your country/region | Faster downloads; leave *multilib* off unless you need Steam/Wine. |
| Disk configuration | *Use a best-effort default partition layout* → your drive → **ext4** | Lowest overhead. btrfs is fine if you want snapshots. Disk encryption (LUKS) costs very little battery on modern CPUs; enable it if the laptop travels. |
| Swap | zram **on** (default) | Compressed RAM swap: no disk wakeups. Hibernation needs a real swap partition; skip it unless you want it. |
| Bootloader | **systemd-boot** (UEFI) | Smallest and simplest. |
| Kernel | `linux` | The stock kernel is best supported by TLP and firmware. |
| Hostname | anything | |
| Authentication | create a **user** with *sudo* | Root password optional. |
| Profile → Type | **Desktop → Hyprland** | The requested profile. |
| ↳ Seat access | **polkit** | Needed for the session without a login daemon quirks. |
| ↳ Graphics driver | match your GPU: *Intel (open-source)* or *AMD / ATI (open-source)* | See section 3. For NVIDIA-hybrid laptops, still pick the integrated GPU's open driver; see section 3. |
| ↳ Greeter | `ly` if offered (tiny, text-mode), otherwise `sddm` | Pick the entry **Hyprland (uwsm)** at login. |
| Audio | **pipewire** | |
| Network configuration | **Use NetworkManager** | Do **not** pick "copy ISO configuration": that leaves iwd + systemd-networkd and no auto-reconnecting profiles. |
| Additional packages | paste the list below | Saves a post-install step. |
| Timezone | yours | |
| Automatic time sync | **on** | |
| Save configuration (optional) | save to the USB or `/tmp` | Lets you re-run the same install. |

**Additional packages** (all in the official repos; type them space-separated in the box):

```text
git base-devel neovim waybar swaybg fuzzel mako foot hypridle hyprlock hyprpolkitagent brightnessctl playerctl grim slurp wl-clipboard libnotify python python-pillow tk fontconfig dconf gsettings-desktop-schemas xdg-desktop-portal-gtk gnome-themes-extra breeze plasma-integration kio-extras archlinux-xdg-menu ffmpegthumbs kdegraphics-thumbnailers gwenview mpv strawberry xdg-utils jq xorg-xwayland tlp powertop chromium obsidian code hyprsunset inter-font ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
```

Select **Install**, confirm, wait, answer *no* to chroot, and then:

```bash
# reboot
```

Remove the USB when the screen goes dark.

### 1.4 First boot

Log in through the greeter, choosing the **Hyprland (uwsm)** session. You get a bare Hyprland with archinstall's default packages (kitty, dunst, wofi, dolphin). In the stock config `Super+Q` opens kitty; if nothing responds, switch to a text console with `Ctrl+Alt+F2`, log in, and continue from the console.

Connect Wi-Fi once (NetworkManager remembers it and reconnects on every boot):

```bash
$ nmcli device wifi list
$ nmcli device wifi connect "YourSSID" --ask
```

### 1.5 Services and extra packages

```bash
$ sudo systemctl enable --now NetworkManager tlp
$ sudo systemctl mask systemd-rfkill.service systemd-rfkill.socket   # TLP asks for this
```

AUR helper, then the AUR-only pieces (pixel font, Spotify, spicetify):

```bash
$ git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si && cd ..
$ yay -S --needed ttf-monocraft spotify spicetify-cli
```

If `ttf-monocraft` is not found, download `Monocraft.ttc` (or `.otf`) from the Monocraft GitHub releases page into `~/.local/share/fonts/` and run `fc-cache -f`. For Spotify, give spicetify write access once: `sudo chmod a+wr /opt/spotify -R && sudo chmod a+wr /opt/spotify/Apps -R`.

Optional clean-up of defaults you will not use: `sudo pacman -Rns dunst wofi kitty` (keep `dolphin` if you want a GUI file manager, or swap it for `thunar`).

### 1.6 Install the dotfiles

Get `dotfiles.zip` onto the machine (second USB stick, or put the folder in a Git repo and clone it). Then:

```bash
$ unzip dotfiles.zip && cd dotfiles
$ ./install-dotfiles.sh
$ sudo install -Dm644 etc/tlp.d/10-rice.conf /etc/tlp.d/10-rice.conf
$ sudo install -Dm644 etc/NetworkManager/conf.d/wifi-powersave.conf /etc/NetworkManager/conf.d/wifi-powersave.conf
$ sudo tlp start && sudo systemctl restart NetworkManager
$ fc-cache -f
```

The installer backs up any existing `~/.config/hypr`, `~/.config/rice`, `~/.config/spicetify` and `~/.local/bin` to `~/.dotfiles-backup-<date>`, copies the files, runs `rice apply`, and prints the two `sudo` commands above. By default it is **safe**: it never overwrites your own `rice.json`, `hyprland.conf` or `hypridle.conf` (see 1.7); use `./install-dotfiles.sh --force` to overwrite everything. Log out and back in; you now have the full rice. Then run the one-time app setup from **Chapter 14** (`rice setup`): after it, Chromium, VS Code, Obsidian and Spotify follow every theme change automatically.

### 1.7 Upgrading from an earlier version of these dotfiles

Short answer: **not the same moves.** Do not delete anything and do not re-run a fresh install over your settings. The installer now has a safe default that updates the program, themes and templates but keeps your personal files.

1. **Install the packages added since your version** (harmless if already present):
   ```bash
   $ sudo pacman -S --needed hyprsunset xdg-desktop-portal-gtk gnome-themes-extra breeze plasma-integration kio-extras archlinux-xdg-menu ffmpegthumbs kdegraphics-thumbnailers gwenview mpv strawberry
   ```
2. **Unzip the new `dotfiles.zip` into a new folder** (not over the old one) and run the installer from there:
   ```bash
   $ unzip dotfiles.zip -d ~/dotfiles-new && cd ~/dotfiles-new/dotfiles
   $ ./install-dotfiles.sh
   ```
   What it does in the default (safe) mode:

   | Item | Behavior |
   |---|---|
   | `~/.local/bin/rice`, `rice-settings`, `~/.config/rice/templates`, `themes`, `animations`, `backgrounds` | **updated**: you get the new program, the 48 new themes, new templates and the Megumin art. |
   | Your own custom themes, backgrounds and animations (files with names the zip does not contain) | **untouched** |
   | `~/.config/rice/rice.json` (your settings) | **kept**. No merge needed: new settings such as eyecare get their defaults automatically inside `rice`. The new default is saved as `rice.json.new` for reference only; delete it. |
   | `~/.config/hypr/hyprland.conf`, `hypridle.conf` | **kept** (they hold your binds); new version saved as `hyprland.conf.new` |
   | Anything you edited inside `templates/*` or a stock theme/animation file | **overwritten** (the file is in the new zip), but your old copy is in `~/.dotfiles-backup-<date>`; re-apply your edit afterwards |
3. **Merge `hyprland.conf` by hand** (2 minutes). Compare with `diff -u ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.new`. Depending on how old your version is, the changes are:
   - **remove** these four lines if present (themes/animations are now controlled from the settings app): `bind = $mod, N, exec, rice toggle`, `bind = $mod, T, exec, rice theme next`, `bind = $mod SHIFT, T, exec, rice theme prev`, `bind = $mod, A, exec, rice anim next`
   - **add** under `exec-once = rice bg restore`: `exec-once = rice eyecare restore`
   - **add** under `env = QT_QPA_PLATFORM,wayland;xcb`: `env = QT_QPA_PLATFORMTHEME,kde` and `env = XDG_MENU_PREFIX,arch-`

   If you never edited `hyprland.conf`, simply `mv ~/.config/hypr/hyprland.conf.new ~/.config/hypr/hyprland.conf`. Delete the `.new` files when done.
4. **Run the one-time app setup and regenerate everything:**
   ```bash
   $ rice setup
   $ rice apply
   ```
5. **Clean up leftovers from the first versions:** `rm -rf ~/.vscode-oss/extensions/rice.rice-theme-1.0.0 ~/.vscode/extensions/rice.rice-theme-1.0.0` (VS Code is now themed through `settings.json`); in Chromium open `chrome://extensions` and remove the manually loaded "Rice" theme if you added one (the policy replaces it); an old `vscode_dirs` entry in `rice.json` is simply ignored.
6. **Log out and back in** once, so the new `env` lines and the eyecare autostart take effect. Theme/bar/background changes alone do not need a re-login.

Use `./install-dotfiles.sh --force` only if you want the factory state (everything overwritten; your previous files are still copied to `~/.dotfiles-backup-<date>`). To roll back at any time, copy the files from that backup folder back.

---

## 2. Wi-Fi

### 2.1 From the live USB (`iwctl`)

The official Arch ISO ships **iwd** (`iwctl`), not NetworkManager, so `nmcli` is *not* available on it. (If you boot a different live image that includes NetworkManager, use `nmcli device wifi connect "SSID" --ask` instead.)

```bash
# rfkill unblock all
# iwctl
[iwd]# device list                         # note the name, usually wlan0
[iwd]# station wlan0 scan
[iwd]# station wlan0 get-networks
[iwd]# station wlan0 connect "YourSSID"    # asks for the passphrase
[iwd]# exit
```

One-liner without the shell: `iwctl --passphrase 'secret' station wlan0 connect "YourSSID"`. Hidden network: `station wlan0 connect-hidden "SSID"`.

### 2.2 Verify

```bash
# iwctl station wlan0 show        # State should be "connected"
# ip -br addr                     # wlan0 must have an IP address
# ping -c3 1.1.1.1                # raw connectivity
# ping -c3 archlinux.org          # + DNS
# timedatectl                     # clock synced = TLS works
```

`1.1.1.1` works but `archlinux.org` does not → DNS problem (wait 10 s, retry, or try another network). Neither works → link/DHCP problem.

### 2.3 Troubleshooting

| Symptom | Fix |
|---|---|
| `device list` is empty | `rfkill list`; `rfkill unblock all`. Check a hardware Wi-Fi switch / `Fn` key. Then `lspci -k \| grep -A3 -i network`: if no "Kernel driver in use", the chip needs firmware or a driver (common: Broadcom `broadcom-wl`, some Realtek). Use phone USB tethering or Ethernet to install it. |
| Device exists but `Powered: off` | `iwctl device wlan0 set-property Powered on` (and `adapter phy0 set-property Powered on`). |
| `get-networks` empty | Run `station wlan0 scan` again, wait a few seconds. 5 GHz not visible → wrong regulatory domain: `iw reg set US` (your country code). |
| Wrong passphrase / "Operation failed" | Retype; special characters need quotes. WPA3-only or enterprise (eduroam) networks need `iwd` profiles: put a file `/var/lib/iwd/<SSID>.8021x`; easier to tether your phone for the install. |
| Connected but no internet | Captive portal (hotel/campus): open the portal from another device, or tether. Check `ip route` has a default route. |
| `dmesg \| grep -i -E 'firmware\|iwl\|ath\|rtw\|brcm'` shows "failed to load firmware" | Missing firmware; install over another connection with `pacman -S linux-firmware` (already on the ISO) or the vendor package. |
| Works on ISO, not after install | You picked "copy ISO configuration" instead of NetworkManager. Fix: `sudo pacman -S networkmanager && sudo systemctl enable --now NetworkManager`, `sudo systemctl disable --now systemd-networkd iwd` if active, then `nmcli`. |
| Flaky / laggy on battery | Power saving: set `wifi.powersave = 2` in `/etc/NetworkManager/conf.d/wifi-powersave.conf` and `sudo systemctl restart NetworkManager`; also set `WIFI_PWR_ON_BAT=off` in `/etc/tlp.d/10-rice.conf`. |

### 2.4 In the installed system (auto-reconnect)

NetworkManager saves each network you connect to as a profile with autoconnect on, so it joins automatically at boot and after resume.

```bash
$ nmcli device wifi connect "SSID" --ask       # first time only
$ nmcli connection show                        # saved profiles
$ nmcli connection modify "SSID" connection.autoconnect yes connection.autoconnect-priority 10
$ nmtui                                        # text UI; the bar's network module opens it on click
$ systemctl status NetworkManager
```

Do not run `iwd` or `systemd-networkd` alongside NetworkManager.

---

## 3. Hyprland specs for a laptop (minimal, justified)

| Area | Recommendation | Justification |
|---|---|---|
| Integrated GPU (most laptops) | Intel: `mesa vulkan-intel intel-media-driver`. AMD: `mesa vulkan-radeon` | Open drivers, best idle power, hardware video decode. archinstall's driver choice installs the base. |
| NVIDIA hybrid | Keep the iGPU as the Hyprland GPU. Install the dGPU driver (`nvidia-open`, `nvidia-utils`) **only if you need it**, and run apps on it on demand | The dGPU idling costs several watts. Without a driver the dGPU stays powered down (runtime PM). |
| CPU power | `tlp` with `/etc/tlp.d/10-rice.conf` | Automatic AC/battery switching; sets `powersave` governor, `power` energy policy, no turbo on battery, PCIe/USB/audio/Wi-Fi power saving. |
| Don't also install | `power-profiles-daemon`, `auto-cpufreq`, `cpupower` services | Two tools fighting over the same knobs wastes battery. |
| Charge limit | Uncomment `START/STOP_CHARGE_THRESH_BAT0` (75/80) if `sudo tlp-stat -b` shows it is supported | Less battery wear when mostly plugged in. |
| Kernel params (optional) | Only if `powertop` shows a clear win: `pcie_aspm.policy=powersupersave` | Not universal; some SSDs/Wi-Fi misbehave. Add to the `options` line in `/boot/loader/entries/*.conf`. AMD: check `cat /sys/devices/system/cpu/amd_pstate/status` says `active`. |
| Swap | zram (archinstall default) | No disk activity. |
| Wi-Fi | `/etc/NetworkManager/conf.d/wifi-powersave.conf` (`wifi.powersave = 3`) | Radio sleeps between packets. |
| Hyprland | `misc:vfr = true`, blur off, shadows off, `smooth` or lighter animations | Hyprland only redraws when something changes; blur/shadow are the biggest GPU costs. |
| Idle | `hypridle`: dim 2.5 min → lock 5 min → screen off 5.5 min → suspend 15 min | The screen is the biggest consumer. |
| Terminal | `foot` | Smallest Wayland terminal, no GPU use. |
| Don't install | `thermald` unless Intel with thermal issues | Not needed on AMD; rarely helps battery. |

Diagnose: `sudo powertop` (Tunables tab, "Bad" items), `sudo tlp-stat -s -b -p`, `cat /sys/class/power_supply/BAT0/power_now` (µW; divide by 1e6 for watts). A modern laptop idling at a quiet desktop should draw roughly 4-8 W; much more usually means a Chromium tab, a hot dGPU, or a missing power-saving setting.

---

## 4. Dotfile structure

```text
dotfiles/
├── install-dotfiles.sh                  copies everything into $HOME
├── etc/
│   ├── tlp.d/10-rice.conf               battery tuning (sudo install)
│   └── NetworkManager/conf.d/wifi-powersave.conf
├── .local/bin/
│   ├── rice                             the manager (themes, bg, bar, animations)
│   └── rice-settings                    Tk settings GUI
└── .config/
    ├── hypr/
    │   ├── hyprland.conf                static: binds, input, layouts, autostart
    │   └── hypridle.conf                idle/lock/suspend timers
    ├── spicetify/Themes/rice/user.css   Spotify theme extras
    └── rice/
        ├── rice.json                    YOUR settings (fonts, gaps, opacity, bar layout...)
        ├── themes/*.toml                one file = one theme
        ├── animations/*.conf            one file = one animation preset
        ├── backgrounds/*.txt            one file = one ASCII background
        └── templates/*                  one template per app (waybar.css, foot.ini, ...)
```

**How it flows.** `rice apply` reads `rice.json` + the active theme + the templates, replaces `{{variables}}`, and writes the real config files:

| Generated file | Used by |
|---|---|
| `~/.config/hypr/generated/theme.conf`, `anim.conf` | Hyprland (sourced from `hyprland.conf`) |
| `~/.config/waybar/config.jsonc`, `style.css` | Waybar |
| `~/.config/foot/foot.ini`, `fuzzel/fuzzel.ini`, `mako/config`, `hypr/hyprlock.conf` | terminal, launcher, notifications, lock screen |
| `~/.config/spicetify/Themes/rice/color.ini` | Spotify |
| `~/.config/kdeglobals` + `~/.local/share/color-schemes/Rice.colors` | Dolphin and all Qt/KDE apps (Gwenview, Strawberry...) |
| `~/.config/mpv/mpv.conf` | mpv video player |
| `/etc/chromium/policies/managed/rice.json` (+ optional `~/.config/rice/chromium-theme/`) | Chromium (live) |
| `~/.config/Code - OSS/User/settings.json` (color keys only) | VS Code (live) |
| `<vault>/.obsidian/snippets/rice.css` + `appearance.json` | Obsidian (every vault) |
| `~/.config/spicetify/Themes/rice/color.ini` | Spotify |

**Never edit generated files**; edit `rice.json`, a theme, or a template, then run `rice apply`.

Template variables: every key of the active theme (`{{bg}}`, `{{accent}}`, ...), every key of `rice.json` (`{{rounding}}`, `{{font_ui}}`), plus `{{term_font}}`, `{{bar_font}}`, `{{font_size_big}}`, `{{theme_name}}`. Suffixes: `{{bg.hex}}` → `fdf4f5` (no `#`), `{{bg.rgb}}` → `253, 244, 245`.

---

## 5. Hotkeys

`Super` = the Windows key.

| Keys | Action |
|---|---|
| `Super+Return` | terminal (foot) |
| `Super+D` | launcher (fuzzel) |
| `Super+Q` | close window |
| `Super+F` / `Super+V` | fullscreen / toggle floating |
| `Super+J` / `Super+P` | toggle split / pseudotile |
| `Super+Arrows` | move focus |
| `Super+Shift+Arrows` | move window |
| `Super+Ctrl+Arrows` | resize window |
| `Super+1…9` / `Super+Shift+1…9` | go to / send to workspace |
| `Super+L` | lock screen |
| `Super+Shift+E` | exit Hyprland |
| `Print` | region screenshot → clipboard + `~/Pictures` |
| **`Super+B`** | **show / hide the bar** |
| `Super+Space` (or `Alt+Shift`) | next keyboard layout (en → ru → ge) |
| **`Super+Alt+M`** | **set the main background** |
| `Super+Alt+→` / `Super+Alt+←` | next / previous background |
| `Super+Alt+R` | random background |
| `Super+S` | **settings app** (themes, day/night, animations, fonts, bar layout: no separate hotkeys on purpose) |
| Volume / brightness / media keys | wpctl / brightnessctl / playerctl |
| `Super`+left-drag / right-drag | move / resize floating window |

Themes, day/night, animations and fonts deliberately have **no hotkeys**: use the settings app. Backgrounds keep theirs. Change a bind by editing the matching line in `~/.config/hypr/hyprland.conf` (then it applies instantly; Hyprland watches the file).

---

## 6. Theme switching

```bash
$ rice list themes          # 57 names (blue-pastel-day, blue-pastel-night, ... plus the 9 originals)
$ rice theme mint           # switch now
$ rice theme next           # cycle (CLI only; no hotkey)
$ rice toggle               # day <-> night (also the "Day / Night" button in rice-settings)
```

**Day / night.** `day_theme` and `night_theme` in `rice.json` are the two sides of the toggle (defaults: `sakura` and `lavender-night`). Change them with the settings app or `rice set night_theme black`.

**Automatic switching.** `rice set auto_daynight true`. The autostart loop checks every 15 minutes; hours are `day_start` (7) and `night_start` (19). It switches only when the phase *changes*, so a manual choice sticks until the next sunrise/sunset boundary.

**The 9 originals.** Pastel: `sakura`, `mint`, `sky` (light), `lavender-night`, `peach-dusk` (dark). Neutral: `pure-white`, `milky`, `charcoal`, `black` (pure black saves battery on OLED).

**The 48 color themes** are named `COLOR-VARIATION-day` / `COLOR-VARIATION-night`:

| Color | Variations (each has a day and a night version) |
|---|---|
| `blue`, `red`, `green`, `yellow`, `pink`, `purple`, `orange`, `brown` | `pastel` (soft, light-touch), `muted` (calm, low-saturation, easy on the eyes), `vivid` (rich, saturated accent) |

Example: `rice theme green-muted-night`. **`rice toggle` (the Day / Night button) switches to the matching sibling of the *same* color and variation** (`green-muted-night` ↔ `green-muted-day`). Automatic day/night switching does the same. For the 9 originals, which have no `-day`/`-night` pair, the toggle uses the `day_theme` / `night_theme` settings as before. Every theme was checked for readable text: body text contrast is at least 10:1 against its background, dim text at least 4.2:1, and text on accent buttons at least 4.6:1; the pastel accents are intentionally gentle.

Too many themes? Delete the files you do not want from `~/.config/rice/themes/`; nothing else needs editing.

**Adding a theme = adding one file.** Copy any file in `~/.config/rice/themes/` to a new name and change the colors; it appears everywhere (`rice list`, hotkey cycling, settings app) with no other edit.

```toml
# ~/.config/rice/themes/butter.toml
mode = "light"          # "light" or "dark": sets GTK color scheme + VS Code variant
bg = "#fffbea"          # window/page background
bg_alt = "#f7f0cf"      # bars, sidebars
surface = "#efe6b8"     # hovers, cards, selection
fg = "#5a5336"          # main text
fg_dim = "#9a925f"      # secondary text
accent = "#f0d56e"      # highlights, battery pill, borders
accent_alt = "#e8b7a0"  # gradient partner, secondary highlight
border = "#e6dca6"      # inactive borders, separators
red = "#e59a8a"
green = "#b4d6a0"
yellow = "#f2dca4"
blue = "#a9c4e0"
on_accent = "#4a4220"   # text drawn ON the accent color (must contrast with accent)
# optional: ascii = "#d9c98a"   # color of ASCII-art backgrounds (default: bg/accent blend)
```

Then `rice theme butter`. A missing key produces a clear error naming it.

---

## 7. Background switching

Backgrounds are plain `.txt` files in `~/.config/rice/backgrounds/`. `rice` renders the chosen one to a screen-sized PNG (centered, in the theme's colors, scaled to about 60% of the screen) and shows it with `swaybg`, a ~1 MB process with no animation, so battery cost is nil. Renders are cached in `~/.cache/rice/bg/`, so switching is instant after the first time per theme.

| Keys / command | Action |
|---|---|
| `Super+Alt+M` / `rice bg main` | jump to your **main** background |
| `Super+Alt+→` / `rice bg next` | next (alphabetical, wraps) |
| `Super+Alt+←` / `rice bg prev` | previous |
| `Super+Alt+R` / `rice bg random` | random (never the current one) |
| `rice bg set NAME` | a specific one |
| `rice bg pin` | make the **current** background the main one |
| `rice bg list` | list available backgrounds |

Choose the main background in the settings app ("Main background") or `rice set background_main moon`.

### 7.1 Filling the screen and soft edges (QHD and any other display)

Each background can carry its own options in a small file next to it, `~/.config/rice/backgrounds/NAME.toml` (edit by hand, or use the settings app's **Background art** tab, or `rice bg opts NAME '{"soften": 3}'`):

| Option | Values | Meaning |
|---|---|---|
| `fit` | `contain` / `cover` | `contain` shows the art at `scale`% of the screen, centered (the old behavior, which is why art did not fill your screen). **`cover` stretches the art to fill the whole display exactly**: every character cell becomes `screen width ÷ columns` by `screen height ÷ rows` pixels. Screen size is read from Hyprland, so QHD (2560×1440) just works. |
| `scale` | 20-100 | size in `contain` mode |
| `soften` | 0-10 | **0** crisp glyphs; **~2** soft edges but still visibly ASCII; **4+** smooth, image-like. It averages each character cell and blurs slightly, which removes the hard glyph steps and the row/column grid. |
| `feather` | 0-50 (%) | fades the art's outer border into the background color: no visible rectangle in `contain` mode, or a vignette in `cover` mode |
| `strength` | 0-1 | how strongly the ink color (an accent/background mix) shows; lower = calmer wallpaper |

Your `megumin.txt` ships with `fit = "cover"`, `soften = 2`, `strength = 0.4`. Try `soften = 3` if you still see sharp edges.

**Upscaling the ASCII (more characters = finer detail).** Your art is 213 columns, so at QHD each character is about 12 px wide. Re-convert the original image with more columns:

```bash
$ rice ascii ~/Pictures/solo_poses_NSPC_00033_transparent.png --cols 320 --name megumin320
$ rice bg set megumin320          # also tweak with: rice bg opts megumin320 '{"soften": 2}'
```

| `--cols` | Character size on QHD | Look |
|---|---|---|
| 213 | ~12 px | chunky, retro (your current art) |
| 320 | ~8 px | good balance (default) |
| 426 | ~6 px | fine detail, needs a small font; slower to render the first time |

The converter keeps transparent areas **empty** (your original used `]` characters as the background fill, which draws a dense block behind the character; keep your version if you like that texture). Options: `--invert` (swap which tones are dense), `--gamma 0.8` (brighter) / `1.3` (darker), `--aspect 0.6` (glyph width ÷ line height of your font; rows are computed so the art keeps the image's proportions). For an undistorted result in `cover` mode, use an image with the same aspect as your screen (16:9 for QHD; yours is 1024×576, which is 16:9).

Combine both ideas: 320+ columns **and** `soften` 2 gives the sharpest picture without hard edges. Rendered wallpapers are cached per theme and per option set, so only the first switch is slow.

**Adding one:** save any ASCII art as `~/.config/rice/backgrounds/myart.txt` (monospaced, any size; up to ~100 columns reads well). It is available immediately. Font for the art: setting `bg_font` (`mono`, `pixel`, `ui`). Pixel-font art looks great but check the font covers every character you use. Backgrounds re-render automatically when the theme changes. With several monitors, the first monitor's resolution is used and the image is stretched with `fill`.

---

## 8. Bar configuration

**Hide/show:** `Super+B` (sends `SIGUSR1` to Waybar). Hidden also releases the reserved screen space.

**Contents:** left: workspaces + active window; center: clock; right: keyboard layout, CPU, RAM, temperature, network, volume, **battery**. The battery is a bold accent-colored pill, larger than the rest, that turns green while charging, yellow ≤ 25% and red ≤ 12%.

**Placing modules.** Three ways, all equivalent:

1. Settings app → *Bar modules* tab: pick left / center / right / off per module → Apply.
2. CLI: `rice bar move battery left`, `rice bar move temperature off`.
3. `~/.config/rice/rice.json`:
   ```json
   "bar": {
     "left":   ["hyprland/workspaces"],
     "center": ["clock"],
     "right":  ["cpu", "memory", "temperature", "network", "battery"]
   }
   ```
   Order inside a list is the on-screen order. Run `rice apply` afterwards.

Available modules (`rice list modules`): `hyprland/workspaces`, `hyprland/window`, `clock`, `cpu`, `memory`, `temperature`, `battery`, `network`, `hyprland/language`, `wireplumber`, `backlight`, `tray`. Bar at the bottom: `rice set bar_position bottom`.

**Tuning module text/behavior:** edit the `MODULES` table near the top of `~/.local/bin/rice` (formats, thresholds, intervals). Examples: `"format": "{usage}%"` to drop the label, `"warning": 30`, `"interval": 10`. **Styling:** `~/.config/rice/templates/waybar.css` (the battery block is commented "loud on purpose"). Click actions: clock click toggles the long date; network click opens `nmtui`; layout click cycles layouts.

**Temperature shows nothing / wrong sensor?** Find your CPU sensor: `for f in /sys/class/hwmon/hwmon*/name; do echo $f $(cat $f); done`, then add `"hwmon-path": "/sys/class/hwmon/hwmonN/temp1_input"` to the `temperature` entry in `MODULES` (`coretemp` on Intel, `k10temp` on AMD).

---

## 9. Animations

Presets live in `~/.config/rice/animations/`. Switch in the settings app (`Super+S` → Look → Animations) or with `rice anim NAME` / `rice anim next`.

| Preset | Look | Cost |
|---|---|---|
| `off` | instant | zero |
| `eco` | 0.2 s fade/pop on windows only | almost zero |
| `minimal` | short fade/pop + workspace fade | very low |
| `smooth` (default) | soft pop-in, slide workspaces | low |
| `snappy` | quick slides, 0.2 s | low |

None animate borders heavily or use blur, which are the expensive parts. **Add one:** copy a preset to `~/.config/rice/animations/mine.conf` and edit it; the format is Hyprland's `animation = NAME, ON(1/0), SPEED(×100 ms), BEZIER, STYLE`. Names: `windows`, `fade`, `workspaces`, `border`. Styles: `popin 90%`, `slide`, `fade`. See the Hyprland wiki "Animations" page for more. Test with `rice anim mine`.

---

## 10. Fonts

| Font | Package | Use it for |
|---|---|---|
| **Monocraft** (Minecraft-style pixel) | AUR `ttf-monocraft` | Lock-screen clock; optionally bar (`rice set bar_font pixel`), terminal or ASCII art. Fun, less legible at small sizes: keep it for display text. |
| **JetBrainsMono Nerd Font** | `ttf-jetbrains-mono-nerd` | Terminal, bar (default), code editors, ASCII art. Ligatures + icons. |
| **Inter** | `inter-font` | UI text: launcher, notifications, Obsidian, VS Code UI. |
| **Noto Sans Georgian** (in `noto-fonts`) | `noto-fonts` | Fallback so Georgian text renders everywhere (already added to the bar and terminal font lists). |
| **Noto Color Emoji** | `noto-fonts-emoji` | Emoji. |

Cyrillic is covered by Inter and JetBrains Mono. Monocraft's Cyrillic/Georgian coverage depends on the release: missing glyphs fall back automatically to another font, so text never disappears, it just changes style.

**Change fonts:** settings app → *Fonts*, or `rice set font_ui "Inter"`, `rice set font_mono "JetBrainsMono Nerd Font"`, `rice set font_pixel "Monocraft"`, `rice set font_size 12`; `terminal_font`, `bar_font`, `bg_font` take `mono`, `pixel` or `ui`. Find exact family names with `fc-list : family | sort -u`. To use a font not installed from a package, drop it into `~/.local/share/fonts/` and run `fc-cache -f`.

---

## 11. Keyboard layouts (English / Russian / Georgian)

In `~/.config/hypr/hyprland.conf`:

```ini
input {
    kb_layout = us,ru,ge
    kb_variant =
    kb_options = grp:alt_shift_toggle
}
```

- **Switch:** `Alt+Shift` or `Super+Space` (cycles us → ru → ge → us). The bar shows the current layout (`us`/`ru`/`ge`); click it to cycle.
- **Variants** are positional, one per layout: `kb_variant = ,phonetic,` gives the phonetic Russian layout (`ru` variant `phonetic`) while keeping standard `us` and `ge`. List variants with `localectl list-x11-keymap-variants ru`.
- Add a language: append its xkb code to `kb_layout` and a comma to `kb_variant` (e.g. `us,ru,ge,de` / `,,,`).
- Caps Lock as a layout key instead: `kb_options = grp:caps_toggle`.
- Fonts: see chapter 10; Georgian needs `noto-fonts` (installed).

---

## 12. Changing visuals

Most things are one-line settings in `~/.config/rice/rice.json` (or the settings app, or `rice set KEY VALUE`). After editing the file by hand run `rice apply`.

| Want | Setting | Notes |
|---|---|---|
| Window opacity | `opacity_active`, `opacity_inactive` | `0.5`–`1.0`. Opacity forces a redraw of what's behind; `1.0` is cheapest. |
| Bar opacity | `bar_opacity` | `0` = invisible pills, `1` = solid. |
| Blur | `blur` (`true`/`false`), `blur_size` | Pretty but costs GPU; leave off on battery. Only visible if opacity < 1. |
| Shadows | `shadow` | Same trade-off. |
| Gaps | `gap_in`, `gap_out` | pixels |
| Rounded corners | `rounding` | `0` = square. Also rounds bar pills, launcher, notifications. |
| Border width | `border_size` | Color = theme `accent` → `accent_alt` gradient (active), `border` (inactive). |
| Colors | the theme `.toml` | Edit `accent`, `bg`, etc. |
| Bar look | `templates/waybar.css` | GTK CSS. |
| Terminal look/padding | `templates/foot.ini` | `pad=12x12`. |
| Launcher/notification look | `templates/fuzzel.ini`, `templates/mako.conf` | |
| Lock screen | `templates/hyprlock.conf` | |

Direct-edit workflow: edit a **template** or theme, then `rice apply`. For a quick experiment on the live system you can edit a generated file (e.g. `~/.config/hypr/generated/theme.conf`; Hyprland applies on save), but the next `rice apply` overwrites it, so copy the change back into the template.

Examples:

```bash
rice set opacity_inactive 0.88      # slightly see-through unfocused windows
rice set rounding 0                 # sharp, ultra-minimal
rice set gap_out 16                 # airy
rice set blur true                  # (costs battery)
```

---

### Eyecare mode (warm screen)

Tints the whole screen warmer to reduce blue light in the evening, using `hyprsunset` (official Hyprland tool, package `hyprsunset`; already in the package list, confirm with `pacman -Ss hyprsunset`). It is controlled from the settings app (**Eyecare** tab) with no hotkey, per your preference, and it is independent of the day/night *theme*.

| Setting | Meaning |
|---|---|
| `eyecare` | manual on/off |
| `eyecare_temp` | color temperature in kelvin, 2000-6500. Lower = warmer. |
| `eyecare_schedule` | if `true`, the schedule decides and the manual switch is ignored |
| `eyecare_start`, `eyecare_end` | schedule hours (24h); may wrap midnight, default 20 → 7 |

Warmth guide: `6500` neutral · `4500` mild · `4000` default · `3500` strong · `3000` very warm · `2500` candle-like.

CLI: `rice eyecare on|off`, `rice eyecare temp 3500`, `rice eyecare status`, or `rice set eyecare_schedule true`. It is restored at login by the autostart line `exec-once = rice eyecare restore`, and the 15-minute loop turns the schedule on/off. Applying it restarts the small `hyprsunset` process (about one second of screen flicker); idle cost is negligible. Screenshots and the screen content itself are unaffected; only the output color is tinted.

## 13. The settings app

`Super+S` or `rice-settings`. Requires `tk` (installed) and runs through XWayland (`xorg-xwayland`), so text can look soft on fractional scaling; it is a utility window, not a daily driver. It styles itself with your current theme.

Tabs: **Look** (theme, day/night themes, auto switching, animations, main background, opacity, blur, shadows), **Eyecare** (on/off, warmth, schedule), **Background art** (fit, softness, edge fade, strength per background), **Fonts**, **Layout** (gaps, border, rounding, bar opacity/position), **Bar modules** (left / center / right / off), **Apps** (extra Obsidian vault, auto-apply Spotify), plus buttons **Set up apps** and **Refresh apps only**. Press **Apply** to save and regenerate everything; **Day / Night** and **Next background** act immediately. Everything it does is just `rice set-many '{...}'`, so the same changes can be scripted.

The window is tiled by default; press `Super+V` to float it.

---

## 14. App theming (Dolphin, Chromium, VS Code, Spotify, Obsidian, media apps)

Goal: change the theme once and **all these apps follow with no manual clicking**. `rice apply` (run on every theme change) updates them; the one-time bit is `rice setup`.

### 14.1 One-time setup

```bash
$ sudo pacman -S --needed xdg-desktop-portal-gtk gnome-themes-extra     # already in the package list
$ sudo mkdir -p /etc/chromium/policies/managed && sudo chown $USER /etc/chromium/policies/managed
$ sudo chmod a+wr /opt/spotify -R && sudo chmod a+wr /opt/spotify/Apps -R   # Spotify (AUR package)
$ # start VS Code, Obsidian (open your vault) and Spotify (log in) once, then close them
$ rice setup
```

`rice setup` is safe to repeat. It tells you exactly which of the sudo lines above are still missing, configures spicetify, and runs `rice apply`. The settings app has a **Set up apps** button that does the same (log in `~/.cache/rice/setup.log`).

**Why the apps previously did not follow the system:** they only know "dark" or "light" through the desktop portal (`xdg-desktop-portal-gtk` + the `color-scheme` setting), and Hyprland's own portal does not provide it. The package above fixes that, and `rice apply` now sets the `color-scheme` and GTK theme on every switch, in addition to the explicit per-app mechanisms below, so nothing depends on the portal alone.

### 14.2 What happens per app

| App | Mechanism | Live? |
|---|---|---|
| **VS Code** | `rice` merges `workbench.colorCustomizations`, token colors, a base "Default Dark/Light Modern" theme and your monospace font into `settings.json` (Code - OSS and Code paths). VS Code applies settings changes instantly. | Yes |
| **Obsidian** | Detects every vault from Obsidian's own config, writes `.obsidian/snippets/rice.css`, enables it in `appearance.json`, and sets the base scheme (dark/light) to match. Snippets hot-reload. | Yes (restart Obsidian once the first time, so it re-reads `appearance.json`) |
| **Chromium** | A managed policy file sets the browser theme color (your accent) and forces dark/light to match. Chromium re-reads policies by itself. | Yes |
| **Spotify** | spicetify regenerates `color.ini`; `rice apply` runs `spicetify -q apply` in the background (turn off with `rice set spicetify_auto false`). | Needs a Spotify restart to show new colors |

**Things to know**

- **VS Code:** your `settings.json` is rewritten as plain JSON, so *comments in it are removed* (a copy is saved as `settings.json.rice-backup` the first time). Existing keys are kept. If the file cannot be parsed, `rice` leaves it alone and prints a warning. The rice owns these keys: `workbench.colorTheme`, `window.autoDetectColorScheme`, `workbench.colorCustomizations`, `editor.tokenColorCustomizations`, `editor.fontFamily`, `terminal.integrated.fontFamily`. Pastel keyword colors on light backgrounds are intentionally soft; darken `accent` in your theme if code contrast is too low.
- **Chromium:** a policy makes Chromium show "Managed by your organization" in its menu; that is normal here. Policy support for theme color and color scheme depends on the Chromium version (current Arch builds support it). I chose Chromium over Firefox because of this level of control; Firefox can only be matched with `userChrome.css` hacks. If you ever prefer a full custom theme (tab and toolbar colors exactly matching), `rice` also generates a theme extension in `~/.config/rice/chromium-theme`: `chrome://extensions` → Developer mode → Load unpacked → reload it after theme changes. Do not use both at once. `--ozone-platform=wayland` is set in `~/.config/chromium-flags.conf`.
- **Spotify:** spicetify patches the installed app, so Spotify updates can undo it; re-run `rice setup spotify`. Spotify must have been started and logged in once before the first setup. If the `rice` theme should be reset: `spicetify restore`.
- **Obsidian:** your own `theme` choice in Settings → Appearance is overridden by the dark/light match; community themes still work but their colors lose to the snippet.
- Individual steps: `rice setup chromium|vscode|obsidian|spotify|portal`.

### 14.3 Dolphin (and every other Qt/KDE app)

Dolphin reads its colors, fonts and icon theme from `~/.config/kdeglobals`, so `rice` generates that file (plus a `Rice.colors` scheme) from the active theme: window, view, button, selection and tooltip colors, your UI and monospace fonts, `breeze` / `breeze-dark` icons and the Breeze widget style. This also themes **Gwenview, Strawberry, Okular, Kate** and any other Qt/KDE app you install, because they read the same file.

Needs (already in the package list): `breeze`, `plasma-integration` (provides the `kde` Qt platform theme, selected by `env = QT_QPA_PLATFORMTHEME,kde` in `hyprland.conf`), `kio-extras`.

- **Live or not:** `rice` pings KDE's settings signal after writing, which makes running KDE apps repaint in most versions. If an already-open Dolphin keeps the old colors, close and reopen it. New windows are always correct.
- Your previous `~/.config/kdeglobals` is saved once as `kdeglobals.rice-backup`.
- **Empty "Open with" menu / no file associations** (a known issue outside Plasma): the config sets `XDG_MENU_PREFIX=arch-` and `archlinux-xdg-menu` is installed; then run `kbuildsycoca6 --noincremental` once.
- **Thumbnails** for videos/images/PDFs: `ffmpegthumbs`, `kdegraphics-thumbnailers`, `kio-extras` (installed); enable them in Dolphin → Settings → General → Previews.
- Only part-way themed? That is a hybrid Qt/GTK limitation; GTK apps use the GTK/portal route (`color-scheme` + Adwaita), Qt apps use `kdeglobals`. Both switch together.

### 14.4 Recommended image, video and audio apps

Chosen for low idle power, Wayland support and following the theme. All are in the official repos (confirm names with `pacman -Ss`).

| Job | Pick | Why | Lighter alternative |
|---|---|---|---|
| **Images** | **Gwenview** (`gwenview`) | Integrates with Dolphin (browse, rotate, tag, basic edit), supports modern formats with `kimageformats`, uses the same Qt theme, so it matches automatically. Adds almost nothing because Dolphin already installs the KDE libraries. | **imv** (`imv`): tiny, keyboard-driven, instant start; background color via `imv` config `[options] background=...` |
| **Video** | **mpv** (`mpv`) | Best efficiency: hardware decoding (`hwdec=auto-safe`, configured), native Wayland, tiny. `rice` themes its background and on-screen text from the theme (`~/.config/mpv/mpv.conf`). Keyboard-first; optional `uosc` script adds a nicer on-screen UI. | **Celluloid** (`celluloid`) if you want a normal GTK window around mpv |
| **Audio** | **Strawberry** (`strawberry`) | Full music-library manager, gapless, ReplayGain, tag editor, themed through Qt automatically. Idle cost is low. | **cmus** (`cmus`) in the terminal: single tiny process, uses the terminal colors, so it also follows every theme for free |

Set them as defaults (check exact `.desktop` names in `/usr/share/applications`):

```bash
$ xdg-mime default org.kde.gwenview.desktop image/png image/jpeg image/webp image/gif image/avif
$ xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm video/quicktime
$ xdg-mime default org.strawberrymusicplayer.strawberry.desktop audio/mpeg audio/flac audio/ogg audio/x-wav
```

Battery tips: for video, make sure VA-API works (`vainfo` from `libva-utils`; Intel needs `intel-media-driver`); hardware decode cuts playback power by half or more compared with software decode. Do not run Strawberry's visualisations on battery.

### 14.5 Updating only the apps (without re-applying everything)

Yes. You never need to reinstall or re-copy the dotfiles to update app themes; they are all generated from the *current theme* by one command, and you can limit it to some targets:

```bash
$ rice apply apps                    # Dolphin/Qt, VS Code, Obsidian, Chromium, Spotify, mpv, GTK color scheme
$ rice apply vscode obsidian         # just those two
$ rice apply desktop                 # the opposite: Hyprland, bar, terminal, launcher, notifications, lock, background
$ rice theme mint apps               # switch to the mint theme, but refresh ONLY the apps
$ rice list targets                  # apps desktop spotify chromium vscode obsidian kde mpv gtk hypr waybar foot fuzzel mako hyprlock bg eyecare
```

Notes:

- The chosen theme is stored once (`theme` in `rice.json`); a partial run just skips refreshing the other targets. They catch up on the next plain `rice apply` or theme switch. To keep the desktop and apps on **different** themes permanently is not built in; if you want it, tell me and it is a ~10-line addition.
- The settings app has a **Refresh apps only** button for the same thing.
- After **adding a brand-new theme file**, no re-install is needed either: `rice theme mynewtheme apps`.
- After editing an *app template* (for example `templates/obsidian.css`): `rice apply obsidian`.
- Spotify may need a restart to show the new colors, and Chromium/VS Code/Obsidian update live (section 14.2).

## 15. Further tuning and modifying the dotfiles

**Battery wins, in order of impact:** screen brightness (`brightnessctl set 40%`), fewer Chromium tabs, no blur/shadow, `tlp` in place, suspend on idle (already set), pure `black` theme on OLED, `snappy`/`eco`/`off` animations, `powertop` tunables. Measure before/after with `cat /sys/class/power_supply/BAT0/power_now`.

**Handy additions**

- Per-app float rules and workspace rules: Hyprland's rule syntax changed across 0.4x/0.5x, so check the wiki "Window Rules" page for your installed version before copying snippets.
- Clipboard history: `sudo pacman -S cliphist`, then `exec-once = wl-paste --watch cliphist store` and a bind running `cliphist list | fuzzel --dmenu | cliphist decode | wl-copy`.
- Bluetooth: `bluez bluez-utils`, `sudo systemctl enable --now bluetooth`, `bluetui` (TUI).
- Night light: `hyprsunset`, started from `exec-once`.
- Laptop lid/power button behavior: `/etc/systemd/logind.conf` (`HandleLidSwitch=suspend`).
- Snapshots (if you chose btrfs): `snapper` + `snap-pac`.

**Modifying the dotfiles safely**

- Keep them in Git: `cd ~ && git init --bare ~/.dotfiles` style, or simply copy `~/.config/hypr`, `~/.config/rice`, `~/.local/bin/rice*` into a repo; they contain no secrets.
- New app to theme: add `templates/myapp.conf` using `{{variables}}`, then one tuple in the `TARGETS` list at the top of `~/.local/bin/rice`: `("myapp.conf", "~/.config/myapp/config")`. That's all.
- New bar module: add its definition to `MODULES` in `rice` (it then shows in `rice list modules` and the settings app); see the Waybar wiki for module options.
- New hotkey: one `bind = ...` line in `hyprland.conf`.
- Revert everything: restore from `~/.dotfiles-backup-*`.

---

## Appendix: complete files

Every file below is shown in full with its install path (relative to your home folder, except `etc/` files, which go to `/etc/`).

### `~/.local/bin/rice`

````python
#!/usr/bin/env python3
"""rice - theme / animation / background / bar manager for the Hyprland dotfiles.

Usage: rice help
"""
import json, os, random, re, shutil, subprocess, sys, time, tomllib
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CFG = HOME / ".config/rice"
CACHE = HOME / ".cache/rice"
SETTINGS = CFG / "rice.json"
NULL = subprocess.DEVNULL

DEFAULTS = {
    "theme": "sakura", "day_theme": "sakura", "night_theme": "lavender-night",
    "auto_daynight": False, "day_start": 7, "night_start": 19, "auto_phase": "",
    "animation": "smooth",
    "font_ui": "Inter", "font_mono": "JetBrainsMono Nerd Font", "font_pixel": "Monocraft",
    "font_size": 11, "terminal_font": "mono", "bar_font": "mono", "bg_font": "mono",
    "gap_in": 4, "gap_out": 8, "border_size": 2, "rounding": 10,
    "opacity_active": 1.0, "opacity_inactive": 0.95, "bar_opacity": 0.85,
    "blur": False, "blur_size": 6, "shadow": False,
    "bar_position": "top",
    "bar": {
        "left": ["hyprland/workspaces", "hyprland/window"],
        "center": ["clock"],
        "right": ["hyprland/language", "cpu", "memory", "temperature", "network", "wireplumber", "battery"],
    },
    "background_main": "cat", "background_current": "cat",
    "obsidian_vault": "", "spicetify_auto": True,
    "eyecare": False, "eyecare_temp": 4000,
    "eyecare_schedule": False, "eyecare_start": 20, "eyecare_end": 7,
    "vscode_settings": ["~/.config/Code - OSS/User/settings.json", "~/.config/Code/User/settings.json"],
    "chromium_policy_dir": "/etc/chromium/policies/managed",
}

REQUIRED = ["mode", "bg", "bg_alt", "surface", "fg", "fg_dim", "accent", "accent_alt",
            "border", "red", "green", "yellow", "blue", "on_accent"]

# (target name, template file in ~/.config/rice/templates, destination)
TARGETS = [
    ("hypr", "hypr-theme.conf", "~/.config/hypr/generated/theme.conf"),
    ("waybar", "waybar.css", "~/.config/waybar/style.css"),
    ("foot", "foot.ini", "~/.config/foot/foot.ini"),
    ("fuzzel", "fuzzel.ini", "~/.config/fuzzel/fuzzel.ini"),
    ("mako", "mako.conf", "~/.config/mako/config"),
    ("hyprlock", "hyprlock.conf", "~/.config/hypr/hyprlock.conf"),
    ("spotify", "spicetify.ini", "~/.config/spicetify/Themes/rice/color.ini"),
    ("chromium", "chromium.json", "~/.config/rice/chromium-theme/manifest.json"),
    ("kde", "kdeglobals", "~/.config/kdeglobals"),
    ("kde", "kdeglobals", "~/.local/share/color-schemes/Rice.colors"),
    ("mpv", "mpv.conf", "~/.config/mpv/mpv.conf"),
]
# Targets for partial updates:  rice apply apps   |   rice apply vscode obsidian   |   rice theme black apps
GROUPS = {
    "apps": ["spotify", "chromium", "vscode", "obsidian", "kde", "mpv", "gtk"],
    "desktop": ["hypr", "waybar", "foot", "fuzzel", "mako", "hyprlock", "bg", "eyecare"],
}
ALL_TARGETS = [x for g in GROUPS.values() for x in g]

MODULES = {
    "hyprland/workspaces": {"format": "{icon}", "format-icons": {"active": "●", "default": "○", "empty": "·"},
                            "persistent-workspaces": {"*": 4}},
    "hyprland/window": {"max-length": 40, "separate-outputs": True},
    "clock": {"format": "{:%H:%M}", "format-alt": "{:%a %d %b  %H:%M}", "tooltip-format": "{:%A, %d %B %Y}"},
    "cpu": {"format": "CPU {usage}%", "interval": 5},
    "memory": {"format": "RAM {percentage}%", "interval": 10},
    "temperature": {"format": "{temperatureC}°C", "interval": 10, "critical-threshold": 85},
    "battery": {"states": {"warning": 25, "critical": 12}, "interval": 20,
                "format": "BAT {capacity}%", "format-charging": "CHG {capacity}%",
                "format-plugged": "AC {capacity}%", "format-full": "FULL",
                "tooltip-format": "{timeTo}\n{power:.1f} W"},
    "network": {"format-wifi": "{essid} {signalStrength}%", "format-ethernet": "ETH",
                "format-disconnected": "offline", "tooltip-format": "{ifname}  {ipaddr}",
                "on-click": "foot -e nmtui", "interval": 10},
    "hyprland/language": {"format": "{short}", "on-click": "hyprctl switchxkblayout all next"},
    "wireplumber": {"format": "VOL {volume}%", "format-muted": "MUTE",
                    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"},
    "backlight": {"format": "LUM {percent}%"},
    "tray": {"spacing": 8},
}


# ---------------------------------------------------------------- helpers
def sh(*a, bg=False):
    try:
        if bg:
            subprocess.Popen(a, stdout=NULL, stderr=NULL, start_new_session=True)
        else:
            subprocess.run(a, stdout=NULL, stderr=NULL, timeout=30)
    except Exception:
        pass


def note(msg):
    sh("notify-send", "-t", "1500", "-h", "string:x-canonical-private-synchronous:rice", "rice", msg)


def expand(p):
    return Path(os.path.expanduser(str(p)))


def write(dest, text):
    d = expand(dest)
    d.parent.mkdir(parents=True, exist_ok=True)
    d.write_text(text)


def load():
    s = json.loads(json.dumps(DEFAULTS))
    if SETTINGS.exists():
        s.update(json.loads(SETTINGS.read_text()))
    return s


def save(s):
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(s, indent=2, ensure_ascii=False) + "\n")


def list_themes():
    return sorted(p.stem for p in (CFG / "themes").glob("*.toml"))


def list_anims():
    return sorted(p.stem for p in (CFG / "animations").glob("*.conf"))


def list_bgs():
    return sorted(p.stem for p in (CFG / "backgrounds").glob("*.txt"))


def load_theme(name):
    f = CFG / "themes" / f"{name}.toml"
    if not f.exists():
        sys.exit(f"rice: no such theme '{name}' (try: rice list themes)")
    t = tomllib.loads(f.read_text())
    missing = [k for k in REQUIRED if k not in t]
    if missing:
        sys.exit(f"rice: theme '{name}' is missing keys: {', '.join(missing)}")
    return t


def ctx(s):
    c = dict(s)
    c.update(load_theme(s["theme"]))
    fonts = {"mono": s["font_mono"], "pixel": s["font_pixel"], "ui": s["font_ui"]}
    c["theme_name"] = s["theme"]
    c["term_font"] = fonts.get(s["terminal_font"], s["font_mono"])
    c["bar_font"] = fonts.get(s["bar_font"], s["font_mono"])
    c["bg_font_family"] = fonts.get(s["bg_font"], s["font_mono"])
    c["font_size_big"] = int(s["font_size"]) + 2
    c["icon_theme"] = "breeze-dark" if c["mode"] == "dark" else "breeze"
    return c


PAT = re.compile(r"\{\{\s*(\w+)(?:\.(hex|rgbc|rgb))?\s*\}\}")


def render(text, c):
    def sub(m):
        k, mod = m.group(1), m.group(2)
        if k not in c:
            sys.exit(f"rice: template uses unknown variable '{k}'")
        v = c[k]
        if mod == "hex":
            return str(v).lstrip("#")
        if mod in ("rgb", "rgbc"):
            h = str(v).lstrip("#")
            return ("," if mod == "rgbc" else ", ").join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))
        if isinstance(v, bool):
            return str(v).lower()
        return str(v)
    return PAT.sub(sub, text)


def tpl(name, c):
    return render((CFG / "templates" / name).read_text(), c)


# ---------------------------------------------------------------- generators
def waybar_config(s):
    b = s["bar"]
    cfg = {"layer": "top", "position": s["bar_position"], "height": 30, "spacing": 6,
           "margin": "6 8 0 8" if s["bar_position"] == "top" else "0 8 6 8",
           "reload_style_on_change": True}
    for side in ("left", "center", "right"):
        cfg[f"modules-{side}"] = b.get(side, [])
        for m in b.get(side, []):
            if m in MODULES:
                cfg[m] = MODULES[m]
    return cfg


def load_jsonc(path):
    """Parse JSON with comments / trailing commas (VS Code settings.json)."""
    txt = path.read_text()
    out, i, n, in_str = [], 0, len(txt), False
    while i < n:
        ch = txt[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(txt[i + 1])
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
            out.append(ch)
        elif txt.startswith("//", i):
            while i < n and txt[i] != "\n":
                i += 1
            continue
        elif txt.startswith("/*", i):
            k = txt.find("*/", i + 2)
            i = n if k < 0 else k + 1
        else:
            out.append(ch)
        i += 1
    s = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
    return json.loads(s) if s.strip() else {}


def vscode(c, s):
    """Live theming: writes colorCustomizations into VS Code's settings.json (VS Code applies it instantly)."""
    th = json.loads(tpl("vscode.json", c))
    dark = c["mode"] == "dark"
    font = f"'{s['font_mono']}', monospace"
    for p in map(expand, s["vscode_settings"]):
        if not p.parent.parent.exists():
            continue
        try:
            cur = load_jsonc(p) if p.exists() else {}
        except Exception as e:
            print(f"rice: could not parse {p} ({e}); left untouched", file=sys.stderr)
            continue
        new = dict(cur)
        new["workbench.colorTheme"] = "Default Dark Modern" if dark else "Default Light Modern"
        new["window.autoDetectColorScheme"] = False
        new["workbench.colorCustomizations"] = th["colors"]
        new["editor.tokenColorCustomizations"] = {"textMateRules": th["tokenColors"]}
        new["editor.fontFamily"] = font
        new["terminal.integrated.fontFamily"] = font
        if new == cur and p.exists():
            continue
        p.parent.mkdir(parents=True, exist_ok=True)
        bak = p.with_name(p.name + ".rice-backup")
        if p.exists() and not bak.exists():
            bak.write_text(p.read_text())
        p.write_text(json.dumps(new, indent=2, ensure_ascii=False) + "\n")


def obsidian_vaults(s):
    vs = []
    if s["obsidian_vault"]:
        vs.append(expand(s["obsidian_vault"]))
    try:
        data = json.loads((HOME / ".config/obsidian/obsidian.json").read_text())
        vs += [Path(v["path"]) for v in data.get("vaults", {}).values()]
    except Exception:
        pass
    seen, out = set(), []
    for v in vs:
        if v not in seen and (v / ".obsidian").exists():
            seen.add(v)
            out.append(v)
    return out


def obsidian(c, s):
    """Writes the snippet into every known vault, enables it, and sets Obsidian's base scheme to match."""
    css = tpl("obsidian.css", c)
    for v in obsidian_vaults(s):
        write(v / ".obsidian/snippets/rice.css", css)
        ap = v / ".obsidian/appearance.json"
        try:
            a = json.loads(ap.read_text()) if ap.exists() else {}
        except Exception:
            continue
        b = dict(a)
        en = list(b.get("enabledCssSnippets", []))
        if "rice" not in en:
            en.append("rice")
        b["enabledCssSnippets"] = en
        b["theme"] = "obsidian" if c["mode"] == "dark" else "moonstone"
        if b != a:
            ap.write_text(json.dumps(b, indent=2))


def chromium(c, s):
    """Managed-policy theming: Chromium re-reads it live. Needs the one-time setup in `rice setup chromium`."""
    d = expand(s["chromium_policy_dir"])
    if not (d.is_dir() and os.access(d, os.W_OK)):
        return
    pol = {"BrowserThemeColor": c["accent"], "BrowserColorScheme": 2 if c["mode"] == "dark" else 1}
    f = d / "rice.json"
    txt = json.dumps(pol, indent=2) + "\n"
    if not f.exists() or f.read_text() != txt:
        f.write_text(txt)


# ---------------------------------------------------------------- backgrounds
def screen_size():
    env = os.environ.get("RICE_SCREEN", "")
    if re.fullmatch(r"\d+x\d+", env):
        return tuple(int(x) for x in env.split("x"))
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=5).stdout
        m = json.loads(out)[0]
        return int(m["width"]), int(m["height"])
    except Exception:
        return 1920, 1080


def mix(a, b, t):
    pa = [int(a.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    pb = [int(b.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return tuple(round(x * (1 - t) + y * t) for x, y in zip(pa, pb))


BG_DEFAULTS = {"fit": "contain", "scale": 60, "soften": 0, "feather": 0, "strength": 0.55}
RAMP = " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"


def bg_options(name):
    """Per-background render options: defaults overridden by backgrounds/NAME.toml."""
    o = dict(BG_DEFAULTS)
    f = CFG / "backgrounds" / f"{name}.toml"
    if f.exists():
        try:
            o.update(tomllib.loads(f.read_text()))
        except Exception:
            pass
    return o


def render_bg(name, c):
    """fit = contain: art at `scale`% of the screen.  fit = cover: art stretched to fill the whole screen exactly.
    soften = softness (0-10): 0 crisp glyphs, ~2 soft edges, 4+ smooth image, feather = fade the art's outer edge into the background (0-50 %),
    strength = how strongly the ink color shows (0-1)."""
    import hashlib
    from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
    o = bg_options(name)
    w, h = screen_size()
    fam = c["bg_font_family"]
    src = CFG / "backgrounds" / f"{name}.txt"
    key = hashlib.md5(json.dumps(["v3", o, c["bg"], c["accent"], c.get("ascii"), fam, w, h, src.stat().st_mtime_ns]).encode()).hexdigest()[:10]
    out = CACHE / "bg" / f"{c['theme_name']}-{name}-{key}.png"
    if out.exists():
        return out
    lines = src.read_text().expandtabs(4).rstrip("\n").split("\n")
    cols, rows = max(len(l) for l in lines), len(lines)
    path = subprocess.run(["fc-match", "-f", "%{file}", fam], capture_output=True, text=True).stdout.strip()
    adv = ImageFont.truetype(path, 100).getlength("M") / 100.0

    def font_at(sz):
        try:
            return ImageFont.truetype(path, sz)
        except Exception:
            return ImageFont.truetype(path, int(round(sz)))

    if o["fit"] == "cover":
        cw, lh = w / cols, h / rows
        font = font_at(cw / adv)
        x0 = y0 = 0.0
    else:
        best = 10
        frac = float(o["scale"]) / 100.0
        for sz in range(10, 120):
            if adv * sz * cols > w * frac or sz * 1.2 * rows > h * frac:
                break
            best = sz
        font = font_at(best)
        cw, lh = adv * best, best * 1.2
        x0, y0 = (w - cw * cols) / 2, (h - lh * rows) / 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for i, line in enumerate(lines):
        d.text((x0, y0 + i * lh), line, font=font, fill=255)
    soft = float(o["soften"])
    if soft > 0:
        # 1) blend toward a per-character-cell average: removes the row/column "grid" and glyph jaggies
        cells = mask.resize((cols, rows), Image.BOX).resize((w, h), Image.BICUBIC) if o["fit"] == "cover" else \
            mask.resize((max(1, round(w / cw)), max(1, round(h / lh))), Image.BOX).resize((w, h), Image.BICUBIC)
        mask = Image.blend(mask, cells, min(1.0, soft / 4.0))
        # 2) gentle round blur for soft silhouette edges
        mask = mask.filter(ImageFilter.GaussianBlur(soft * 0.05 * lh))
        gain = 1 + soft * 0.15
        mask = mask.point(lambda v: min(255, int(v * gain)))
    feather = float(o["feather"])
    if feather > 0:
        aw, ah = min(cw * cols, w), min(lh * rows, h)
        r = feather / 100.0 * min(aw, ah) * 0.5
        edge = Image.new("L", (w, h), 0)
        ex0, ey0 = max(x0, 0), max(y0, 0)
        ImageDraw.Draw(edge).rectangle([ex0 + r, ey0 + r, ex0 + aw - r, ey0 + ah - r], fill=255)
        mask = ImageChops.multiply(mask, edge.filter(ImageFilter.GaussianBlur(max(r / 2, 1))))
    ink = c.get("ascii") or "#%02x%02x%02x" % mix(c["bg"], c["accent"], float(o["strength"]))
    img = Image.composite(Image.new("RGB", (w, h), ink), Image.new("RGB", (w, h), c["bg"]), mask)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    return out


def write_bg_options(name, opts):
    f = CFG / "backgrounds" / f"{name}.toml"
    lines = []
    for k, v in opts.items():
        lines.append(f"{k} = {json.dumps(v)}")  # json scalars are valid TOML for str/int/float
    f.write_text("\n".join(lines) + "\n")


def cmd_ascii(args):
    """rice ascii IMAGE [--cols N] [--name NAME] [--invert] [--gamma G]: image -> backgrounds/NAME.txt"""
    import argparse
    from PIL import Image, ImageOps
    ap = argparse.ArgumentParser(prog="rice ascii")
    ap.add_argument("image")
    ap.add_argument("--cols", type=int, default=320, help="characters per row; more = sharper (default 320)")
    ap.add_argument("--name")
    ap.add_argument("--invert", action="store_true", help="swap which tones become dense characters")
    ap.add_argument("--gamma", type=float, default=1.0, help="<1 brighter, >1 darker")
    ap.add_argument("--aspect", type=float, default=0.6, help="glyph width/height of your font (default 0.6)")
    a = ap.parse_args(args)
    im = Image.open(a.image).convert("RGBA")
    rows = max(1, round(a.cols * im.height / im.width * a.aspect))
    im = im.resize((a.cols, rows), Image.LANCZOS)
    alpha = im.getchannel("A").load()
    lum = ImageOps.autocontrast(im.convert("L"), cutoff=1).point(lambda v: int(255 * (v / 255) ** a.gamma))
    px = lum.load()
    ramp = RAMP[::-1] if a.invert else RAMP
    out = []
    for y in range(rows):
        out.append("".join(" " if alpha[x, y] < 40 else ramp[min(len(ramp) - 1, px[x, y] * len(ramp) // 256)] for x in range(a.cols)))
    name = a.name or Path(a.image).stem
    (CFG / "backgrounds").mkdir(parents=True, exist_ok=True)
    (CFG / "backgrounds" / f"{name}.txt").write_text("\n".join(out) + "\n")
    if not (CFG / "backgrounds" / f"{name}.toml").exists():
        write_bg_options(name, {"fit": "cover", "soften": 2, "feather": 0, "strength": 0.5})
    print(f"wrote {name}.txt ({a.cols}x{rows}); try: rice bg set {name}")


def set_bg(name, s=None, c=None):
    s = s or load()
    c = c or ctx(s)
    old = subprocess.run(["pgrep", "-x", "swaybg"], capture_output=True, text=True).stdout.split()
    if name and (CFG / "backgrounds" / f"{name}.txt").exists():
        try:
            png = render_bg(name, c)
            sh("swaybg", "-i", str(png), "-m", "fill", "-c", c["bg"], bg=True)
        except Exception as e:
            print(f"rice: background render failed ({e}); using solid color", file=sys.stderr)
            sh("swaybg", "-c", c["bg"], bg=True)
    else:
        sh("swaybg", "-c", c["bg"], bg=True)
    time.sleep(0.4)
    for pid in old:
        try:
            os.kill(int(pid), 15)
        except Exception:
            pass


# ---------------------------------------------------------------- eyecare (warm screen via hyprsunset)
def eyecare_state(s):
    """Returns the wanted color temperature in kelvin as a string, or 'off'."""
    if s["eyecare_schedule"]:
        h, a, b = datetime.now().hour, int(s["eyecare_start"]), int(s["eyecare_end"])
        on = (h >= a or h < b) if a > b else (a <= h < b)
    else:
        on = bool(s["eyecare"])
    return str(int(s["eyecare_temp"])) if on else "off"


def eyecare_apply(s):
    want = eyecare_state(s)
    f = CACHE / "eyecare"
    pids = subprocess.run(["pgrep", "-x", "hyprsunset"], capture_output=True, text=True).stdout.split()
    have = f.read_text().strip() if f.exists() else "off"
    if want == have and bool(pids) == (want != "off"):
        return
    if want != "off":
        sh("hyprsunset", "-t", want, bg=True)
    time.sleep(0.3)
    for pid in pids:
        try:
            os.kill(int(pid), 15)
        except Exception:
            pass
    CACHE.mkdir(parents=True, exist_ok=True)
    f.write_text(want)


def sibling(name, phase):
    """blue-pastel-day <-> blue-pastel-night: the same color family in the other phase, if it exists."""
    m = re.fullmatch(r"(.+)-(day|night)", name)
    if m and (CFG / "themes" / f"{m.group(1)}-{phase}.toml").exists():
        return f"{m.group(1)}-{phase}"
    return None


def cycle(items, cur, d):
    if not items:
        return None
    i = (items.index(cur) + d) if cur in items else 0
    return items[i % len(items)]


# ---------------------------------------------------------------- apply
def resolve(targets):
    if not targets:
        return None
    out = set()
    for x in targets:
        if x in GROUPS:
            out.update(GROUPS[x])
        elif x in ALL_TARGETS:
            out.add(x)
        else:
            sys.exit(f"rice: unknown target '{x}' (try: rice list targets)")
    return out


def kde_notify():
    sh("dbus-send", "--session", "--type=signal", "/KGlobalSettings",
       "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0")


def apply(s=None, reload=True, only=None):
    """Regenerate configs. `only` limits it to some targets/groups (see GROUPS)."""
    s = s or load()
    c = ctx(s)
    only = resolve(only)
    on = lambda n: only is None or n in only
    for name, t, dest in TARGETS:
        if not on(name):
            continue
        d = expand(dest)
        if name == "kde" and d.name == "kdeglobals" and d.exists() and not d.with_name("kdeglobals.rice-backup").exists():
            d.with_name("kdeglobals.rice-backup").write_text(d.read_text())
        write(dest, tpl(t, c))
    if on("hypr"):
        anim = CFG / "animations" / f"{s['animation']}.conf"
        if not anim.exists():
            anim = CFG / "animations" / "smooth.conf"
        write("~/.config/hypr/generated/anim.conf", render(anim.read_text(), c))
    if on("waybar"):
        write("~/.config/waybar/config.jsonc", json.dumps(waybar_config(s), indent=2, ensure_ascii=False))
    if on("vscode"):
        vscode(c, s)
    if on("obsidian"):
        obsidian(c, s)
    if on("chromium"):
        chromium(c, s)
    if on("gtk"):
        sh("gsettings", "set", "org.gnome.desktop.interface", "color-scheme",
           "prefer-dark" if c["mode"] == "dark" else "prefer-light")
        sh("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme",
           "Adwaita-dark" if c["mode"] == "dark" else "Adwaita")
    if reload:
        if on("hypr"):
            sh("hyprctl", "reload")
        if on("waybar"):
            if subprocess.run(["pgrep", "-x", "waybar"], capture_output=True).returncode == 0:
                sh("pkill", "-SIGUSR2", "waybar")
            else:
                sh("waybar", bg=True)
        if on("mako"):
            sh("makoctl", "reload")
        if on("bg"):
            set_bg(s["background_current"], s, c)
        if on("eyecare"):
            eyecare_apply(s)
        if on("kde"):
            kde_notify()
        if on("spotify") and s["spicetify_auto"] and shutil.which("spicetify"):
            sh("spicetify", "-q", "apply", bg=True)


def set_theme(name, s=None, only=None):
    s = s or load()
    load_theme(name)
    s["theme"] = name
    save(s)
    apply(s, only=only)
    note(f"theme: {name}" + (f" ({' '.join(only)} only)" if only else ""))


# ---------------------------------------------------------------- commands
def cmd_bg(args):
    s = load()
    bgs = list_bgs()
    sub = args[0] if args else "restore"
    cur = s["background_current"]
    if sub == "restore":
        set_bg(cur, s)
        return
    if sub == "list":
        print("\n".join(bgs))
        return
    if sub == "main":
        new = s["background_main"]
    elif sub == "next":
        new = cycle(bgs, cur, 1)
    elif sub == "prev":
        new = cycle(bgs, cur, -1)
    elif sub == "random":
        new = random.choice([b for b in bgs if b != cur] or bgs)
    elif sub == "pin":
        s["background_main"] = cur
        save(s)
        note(f"main background: {cur}")
        return
    elif sub == "set" and len(args) > 1:
        new = args[1]
    elif sub == "info" and len(args) > 1:
        print(json.dumps(bg_options(args[1])))
        return
    elif sub == "opts" and len(args) > 2:
        f = CFG / "backgrounds" / f"{args[1]}.toml"
        cur = tomllib.loads(f.read_text()) if f.exists() else {}
        cur.update(json.loads(args[2]))
        write_bg_options(args[1], cur)
        return
    elif sub == "opt" and len(args) > 3:
        name, k, v = args[1], args[2], args[3]
        cur = {}
        f = CFG / "backgrounds" / f"{name}.toml"
        if f.exists():
            cur = tomllib.loads(f.read_text())
        try:
            cur[k] = json.loads(v)
        except Exception:
            cur[k] = v
        write_bg_options(name, cur)
        if name == s["background_current"]:
            set_bg(name, s)
        return
    else:
        sys.exit("usage: rice bg [restore|list|main|next|prev|random|pin|set NAME|info NAME|opt NAME KEY VALUE|opts NAME JSON]")
    s["background_current"] = new
    save(s)
    set_bg(new, s)
    note(f"background: {new}")


def cmd_bar(args):
    s = load()
    if not args or args[0] == "toggle":
        sh("pkill", "-SIGUSR1", "waybar")
        return
    if args[0] == "move" and len(args) == 3:
        m, side = args[1], args[2]
        if m not in MODULES:
            sys.exit("unknown module; see: rice list modules")
        for k in s["bar"]:
            if m in s["bar"][k]:
                s["bar"][k].remove(m)
        if side in ("left", "center", "right"):
            s["bar"][side].append(m)
        save(s)
        apply(s)
        return
    sys.exit("usage: rice bar [toggle | move MODULE left|center|right|off]")


def cmd_set(args):
    if len(args) != 2:
        sys.exit("usage: rice set KEY VALUE   (VALUE may be JSON)")
    s = load()
    try:
        v = json.loads(args[1])
    except Exception:
        v = args[1]
    s[args[0]] = v
    save(s)
    apply(s)


def cmd_setup(args):
    """One-time (idempotent) app integration. Prints the few sudo commands it cannot run itself."""
    s = load()
    what = args[0] if args else "all"
    want = lambda x: what in ("all", x)
    if want("portal"):
        for pkg in ("xdg-desktop-portal-gtk", "gnome-themes-extra"):
            if shutil.which("pacman") and subprocess.run(["pacman", "-Qq", pkg], capture_output=True).returncode != 0:
                print(f"[portal]   missing package -> sudo pacman -S {pkg}")
        print("[portal]   dark/light follows the theme mode via gsettings + the GTK portal")
    if want("chromium"):
        d = expand(s["chromium_policy_dir"])
        if d.is_dir() and os.access(d, os.W_OK):
            print("[chromium] policy folder ready; colors now follow the theme live")
        else:
            print(f"[chromium] one-time, run:  sudo mkdir -p {d} && sudo chown $USER {d}   then: rice setup chromium")
    if want("kde"):
        for pkg in ("breeze", "plasma-integration", "kio-extras"):
            if shutil.which("pacman") and subprocess.run(["pacman", "-Qq", pkg], capture_output=True).returncode != 0:
                print(f"[dolphin]  missing package -> sudo pacman -S {pkg}")
        print("[dolphin]  colors/fonts/icons come from ~/.config/kdeglobals (Dolphin, Gwenview, Strawberry, Okular...)")
    if want("vscode"):
        found = [str(p) for p in map(expand, s["vscode_settings"]) if p.parent.parent.exists()]
        print("[vscode]   will write live colors into: " + (", ".join(found) or "(start VS Code once first)"))
    if want("obsidian"):
        vs = obsidian_vaults(s)
        print("[obsidian] vaults: " + (", ".join(map(str, vs)) or "(none found; open a vault in Obsidian once, or: rice set obsidian_vault PATH)"))
    if want("spotify"):
        if not shutil.which("spicetify"):
            print("[spotify]  spicetify missing -> yay -S spicetify-cli spotify")
        elif Path("/opt/spotify").exists() and not os.access("/opt/spotify", os.W_OK):
            print("[spotify]  one-time, run:  sudo chmod a+wr /opt/spotify -R   then: rice setup spotify")
        else:
            subprocess.run(["spicetify", "config", "current_theme", "rice", "color_scheme", "base"], capture_output=True)
            r = subprocess.run(["spicetify", "backup", "apply"], capture_output=True, text=True, timeout=300)
            print("[spotify]  " + ("themed" if r.returncode == 0 else "spicetify said: " + (r.stdout + r.stderr).strip()[-300:] +
                  "\n           (start Spotify once and log in, then run: rice setup spotify)"))
    apply(s)
    print("done: everything above now follows `rice theme`.")


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "help"
    rest = a[1:]
    s = load()
    if cmd == "apply":
        apply(s, only=rest or None)
    elif cmd == "theme":
        t = rest[0] if rest else sys.exit("usage: rice theme NAME|next|prev")
        ts = list_themes()
        if t == "next":
            t = cycle(ts, s["theme"], 1)
        elif t == "prev":
            t = cycle(ts, s["theme"], -1)
        set_theme(t, s, only=rest[1:] or None)
    elif cmd == "toggle":
        m = re.fullmatch(r"(.+)-(day|night)", s["theme"])
        if m and sibling(s["theme"], "night" if m.group(2) == "day" else "day"):
            t = sibling(s["theme"], "night" if m.group(2) == "day" else "day")
        else:
            t = s["day_theme"] if s["theme"] == s["night_theme"] else s["night_theme"]
        set_theme(t, s)
    elif cmd == "auto":
        if s["eyecare_schedule"]:
            eyecare_apply(s)
        if not s["auto_daynight"]:
            return
        h = datetime.now().hour
        phase = "day" if s["day_start"] <= h < s["night_start"] else "night"
        if phase != s["auto_phase"]:
            s["auto_phase"] = phase
            save(s)
            set_theme(sibling(s["theme"], phase) or (s["day_theme"] if phase == "day" else s["night_theme"]), s)
    elif cmd == "anim":
        n = rest[0] if rest else sys.exit("usage: rice anim NAME|next")
        if n == "next":
            n = cycle(list_anims(), s["animation"], 1)
        if n not in list_anims():
            sys.exit("no such preset; see: rice list anims")
        s["animation"] = n
        save(s)
        apply(s)
        note(f"animations: {n}")
    elif cmd == "eyecare":
        sub = rest[0] if rest else "status"
        if sub in ("on", "off"):
            s["eyecare"] = sub == "on"
            save(s)
            eyecare_apply(s)
            note(f"eyecare: {sub}")
        elif sub == "temp" and len(rest) > 1:
            s["eyecare_temp"] = max(2000, min(6500, int(rest[1])))
            save(s)
            eyecare_apply(s)
            note(f"eyecare: {s['eyecare_temp']} K")
        elif sub == "restore":
            eyecare_apply(s)
        else:
            print(eyecare_state(s))
    elif cmd == "setup":
        cmd_setup(rest)
    elif cmd == "ascii":
        cmd_ascii(rest)
    elif cmd == "bg":
        cmd_bg(rest)
    elif cmd == "bar":
        cmd_bar(rest)
    elif cmd == "set":
        cmd_set(rest)
    elif cmd == "set-many":
        s.update(json.loads(rest[0]))
        save(s)
        apply(s)
    elif cmd == "get":
        print(s.get(rest[0], ""))
    elif cmd == "dump":
        print(json.dumps(s))
    elif cmd == "colors":
        print(json.dumps(load_theme(s["theme"])))
    elif cmd == "list":
        what = rest[0] if rest else ""
        items = {"themes": list_themes, "anims": list_anims, "bgs": list_bgs,
                 "modules": lambda: list(MODULES),
                 "targets": lambda: list(GROUPS) + ALL_TARGETS}.get(what)
        print("\n".join(items()) if items else "usage: rice list themes|anims|bgs|modules|targets")
    elif cmd == "shot":
        r = subprocess.run(["slurp"], capture_output=True, text=True)
        if r.returncode == 0:
            png = subprocess.run(["grim", "-g", r.stdout.strip(), "-"], capture_output=True).stdout
            pics = HOME / "Pictures"
            pics.mkdir(exist_ok=True)
            (pics / time.strftime("shot-%Y%m%d-%H%M%S.png")).write_bytes(png)
            subprocess.run(["wl-copy", "--type", "image/png"], input=png)
            note("screenshot copied + saved")
    else:
        print(__doc__)
        print("""Commands:
  apply [TARGET...]             regenerate configs; TARGET = apps | desktop | vscode | obsidian | chromium | spotify | kde | mpv | ... (rice list targets)
  setup [portal|chromium|vscode|obsidian|spotify]   one-time app integration
  theme NAME|next|prev [TARGET...]   switch theme (optionally only for some targets, e.g. `rice theme mint apps`)
  toggle                        switch day_theme <-> night_theme
  auto                          time-based day/night (used by autostart loop)
  anim NAME|next                switch animation preset (rice list anims)
  bg main|next|prev|random|pin|set NAME|list|restore|info NAME|opt NAME KEY VALUE
  ascii IMAGE [--cols N] [--name NAME] [--invert]   convert an image to an ASCII background
  eyecare on|off|temp KELVIN|restore|status   warm screen (hyprsunset), 2000-6500 K
  bar toggle | bar move MODULE left|center|right|off
  set KEY VALUE                 change any rice.json setting and apply
  shot                          region screenshot to clipboard + ~/Pictures
  list themes|anims|bgs|modules|targets""")


if __name__ == "__main__":
    main()
````

### `~/.local/bin/rice-settings`

````python
#!/usr/bin/env python3
"""rice-settings - small Tk GUI for the rice dotfiles. Talks to the `rice` CLI."""
import json, subprocess, tkinter as tk
from tkinter import ttk


def rice(*a):
    return subprocess.run(["rice", *a], capture_output=True, text=True).stdout


def load_state():
    return json.loads(rice("dump"))


S = load_state()
C = json.loads(rice("colors"))
THEMES = rice("list", "themes").split()
ANIMS = rice("list", "anims").split()
BGS = rice("list", "bgs").split()
MODULES = rice("list", "modules").split()
FONTS = sorted({f.split(",")[0].strip() for f in
                subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True).stdout.splitlines() if f.strip()})

root = tk.Tk()
root.title("Rice settings")
root.configure(bg=C["bg"])
root.option_add("*TCombobox*Listbox.background", C["bg_alt"])
root.option_add("*TCombobox*Listbox.foreground", C["fg"])
root.option_add("*TCombobox*Listbox.selectBackground", C["accent"])
root.option_add("*TCombobox*Listbox.selectForeground", C["on_accent"])
st = ttk.Style(root)
st.theme_use("clam")
st.configure(".", background=C["bg"], foreground=C["fg"], fieldbackground=C["bg_alt"],
             bordercolor=C["border"], lightcolor=C["bg"], darkcolor=C["bg"], troughcolor=C["bg_alt"])
# Inputs: explicit field + text colors in EVERY state (the "clam" style otherwise paints readonly
# comboboxes and focused fields white, which made light text on them unreadable).
FIELD, TXT = C["bg_alt"], C["fg"]
for w in ("TEntry", "TSpinbox", "TCombobox"):
    st.configure(w, fieldbackground=FIELD, background=FIELD, foreground=TXT, insertcolor=TXT,
                 arrowcolor=TXT, bordercolor=C["border"], lightcolor=FIELD, darkcolor=FIELD,
                 selectbackground=C["accent"], selectforeground=C["on_accent"])
    st.map(w, fieldbackground=[("readonly", FIELD), ("disabled", FIELD), ("focus", FIELD), ("active", FIELD)],
           background=[("readonly", FIELD), ("active", C["surface"])],
           foreground=[("readonly", TXT), ("disabled", C["fg_dim"]), ("focus", TXT)],
           selectbackground=[("readonly", FIELD), ("focus", C["accent"])],
           selectforeground=[("readonly", TXT), ("focus", C["on_accent"])],
           bordercolor=[("focus", C["accent"])])
st.configure("TCheckbutton", background=C["bg"], foreground=TXT, indicatorbackground=FIELD,
             indicatorforeground=TXT, indicatormargin=4)
st.map("TCheckbutton", background=[("active", C["bg"])], indicatorbackground=[("selected", C["accent"]), ("active", C["surface"])],
       indicatorforeground=[("selected", C["on_accent"])])
st.configure("TLabel", background=C["bg"], foreground=TXT)
st.configure("TFrame", background=C["bg"])
st.configure("TButton", background=C["accent"], foreground=C["on_accent"], padding=6)
st.map("TButton", background=[("active", C["accent_alt"])])
st.configure("TNotebook", background=C["bg"])
st.configure("TNotebook.Tab", background=C["bg_alt"], foreground=C["fg_dim"], padding=(12, 6))
st.map("TNotebook.Tab", background=[("selected", C["accent"])], foreground=[("selected", C["on_accent"])])

nb = ttk.Notebook(root)
nb.pack(fill="both", expand=True, padx=10, pady=10)
V = {}


def page(title):
    f = ttk.Frame(nb, padding=10)
    nb.add(f, text=title)
    f.columnconfigure(1, weight=1)
    return f


def row(f, label, key, kind, values=None, lo=0, hi=100, step=1):
    r = f.grid_size()[1]
    ttk.Label(f, text=label).grid(row=r, column=0, sticky="w", padx=6, pady=4)
    if kind == "choice":
        v = tk.StringVar(value=str(S[key]))
        w = ttk.Combobox(f, textvariable=v, values=values, state="readonly", width=32)
    elif kind in ("int", "float"):
        v = tk.StringVar(value=str(S[key]))
        w = ttk.Spinbox(f, textvariable=v, from_=lo, to=hi, increment=step, width=10)
    elif kind == "bool":
        v = tk.BooleanVar(value=bool(S[key]))
        w = ttk.Checkbutton(f, variable=v)
    else:
        v = tk.StringVar(value=str(S[key]))
        w = ttk.Entry(f, textvariable=v, width=34)
    w.grid(row=r, column=1, sticky="w", padx=6, pady=4)
    V[key] = (kind, v)


look = page("Look")
row(look, "Theme (now)", "theme", "choice", THEMES)
row(look, "Day theme", "day_theme", "choice", THEMES)
row(look, "Night theme", "night_theme", "choice", THEMES)
row(look, "Auto day/night", "auto_daynight", "bool")
row(look, "Day starts (hour)", "day_start", "int", lo=0, hi=23)
row(look, "Night starts (hour)", "night_start", "int", lo=0, hi=23)
row(look, "Animations", "animation", "choice", ANIMS)
row(look, "Main background", "background_main", "choice", BGS)
row(look, "Window opacity", "opacity_active", "float", lo=0.5, hi=1, step=0.05)
row(look, "Inactive opacity", "opacity_inactive", "float", lo=0.5, hi=1, step=0.05)
row(look, "Blur (costs battery)", "blur", "bool")
row(look, "Shadows (costs battery)", "shadow", "bool")

eye = page("Eyecare")
row(eye, "Eyecare mode on", "eyecare", "bool")
row(eye, "Warmth (kelvin, lower = warmer)", "eyecare_temp", "int", lo=2000, hi=6500, step=100)
row(eye, "Use schedule instead", "eyecare_schedule", "bool")
row(eye, "Schedule: starts at hour", "eyecare_start", "int", lo=0, hi=23)
row(eye, "Schedule: ends at hour", "eyecare_end", "int", lo=0, hi=23)
ttk.Label(eye, text="6500 = neutral | 4500 mild | 4000 default | 3500 strong | 3000 very warm | 2500 candle",
          foreground=C["fg_dim"]).grid(row=eye.grid_size()[1], column=0, columnspan=2, sticky="w", padx=6, pady=10)

fonts = page("Fonts")
row(fonts, "UI font", "font_ui", "choice", FONTS)
row(fonts, "Monospace font", "font_mono", "choice", FONTS)
row(fonts, "Pixel font", "font_pixel", "choice", FONTS)
row(fonts, "Font size", "font_size", "int", lo=8, hi=20)
row(fonts, "Terminal uses", "terminal_font", "choice", ["mono", "pixel", "ui"])
row(fonts, "Bar uses", "bar_font", "choice", ["mono", "pixel", "ui"])
row(fonts, "ASCII background uses", "bg_font", "choice", ["mono", "pixel", "ui"])

art = page("Background art")
bsel = tk.StringVar(value=S["background_current"])
BO = {}
ttk.Label(art, text="Background").grid(row=0, column=0, sticky="w", padx=6, pady=4)
ttk.Combobox(art, textvariable=bsel, values=BGS, state="readonly", width=32).grid(row=0, column=1, sticky="w", padx=6, pady=4)
BOPTS = [("Fit (cover = fill whole screen)", "fit", "choice", ["contain", "cover"]),
         ("Size when 'contain' (% of screen)", "scale", "num", (20, 100, 5)),
         ("Softness (0 crisp, 2 soft, 4+ smooth)", "soften", "num", (0, 10, 0.5)),
         ("Edge fade (% , fades art into background)", "feather", "num", (0, 50, 1)),
         ("Ink strength (0-1)", "strength", "num", (0, 1, 0.05))]
for i, (lab, key, kind, spec) in enumerate(BOPTS, start=1):
    ttk.Label(art, text=lab).grid(row=i, column=0, sticky="w", padx=6, pady=4)
    v = tk.StringVar()
    if kind == "choice":
        ttk.Combobox(art, textvariable=v, values=spec, state="readonly", width=12).grid(row=i, column=1, sticky="w", padx=6)
    else:
        ttk.Spinbox(art, textvariable=v, from_=spec[0], to=spec[1], increment=spec[2], width=10).grid(row=i, column=1, sticky="w", padx=6)
    BO[key] = (kind, v)


def bg_load(*_):
    info = json.loads(rice("bg", "info", bsel.get()) or "{}")
    for k, (_, v) in BO.items():
        v.set(str(info.get(k, "")))


def bg_apply():
    opts = {}
    for k, (kind, v) in BO.items():
        x = v.get()
        opts[k] = x if kind == "choice" else float(x)
    rice("bg", "opts", bsel.get(), json.dumps(opts))
    rice("bg", "set", bsel.get())
    status.set("Background art updated.")


ttk.Button(art, text="Apply to this background", command=bg_apply).grid(row=len(BOPTS) + 1, column=1, sticky="w", padx=6, pady=10)
bsel.trace_add("write", bg_load)
bg_load()

lay = page("Layout")
row(lay, "Inner gaps", "gap_in", "int", lo=0, hi=30)
row(lay, "Outer gaps", "gap_out", "int", lo=0, hi=60)
row(lay, "Border size", "border_size", "int", lo=0, hi=8)
row(lay, "Corner rounding", "rounding", "int", lo=0, hi=30)
row(lay, "Bar opacity", "bar_opacity", "float", lo=0, hi=1, step=0.05)
row(lay, "Bar position", "bar_position", "choice", ["top", "bottom"])

barp = page("Bar modules")
BV = {}
cur = {m: next((sd for sd in ("left", "center", "right") if m in S["bar"].get(sd, [])), "off") for m in MODULES}
for i, m in enumerate(MODULES):
    ttk.Label(barp, text=m).grid(row=i, column=0, sticky="w", padx=6, pady=3)
    v = tk.StringVar(value=cur[m])
    ttk.Combobox(barp, textvariable=v, values=["left", "center", "right", "off"], state="readonly", width=10).grid(row=i, column=1, sticky="w", padx=6)
    BV[m] = v

apps = page("Apps")
row(apps, "Extra Obsidian vault (optional)", "obsidian_vault", "text")
row(apps, "Auto-apply Spotify (spicetify)", "spicetify_auto", "bool")


def collect():
    out = {}
    for k, (kind, v) in V.items():
        x = v.get()
        out[k] = int(float(x)) if kind == "int" else float(x) if kind == "float" else bool(x) if kind == "bool" else x
    bar = {}
    for side in ("left", "center", "right"):
        chosen = [m for m in MODULES if BV[m].get() == side]
        keep = [m for m in S["bar"].get(side, []) if m in chosen]
        bar[side] = keep + [m for m in chosen if m not in keep]
    out["bar"] = bar
    return out


def apply_all():
    global S
    status.set("Applying...")
    root.update_idletasks()
    rice("set-many", json.dumps(collect()))
    S = load_state()
    status.set("Applied.")


def toggle():
    rice("toggle")
    V["theme"][1].set(load_state()["theme"])
    status.set("Toggled day/night.")


bar_ = ttk.Frame(root)
bar_.pack(fill="x", padx=10, pady=(0, 10))
ttk.Button(bar_, text="Apply", command=apply_all).pack(side="left", padx=4)
ttk.Button(bar_, text="Day / Night", command=toggle).pack(side="left", padx=4)
def setup_apps():
    import os
    log = os.path.expanduser("~/.cache/rice/setup.log")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    subprocess.Popen(["sh", "-c", f"rice setup > '{log}' 2>&1"])
    status.set("Setting up apps... see ~/.cache/rice/setup.log")


ttk.Button(bar_, text="Set up apps", command=setup_apps).pack(side="left", padx=4)
ttk.Button(bar_, text="Refresh apps only", command=lambda: (rice("apply", "apps"), status.set("Apps refreshed."))).pack(side="left", padx=4)
ttk.Button(bar_, text="Next background", command=lambda: rice("bg", "next")).pack(side="left", padx=4)
ttk.Button(bar_, text="Close", command=root.destroy).pack(side="right", padx=4)
status = tk.StringVar(value="")
ttk.Label(bar_, textvariable=status).pack(side="left", padx=12)
root.mainloop()
````

### `~/.config/hypr/hypridle.conf`

````ini
# ~/.config/hypr/hypridle.conf -- aggressive but sane idle handling for battery life
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}
listener {
    timeout = 150
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
listener {
    timeout = 900
    on-timeout = systemctl suspend
}
````

### `~/.config/hypr/hyprland.conf`

````ini
# ~/.config/hypr/hyprland.conf  -- static config. Colors/gaps/animations come from generated files.
source = ~/.config/hypr/generated/theme.conf
source = ~/.config/hypr/generated/anim.conf

$mod  = SUPER
$term = foot
$menu = fuzzel

monitor = , preferred, auto, 1

# ---------- autostart ----------
exec-once = rice bg restore
exec-once = rice eyecare restore
exec-once = waybar
exec-once = mako
exec-once = hypridle
exec-once = systemctl --user start hyprpolkitagent
exec-once = sh -c 'while true; do rice auto; sleep 900; done'

env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORM,wayland;xcb
env = QT_QPA_PLATFORMTHEME,kde
env = XDG_MENU_PREFIX,arch-
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# ---------- input: English / Russian / Georgian ----------
input {
    kb_layout = us,ru,ge
    kb_variant =
    kb_options = grp:alt_shift_toggle
    follow_mouse = 1
    repeat_rate = 35
    repeat_delay = 250
    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    layout = dwindle
    allow_tearing = false
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    force_default_wallpaper = 0
    vfr = true
}

# ---------- core binds ----------
bind = $mod, Return, exec, $term
bind = $mod, D, exec, $menu
bind = $mod, Q, killactive
bind = $mod SHIFT, E, exit
bind = $mod, F, fullscreen
bind = $mod, V, togglefloating
bind = $mod, P, pseudo
bind = $mod, J, togglesplit
bind = $mod, L, exec, pidof hyprlock || hyprlock
bind = , Print, exec, rice shot

bind = $mod, left, movefocus, l
bind = $mod, right, movefocus, r
bind = $mod, up, movefocus, u
bind = $mod, down, movefocus, d
bind = $mod SHIFT, left, movewindow, l
bind = $mod SHIFT, right, movewindow, r
bind = $mod SHIFT, up, movewindow, u
bind = $mod SHIFT, down, movewindow, d
binde = $mod CTRL, left, resizeactive, -40 0
binde = $mod CTRL, right, resizeactive, 40 0
binde = $mod CTRL, up, resizeactive, 0 -40
binde = $mod CTRL, down, resizeactive, 0 40

bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod, 4, workspace, 4
bind = $mod, 5, workspace, 5
bind = $mod, 6, workspace, 6
bind = $mod, 7, workspace, 7
bind = $mod, 8, workspace, 8
bind = $mod, 9, workspace, 9
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bind = $mod SHIFT, 4, movetoworkspace, 4
bind = $mod SHIFT, 5, movetoworkspace, 5
bind = $mod SHIFT, 6, movetoworkspace, 6
bind = $mod SHIFT, 7, movetoworkspace, 7
bind = $mod SHIFT, 8, movetoworkspace, 8
bind = $mod SHIFT, 9, movetoworkspace, 9
bind = $mod, mouse_down, workspace, e+1
bind = $mod, mouse_up, workspace, e-1
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow

# ---------- rice binds ----------
# Themes, day/night, animations, fonts etc. are controlled from rice-settings (Super+S), not hotkeys.
# Backgrounds keep hotkeys. Bar hide and layout switching are not in the settings app, so they keep theirs.
bind = $mod, B, exec, pkill -SIGUSR1 waybar
bind = $mod, S, exec, rice-settings
bind = $mod, Space, exec, hyprctl switchxkblayout all next
bind = $mod ALT, M, exec, rice bg main
bind = $mod ALT, right, exec, rice bg next
bind = $mod ALT, left, exec, rice bg prev
bind = $mod ALT, R, exec, rice bg random

# ---------- media / hardware keys ----------
bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
bindel = , XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
bindl  = , XF86AudioPlay, exec, playerctl play-pause
bindl  = , XF86AudioNext, exec, playerctl next
bindl  = , XF86AudioPrev, exec, playerctl previous
````

### `~/.config/rice/animations/eco.conf`

````ini
# fade only, very short: nearly free on the GPU
animations {
    enabled = true
    bezier = ease, 0.25, 0.1, 0.25, 1.0
    animation = windows, 1, 2, ease, popin 95%
    animation = fade, 1, 2, ease
    animation = workspaces, 0
    animation = border, 0
}
````

### `~/.config/rice/animations/minimal.conf`

````ini
animations {
    enabled = true
    bezier = ease, 0.25, 0.1, 0.25, 1.0
    animation = windows, 1, 3, ease, popin 90%
    animation = fade, 1, 3, ease
    animation = workspaces, 1, 3, ease, fade
    animation = border, 0
}
````

### `~/.config/rice/animations/off.conf`

````ini
animations {
    enabled = false
}
````

### `~/.config/rice/animations/smooth.conf`

````ini
animations {
    enabled = true
    bezier = soft, 0.22, 1.0, 0.36, 1.0
    animation = windows, 1, 5, soft, popin 85%
    animation = fade, 1, 5, soft
    animation = workspaces, 1, 5, soft, slide
    animation = border, 1, 5, soft
}
````

### `~/.config/rice/animations/snappy.conf`

````ini
animations {
    enabled = true
    bezier = snap, 0.05, 0.9, 0.1, 1.0
    animation = windows, 1, 2, snap, slide
    animation = fade, 1, 2, snap
    animation = workspaces, 1, 2, snap, slide
    animation = border, 0
}
````

### `~/.config/rice/backgrounds/cat.txt`

````text
   /\_/\   
  ( -.- )  zZ
  /     \  
 (_/   \_) 
````

### `~/.config/rice/backgrounds/cloud.txt`

````text
        .--.             
     .-(    ).      .-.  
    (___.__)__)    (   ) 
                  (_____)
 .-.                      
(   ).--.                 
 `-(      )               
   (___.__)               
````

### `~/.config/rice/backgrounds/megumin.toml`

````toml
fit = "cover"
soften = 2
feather = 0
strength = 0.4
````

### `~/.config/rice/backgrounds/megumin.txt`

(Your uploaded art, 213x72 characters; included in `dotfiles.zip`, not reprinted here.)

### `~/.config/rice/backgrounds/moon.txt`

````text
        *          .            *       
              _..._                     
     .      .'     '.         .         
           /    .-"`           *        
   *      |    /                        
          |    \          .             
           \    '-.__.-"               
     .      '._     _.'       *         
               ```''                    
````

### `~/.config/rice/backgrounds/mountains.txt`

````text
                    /\                          
          /\       /  \         /\              
         /  \     /    \   /\  /  \    /\       
    /\  /    \   /      \ /  \/    \  /  \      
   /  \/      \_/        V          \/    \_    
  /                                           \ 
 /_____________________________________________\
````

### `~/.config/rice/backgrounds/plant.txt`

````text
       \ | /       
     `.  \|/  .'   
   -- (  \|/  ) -- 
     .'  /|\  `.   
       / /|\ \     
          |        
        __|__      
       |     |     
        \___/      
````

### `~/.config/rice/backgrounds/waves.txt`

````text
 ~  ~~  ~~~  ~~  ~  ~~  ~~~  ~~  ~  ~~  ~~~  ~~ 
~~~  ~~  ~  ~~~  ~~  ~~~  ~~  ~  ~~~  ~~  ~~~  ~ 
 ~~  ~  ~~~  ~~  ~~~  ~~  ~  ~~~  ~~  ~  ~~~  ~~ 
~  ~~~  ~~  ~  ~~  ~  ~~~  ~~  ~  ~~~  ~~  ~  ~~ 
 ~  ~~  ~~~  ~~  ~  ~~  ~~~  ~~  ~  ~~  ~~~  ~~ 
````

### `~/.config/rice/rice.json`

````json
{
  "theme": "sakura",
  "day_theme": "sakura",
  "night_theme": "lavender-night",
  "auto_daynight": false,
  "day_start": 7,
  "night_start": 19,
  "animation": "smooth",
  "font_ui": "Inter",
  "font_mono": "JetBrainsMono Nerd Font",
  "font_pixel": "Monocraft",
  "font_size": 11,
  "terminal_font": "mono",
  "bar_font": "mono",
  "bg_font": "mono",
  "gap_in": 4,
  "gap_out": 8,
  "border_size": 2,
  "rounding": 10,
  "opacity_active": 1.0,
  "opacity_inactive": 0.95,
  "bar_opacity": 0.85,
  "blur": false,
  "blur_size": 6,
  "shadow": false,
  "bar_position": "top",
  "bar": {
    "left": ["hyprland/workspaces", "hyprland/window"],
    "center": ["clock"],
    "right": ["hyprland/language", "cpu", "memory", "temperature", "network", "wireplumber", "battery"]
  },
  "background_main": "cat",
  "background_current": "cat",
  "obsidian_vault": "",
  "spicetify_auto": true,
  "eyecare": false,
  "eyecare_temp": 4000,
  "eyecare_schedule": false,
  "eyecare_start": 20,
  "eyecare_end": 7
}
````

### `~/.config/rice/templates/chromium.json`

````json
{
  "manifest_version": 3,
  "name": "Rice {{theme_name}}",
  "version": "1.0",
  "theme": {
    "colors": {
      "frame": [{{bg_alt.rgb}}],
      "frame_inactive": [{{bg_alt.rgb}}],
      "toolbar": [{{bg.rgb}}],
      "tab_text": [{{fg.rgb}}],
      "tab_background_text": [{{fg_dim.rgb}}],
      "bookmark_text": [{{fg.rgb}}],
      "ntp_background": [{{bg.rgb}}],
      "ntp_text": [{{fg.rgb}}],
      "ntp_link": [{{accent.rgb}}],
      "button_background": [{{bg.rgb}}]
    }
  }
}
````

### `~/.config/rice/templates/foot.ini`

````ini
# GENERATED by `rice apply`
[main]
font={{term_font}}:size={{font_size}}, Noto Sans Georgian:size={{font_size}}
pad=12x12

[cursor]
color={{bg.hex}} {{accent.hex}}

[colors]
background={{bg.hex}}
foreground={{fg.hex}}
regular0={{surface.hex}}
regular1={{red.hex}}
regular2={{green.hex}}
regular3={{yellow.hex}}
regular4={{blue.hex}}
regular5={{accent_alt.hex}}
regular6={{accent.hex}}
regular7={{fg.hex}}
bright0={{border.hex}}
bright1={{red.hex}}
bright2={{green.hex}}
bright3={{yellow.hex}}
bright4={{blue.hex}}
bright5={{accent_alt.hex}}
bright6={{accent.hex}}
bright7={{fg.hex}}
````

### `~/.config/rice/templates/fuzzel.ini`

````ini
# GENERATED by `rice apply`
[main]
font={{font_ui}}:size={{font_size}}
terminal=foot -e
prompt="› "
width=36
lines=8

[colors]
background={{bg.hex}}ee
text={{fg.hex}}ff
match={{accent.hex}}ff
selection={{bg_alt.hex}}ff
selection-text={{fg.hex}}ff
selection-match={{accent.hex}}ff
border={{accent.hex}}ff

[border]
width=2
radius={{rounding}}
````

### `~/.config/rice/templates/hypr-theme.conf`

````ini
# GENERATED by `rice apply` -- edit ~/.config/rice/rice.json or the templates instead.
general {
    gaps_in = {{gap_in}}
    gaps_out = {{gap_out}}
    border_size = {{border_size}}
    col.active_border = rgb({{accent.hex}}) rgb({{accent_alt.hex}}) 45deg
    col.inactive_border = rgb({{border.hex}})
}
decoration {
    rounding = {{rounding}}
    active_opacity = {{opacity_active}}
    inactive_opacity = {{opacity_inactive}}
    blur {
        enabled = {{blur}}
        size = {{blur_size}}
        passes = 2
    }
    shadow {
        enabled = {{shadow}}
        range = 12
        render_power = 3
        color = rgba({{fg.hex}}22)
    }
}
````

### `~/.config/rice/templates/hyprlock.conf`

````ini
# GENERATED by `rice apply`
general {
    hide_cursor = true
    grace = 0
}
background {
    monitor =
    color = rgb({{bg.hex}})
}
label {
    monitor =
    text = $TIME
    color = rgb({{fg.hex}})
    font_size = 64
    font_family = {{font_pixel}}
    position = 0, 90
    halign = center
    valign = center
}
input-field {
    monitor =
    size = 260, 46
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.3
    inner_color = rgb({{bg_alt.hex}})
    outer_color = rgb({{accent.hex}})
    font_color = rgb({{fg.hex}})
    fade_on_empty = false
    rounding = {{rounding}}
    placeholder_text = <i>password</i>
    position = 0, -40
    halign = center
    valign = center
}
````

### `~/.config/rice/templates/kdeglobals`

````text
# GENERATED by `rice apply` -- KDE/Qt colors, fonts and icons (Dolphin, Gwenview, Strawberry, ...)
[General]
ColorScheme=Rice
Name=Rice
font={{font_ui}},{{font_size}},-1,5,400,0,0,0,0,0,0,0,0,0,0,1
menuFont={{font_ui}},{{font_size}},-1,5,400,0,0,0,0,0,0,0,0,0,0,1
toolBarFont={{font_ui}},{{font_size}},-1,5,400,0,0,0,0,0,0,0,0,0,0,1
fixed={{font_mono}},{{font_size}},-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme={{icon_theme}}

[KDE]
widgetStyle=Breeze

[Colors:Window]
BackgroundNormal={{bg_alt.rgbc}}
BackgroundAlternate={{surface.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}

[Colors:View]
BackgroundNormal={{bg.rgbc}}
BackgroundAlternate={{bg_alt.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}

[Colors:Button]
BackgroundNormal={{surface.rgbc}}
BackgroundAlternate={{bg_alt.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}

[Colors:Selection]
BackgroundNormal={{accent.rgbc}}
BackgroundAlternate={{accent_alt.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent_alt.rgbc}}
ForegroundNormal={{on_accent.rgbc}}
ForegroundInactive={{on_accent.rgbc}}
ForegroundActive={{on_accent.rgbc}}
ForegroundLink={{on_accent.rgbc}}
ForegroundVisited={{on_accent.rgbc}}
ForegroundNegative={{on_accent.rgbc}}
ForegroundNeutral={{on_accent.rgbc}}
ForegroundPositive={{on_accent.rgbc}}

[Colors:Tooltip]
BackgroundNormal={{bg_alt.rgbc}}
BackgroundAlternate={{surface.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}

[Colors:Complementary]
BackgroundNormal={{bg_alt.rgbc}}
BackgroundAlternate={{surface.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}

[Colors:Header]
BackgroundNormal={{bg_alt.rgbc}}
BackgroundAlternate={{surface.rgbc}}
DecorationFocus={{accent.rgbc}}
DecorationHover={{accent.rgbc}}
ForegroundNormal={{fg.rgbc}}
ForegroundInactive={{fg_dim.rgbc}}
ForegroundActive={{accent.rgbc}}
ForegroundLink={{blue.rgbc}}
ForegroundVisited={{accent_alt.rgbc}}
ForegroundNegative={{red.rgbc}}
ForegroundNeutral={{yellow.rgbc}}
ForegroundPositive={{green.rgbc}}
````

### `~/.config/rice/templates/mako.conf`

````ini
# GENERATED by `rice apply`
font={{font_ui}} {{font_size}}
background-color={{bg}}
text-color={{fg}}
border-color={{accent}}
border-size=2
border-radius={{rounding}}
padding=10
margin=12
default-timeout=5000
anchor=top-right

[urgency=high]
border-color={{red}}
default-timeout=0
````

### `~/.config/rice/templates/mpv.conf`

````ini
# GENERATED by `rice apply`
hwdec=auto-safe
gpu-context=wayland
keep-open=yes
save-position-on-quit=yes
background-color={{bg}}
osd-font={{font_ui}}
osd-font-size=30
osd-color={{fg}}
osd-border-color={{bg}}
osd-border-size=2
sub-font={{font_ui}}
sub-font-size=44
````

### `~/.config/rice/templates/obsidian.css`

````css
/* GENERATED by `rice apply` -- enable the "rice" snippet in Settings > Appearance */
body.theme-dark, body.theme-light {
  --background-primary: {{bg}};
  --background-primary-alt: {{bg_alt}};
  --background-secondary: {{bg_alt}};
  --background-secondary-alt: {{surface}};
  --background-modifier-border: {{border}};
  --background-modifier-hover: {{surface}};
  --background-modifier-active-hover: {{surface}};
  --text-normal: {{fg}};
  --text-muted: {{fg_dim}};
  --text-faint: {{fg_dim}};
  --text-accent: {{accent}};
  --text-accent-hover: {{accent_alt}};
  --text-on-accent: {{on_accent}};
  --interactive-accent: {{accent}};
  --interactive-accent-hover: {{accent_alt}};
  --interactive-normal: {{bg_alt}};
  --interactive-hover: {{surface}};
  --text-selection: {{surface}};
  --h1-color: {{accent}};
  --h2-color: {{accent}};
  --h3-color: {{accent_alt}};
  --font-interface-override: "{{font_ui}}";
  --font-text-override: "{{font_ui}}";
  --font-monospace-override: "{{font_mono}}";
}
````

### `~/.config/rice/templates/spicetify.ini`

````ini
[base]
text = {{fg.hex}}
subtext = {{fg_dim.hex}}
main = {{bg.hex}}
main-elevated = {{bg_alt.hex}}
highlight = {{surface.hex}}
highlight-elevated = {{surface.hex}}
sidebar = {{bg_alt.hex}}
player = {{bg_alt.hex}}
card = {{surface.hex}}
shadow = {{bg.hex}}
selected-row = {{fg.hex}}
button = {{accent.hex}}
button-active = {{accent.hex}}
button-disabled = {{border.hex}}
tab-active = {{surface.hex}}
notification = {{surface.hex}}
notification-error = {{red.hex}}
equalizer = {{accent.hex}}
misc = {{border.hex}}
````

### `~/.config/rice/templates/vscode.json`

````json
{
  "name": "Rice {{theme_name}}",
  "type": "{{mode}}",
  "colors": {
    "editor.background": "{{bg}}",
    "editor.foreground": "{{fg}}",
    "editorCursor.foreground": "{{accent}}",
    "editor.selectionBackground": "{{surface}}",
    "editor.lineHighlightBackground": "{{bg_alt}}",
    "editorLineNumber.foreground": "{{fg_dim}}",
    "editorLineNumber.activeForeground": "{{fg}}",
    "editorIndentGuide.background1": "{{border}}",
    "editorWhitespace.foreground": "{{border}}",
    "editorGroup.border": "{{border}}",
    "editorGroupHeader.tabsBackground": "{{bg_alt}}",
    "editorWidget.background": "{{bg_alt}}",
    "tab.activeBackground": "{{bg}}",
    "tab.inactiveBackground": "{{bg_alt}}",
    "tab.activeForeground": "{{fg}}",
    "tab.inactiveForeground": "{{fg_dim}}",
    "tab.activeBorderTop": "{{accent}}",
    "tab.border": "{{border}}",
    "activityBar.background": "{{bg_alt}}",
    "activityBar.foreground": "{{accent}}",
    "activityBar.inactiveForeground": "{{fg_dim}}",
    "activityBar.border": "{{border}}",
    "sideBar.background": "{{bg_alt}}",
    "sideBar.foreground": "{{fg}}",
    "sideBar.border": "{{border}}",
    "sideBarTitle.foreground": "{{fg_dim}}",
    "statusBar.background": "{{accent}}",
    "statusBar.foreground": "{{on_accent}}",
    "titleBar.activeBackground": "{{bg_alt}}",
    "titleBar.activeForeground": "{{fg}}",
    "titleBar.inactiveBackground": "{{bg_alt}}",
    "panel.background": "{{bg}}",
    "panel.border": "{{border}}",
    "terminal.background": "{{bg}}",
    "terminal.foreground": "{{fg}}",
    "terminal.ansiRed": "{{red}}",
    "terminal.ansiGreen": "{{green}}",
    "terminal.ansiYellow": "{{yellow}}",
    "terminal.ansiBlue": "{{blue}}",
    "terminal.ansiMagenta": "{{accent_alt}}",
    "terminal.ansiCyan": "{{accent}}",
    "list.activeSelectionBackground": "{{surface}}",
    "list.activeSelectionForeground": "{{fg}}",
    "list.hoverBackground": "{{surface}}",
    "list.inactiveSelectionBackground": "{{surface}}",
    "input.background": "{{bg_alt}}",
    "input.border": "{{border}}",
    "dropdown.background": "{{bg_alt}}",
    "menu.background": "{{bg_alt}}",
    "button.background": "{{accent}}",
    "button.foreground": "{{on_accent}}",
    "badge.background": "{{accent}}",
    "badge.foreground": "{{on_accent}}",
    "focusBorder": "{{accent}}",
    "scrollbarSlider.background": "{{border}}"
  },
  "tokenColors": [
    {"scope": ["comment", "punctuation.definition.comment"], "settings": {"foreground": "{{fg_dim}}", "fontStyle": "italic"}},
    {"scope": ["string"], "settings": {"foreground": "{{green}}"}},
    {"scope": ["constant.numeric", "constant.language"], "settings": {"foreground": "{{yellow}}"}},
    {"scope": ["keyword", "storage"], "settings": {"foreground": "{{accent}}"}},
    {"scope": ["entity.name.function", "support.function"], "settings": {"foreground": "{{blue}}"}},
    {"scope": ["entity.name.type", "entity.name.class", "support.type"], "settings": {"foreground": "{{accent_alt}}"}},
    {"scope": ["variable.parameter"], "settings": {"foreground": "{{fg}}"}},
    {"scope": ["invalid"], "settings": {"foreground": "{{red}}"}}
  ]
}
````

### `~/.config/rice/templates/waybar.css`

````css
/* GENERATED by `rice apply` -- edit ~/.config/rice/templates/waybar.css */
* {
    font-family: "{{bar_font}}", "Noto Sans Georgian", sans-serif;
    font-size: {{font_size}}px;
    border: none;
    border-radius: 0;
    min-height: 0;
}
window#waybar { background: transparent; color: {{fg}}; }

#workspaces, #window, #clock, #cpu, #memory, #temperature, #network,
#language, #wireplumber, #backlight, #tray {
    background: rgba({{bg.rgb}}, {{bar_opacity}});
    color: {{fg}};
    padding: 2px 12px;
    margin: 0 2px;
    border-radius: {{rounding}}px;
}
#workspaces button { padding: 0 5px; background: transparent; color: {{fg_dim}}; }
#workspaces button.active { color: {{accent}}; }
#clock { font-weight: bold; }
#window { color: {{fg_dim}}; }
#temperature.critical { color: {{red}}; }
#network.disconnected { color: {{red}}; }
#language { color: {{accent_alt}}; }

/* Battery: loud on purpose */
#battery {
    background: {{accent}};
    color: {{on_accent}};
    font-weight: bold;
    font-size: {{font_size_big}}px;
    padding: 2px 16px;
    margin: 0 2px;
    border-radius: {{rounding}}px;
}
#battery.charging, #battery.plugged { background: {{green}}; }
#battery.warning:not(.charging) { background: {{yellow}}; }
#battery.critical:not(.charging) { background: {{red}}; }

tooltip { background: {{bg}}; border: 1px solid {{border}}; border-radius: {{rounding}}px; }
tooltip label { color: {{fg}}; }
````

### `~/.config/rice/themes/black.toml`

````toml
# rice theme: black  (copy this file to add a new theme; all keys below are required)
mode = "dark"
bg = "#000000"
bg_alt = "#0b0b0b"
surface = "#151515"
fg = "#e8e8e8"
fg_dim = "#7c7c7c"
accent = "#d0d0d0"
accent_alt = "#9a9a9a"
border = "#222222"
red = "#d9777f"
green = "#7fc096"
yellow = "#d9bf72"
blue = "#7fa3d6"
on_accent = "#000000"
````

### `~/.config/rice/themes/charcoal.toml`

````toml
# rice theme: charcoal  (copy this file to add a new theme; all keys below are required)
mode = "dark"
bg = "#2b2d31"
bg_alt = "#323439"
surface = "#3b3e44"
fg = "#dcdde0"
fg_dim = "#8d9097"
accent = "#a9afbb"
accent_alt = "#8a93a6"
border = "#44474e"
red = "#d98c92"
green = "#9cc4a8"
yellow = "#d9c48c"
blue = "#8fa8cc"
on_accent = "#202226"
````

### `~/.config/rice/themes/lavender-night.toml`

````toml
# rice theme: lavender-night  (copy this file to add a new theme; all keys below are required)
mode = "dark"
bg = "#1e1b2a"
bg_alt = "#262336"
surface = "#302c44"
fg = "#e6e0f2"
fg_dim = "#9a93b4"
accent = "#c3aaf0"
accent_alt = "#f0a9c8"
border = "#3a3652"
red = "#f0a0b0"
green = "#a8dcc0"
yellow = "#f2dca4"
blue = "#a4c4f0"
on_accent = "#1e1b2a"
````

### `~/.config/rice/themes/milky.toml`

````toml
# rice theme: milky  (copy this file to add a new theme; all keys below are required)
mode = "light"
bg = "#f6f1e9"
bg_alt = "#ece5d9"
surface = "#e2d9ca"
fg = "#4a443c"
fg_dim = "#8d857a"
accent = "#b9a88f"
accent_alt = "#cdbfa9"
border = "#ddd3c2"
red = "#d98e86"
green = "#9cc0a0"
yellow = "#e0c88a"
blue = "#9bb4cc"
on_accent = "#3a342c"
````

### `~/.config/rice/themes/mint.toml`

````toml
# rice theme: mint  (copy this file to add a new theme; all keys below are required)
mode = "light"
bg = "#f3faf6"
bg_alt = "#e4f3ea"
surface = "#d5ebdf"
fg = "#43554b"
fg_dim = "#86998d"
accent = "#8fcfb0"
accent_alt = "#a9d6e8"
border = "#cfe6d8"
red = "#e8a1a1"
green = "#9fd8b4"
yellow = "#efdca0"
blue = "#a5c9e6"
on_accent = "#2f4439"
````

### `~/.config/rice/themes/peach-dusk.toml`

````toml
# rice theme: peach-dusk  (copy this file to add a new theme; all keys below are required)
mode = "dark"
bg = "#241c1d"
bg_alt = "#2e2425"
surface = "#3a2d2e"
fg = "#f5e6df"
fg_dim = "#b09b95"
accent = "#f4b69a"
accent_alt = "#f0a0b0"
border = "#473738"
red = "#f0a0a8"
green = "#b0d8b8"
yellow = "#f2dca4"
blue = "#a8c4e8"
on_accent = "#2a1f20"
````

### `~/.config/rice/themes/pure-white.toml`

````toml
# rice theme: pure-white  (copy this file to add a new theme; all keys below are required)
mode = "light"
bg = "#ffffff"
bg_alt = "#f5f5f5"
surface = "#ebebeb"
fg = "#1a1a1a"
fg_dim = "#767676"
accent = "#4a4a4a"
accent_alt = "#9a9a9a"
border = "#e0e0e0"
red = "#d9777f"
green = "#6fae85"
yellow = "#d9b25f"
blue = "#6f93c4"
on_accent = "#ffffff"
````

### `~/.config/rice/themes/sakura.toml`

````toml
# rice theme: sakura  (copy this file to add a new theme; all keys below are required)
mode = "light"
bg = "#fdf4f5"
bg_alt = "#f8e8ec"
surface = "#f2dce2"
fg = "#5b4a52"
fg_dim = "#9c8790"
accent = "#e8a0b4"
accent_alt = "#c9b1e8"
border = "#ebd2d9"
red = "#e58a9a"
green = "#a8d5ba"
yellow = "#f2d6a2"
blue = "#a9c8e8"
on_accent = "#4a3540"
````

### `~/.config/rice/themes/sky.toml`

````toml
# rice theme: sky  (copy this file to add a new theme; all keys below are required)
mode = "light"
bg = "#f4f8fd"
bg_alt = "#e6eef9"
surface = "#d8e4f4"
fg = "#44546a"
fg_dim = "#8796ab"
accent = "#8fb8e8"
accent_alt = "#c3b5ea"
border = "#d3e0f1"
red = "#e8a0aa"
green = "#a6d8bd"
yellow = "#f0dba2"
blue = "#8fb8e8"
on_accent = "#2d3d54"
````

### `~/.config/spicetify/Themes/rice/user.css`

````css
/* Extra CSS for the rice Spotify theme. Colors come from color.ini (generated by `rice apply`). */
````

### `/etc/NetworkManager/conf.d/wifi-powersave.conf`

````ini
# /etc/NetworkManager/conf.d/wifi-powersave.conf
# 3 = enable Wi-Fi power saving. If Wi-Fi gets laggy/flaky, change to 2 (disable).
[connection]
wifi.powersave = 3
````

### `/etc/tlp.d/10-rice.conf`

````ini
# /etc/tlp.d/10-rice.conf -- battery-first TLP profile
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto
PCIE_ASPM_ON_BAT=powersupersave
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
USB_AUTOSUSPEND=1
SOUND_POWER_SAVE_ON_BAT=1
# Battery longevity (only some laptops, e.g. ThinkPad/ASUS/Framework; uncomment if `tlp-stat -b` says supported)
#START_CHARGE_THRESH_BAT0=75
#STOP_CHARGE_THRESH_BAT0=80
````

### `dotfiles/install-dotfiles.sh`

````bash
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
````

### The 48 color themes (`~/.config/rice/themes/COLOR-VARIATION-day|night.toml`)

Each file has exactly the same 14 keys as the example in chapter 6; this table lists every value (one file per row, included in `dotfiles.zip`). To recreate one, write a file with `mode` plus these keys.

| theme | mode | bg | bg_alt | surface | fg | fg_dim | accent | accent_alt | border | red | green | yellow | blue | on_accent |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `blue-muted-day` | light | `#eef1f4` | `#e2e6ec` | `#d4dae2` | `#253141` | `#637083` | `#7693bc` | `#7e76bc` | `#cdd4dd` | `#b96764` | `#469b62` | `#9b8746` | `#6488b9` | `#151d28` |
| `blue-muted-night` | dark | `#1c1f24` | `#24282e` | `#2d3239` | `#e5eaf0` | `#919cac` | `#90a9cb` | `#9790cb` | `#353b43` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#151d28` |
| `blue-pastel-day` | light | `#f1f5fb` | `#e0eaf7` | `#ceddf3` | `#253141` | `#637083` | `#89b0e6` | `#aba2eb` | `#c4d6f0` | `#cd5551` | `#2e9e53` | `#a68b30` | `#5185cd` | `#151d28` |
| `blue-pastel-night` | dark | `#1a222e` | `#202b39` | `#273446` | `#e5eaf0` | `#919cac` | `#a2c1eb` | `#aba2eb` | `#2e3d52` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#151d28` |
| `blue-vivid-day` | light | `#eef3f9` | `#dee8f4` | `#cddbee` | `#253141` | `#637083` | `#2374e7` | `#3a23e7` | `#c4d4eb` | `#e3403b` | `#17a145` | `#aa8818` | `#3b81e3` | `#000000` |
| `blue-vivid-night` | dark | `#101823` | `#152030` | `#1c2a3e` | `#e5eaf0` | `#919cac` | `#5596f1` | `#6755f1` | `#21324a` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#151d28` |
| `brown-muted-day` | light | `#f3f1ef` | `#e9e6e4` | `#dfdbd7` | `#413025` | `#7d6b5e` | `#917664` | `#918e64` | `#dad4d0` | `#b16f6d` | `#529969` | `#998852` | `#6d89b1` | `#000000` |
| `brown-muted-night` | dark | `#221f1e` | `#2b2826` | `#363230` | `#f0e9e5` | `#ac9b91` | `#a58a79` | `#a5a279` | `#403b38` | `#cda3a2` | `#a2cdb0` | `#d8d0b6` | `#a2b4cd` | `#281d15` |
| `brown-pastel-day` | light | `#f9f5f3` | `#f2ebe6` | `#eaded6` | `#413025` | `#837063` | `#c7a289` | `#b7b267` | `#e6d8ce` | `#c0615d` | `#3c9a5b` | `#a28b3f` | `#5d87c0` | `#281d15` |
| `brown-pastel-night` | dark | `#29231e` | `#332b26` | `#3f352e` | `#f0e9e5` | `#ac9b91` | `#c7a289` | `#c7c389` | `#4a3e36` | `#d79a98` | `#98d7ad` | `#e0d4ae` | `#98b2d7` | `#281d15` |
| `brown-vivid-day` | light | `#f7f3f0` | `#efe8e3` | `#e7dcd5` | `#413025` | `#837063` | `#935d39` | `#938d39` | `#e2d5cd` | `#d2504b` | `#279b4e` | `#a38729` | `#4b84d2` | `#faf7f5` |
| `brown-vivid-night` | dark | `#1f1814` | `#2a211b` | `#362b23` | `#f0e9e5` | `#ac9b91` | `#be794b` | `#beb64b` | `#41332a` | `#e2908d` | `#8de2a9` | `#e9d9a5` | `#8db0e2` | `#281d15` |
| `green-muted-day` | light | `#eef3f0` | `#e2ebe5` | `#d5e2d9` | `#25412e` | `#5a7764` | `#70b386` | `#70b3aa` | `#cddcd2` | `#b96764` | `#469b62` | `#9b8746` | `#6488b9` | `#15281c` |
| `green-muted-night` | dark | `#1c231f` | `#242d27` | `#2d3931` | `#e5f0e9` | `#91ac9a` | `#89c39c` | `#89c3bb` | `#35423a` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#15281c` |
| `green-pastel-day` | light | `#f1fbf4` | `#e2f6e8` | `#d0f1db` | `#25412e` | `#5e7d69` | `#34c665` | `#34c6b3` | `#c6eed3` | `#cd5551` | `#2e9e53` | `#a68b30` | `#5185cd` | `#15281c` |
| `green-pastel-night` | dark | `#1b2d21` | `#213829` | `#294532` | `#e5f0e9` | `#91ac9a` | `#9ae5b3` | `#9ae5db` | `#30503a` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#15281c` |
| `green-vivid-day` | light | `#eef9f2` | `#e0f3e6` | `#cfedd9` | `#25412e` | `#5e7d69` | `#20c557` | `#20c5af` | `#c6e9d2` | `#e3403b` | `#17a145` | `#aa8818` | `#3b81e3` | `#15281c` |
| `green-vivid-night` | dark | `#112217` | `#172e1f` | `#1d3c28` | `#e5f0e9` | `#91ac9a` | `#4fe882` | `#4fe8d3` | `#23482f` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#15281c` |
| `orange-muted-day` | light | `#f4f1ee` | `#ece6e2` | `#e2dbd4` | `#413225` | `#7d6c5e` | `#b8906f` | `#b2b062` | `#ddd4cd` | `#b96764` | `#469b62` | `#9b8746` | `#6488b9` | `#281e15` |
| `orange-muted-night` | dark | `#241f1c` | `#2e2824` | `#39322d` | `#f0eae5` | `#ac9d91` | `#c8a589` | `#c8c689` | `#433b35` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#281e15` |
| `orange-pastel-day` | light | `#fbf6f1` | `#f7ebe0` | `#f3dfce` | `#413225` | `#837163` | `#e1a370` | `#b1ae25` | `#f0d8c4` | `#cd5551` | `#2e9e53` | `#a68b30` | `#5185cd` | `#281e15` |
| `orange-pastel-night` | dark | `#2e231a` | `#392b20` | `#463527` | `#f0eae5` | `#ac9d91` | `#eabe9a` | `#eae89a` | `#523e2e` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#281e15` |
| `orange-vivid-day` | light | `#f9f3ee` | `#f4e8de` | `#eedccd` | `#413225` | `#837163` | `#e67519` | `#aeac13` | `#ebd5c4` | `#e3403b` | `#17a145` | `#aa8818` | `#3b81e3` | `#281e15` |
| `orange-vivid-night` | dark | `#231910` | `#302115` | `#3e2b1c` | `#f0eae5` | `#ac9d91` | `#f0964c` | `#f0ee4c` | `#4a3421` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#281e15` |
| `pink-muted-day` | light | `#f4eef1` | `#ece2e6` | `#e2d4da` | `#412531` | `#836370` | `#bc7693` | `#bc7e76` | `#ddcdd4` | `#b96764` | `#42945e` | `#9b8746` | `#6488b9` | `#28151d` |
| `pink-muted-night` | dark | `#241c1f` | `#2e2428` | `#392d32` | `#f0e5ea` | `#ac919c` | `#cb90a9` | `#cb9790` | `#43353b` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#28151d` |
| `pink-pastel-day` | light | `#fbf1f5` | `#f7e0ea` | `#f3cedd` | `#412531` | `#836370` | `#e892b6` | `#e69489` | `#f0c4d6` | `#cd5551` | `#2e9e53` | `#9e842e` | `#5185cd` | `#28151d` |
| `pink-pastel-night` | dark | `#2e1a22` | `#39202b` | `#462734` | `#f0e5ea` | `#ac919c` | `#eba2c1` | `#ebaba2` | `#522e3d` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#28151d` |
| `pink-vivid-day` | light | `#f9eef3` | `#f4dee8` | `#eecddb` | `#412531` | `#836370` | `#e72374` | `#e73a23` | `#ebc4d4` | `#e3403b` | `#169841` | `#a18117` | `#3b81e3` | `#000000` |
| `pink-vivid-night` | dark | `#231018` | `#301520` | `#3e1c2a` | `#f0e5ea` | `#ac919c` | `#f15596` | `#f16755` | `#4a2132` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#28151d` |
| `purple-muted-day` | light | `#f1eef4` | `#e6e2ec` | `#dbd4e2` | `#322541` | `#726383` | `#9776bc` | `#bc76bc` | `#d4cddd` | `#b96764` | `#42945e` | `#9b8746` | `#6488b9` | `#1e1528` |
| `purple-muted-night` | dark | `#201c24` | `#28242e` | `#332d39` | `#eae5f0` | `#9d91ac` | `#ab90cb` | `#cb90cb` | `#3b3543` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#1e1528` |
| `purple-pastel-day` | light | `#f6f1fb` | `#ebe0f7` | `#dfcef3` | `#322541` | `#726383` | `#bf9aea` | `#e689e6` | `#d9c4f0` | `#cd5551` | `#2e9e53` | `#9e842e` | `#5185cd` | `#1e1528` |
| `purple-pastel-night` | dark | `#231a2e` | `#2c2039` | `#362746` | `#eae5f0` | `#9d91ac` | `#c4a2eb` | `#eba2eb` | `#3f2e52` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#1e1528` |
| `purple-vivid-day` | light | `#f3eef9` | `#e9def4` | `#ddcdee` | `#322541` | `#726383` | `#7e23e7` | `#e723e7` | `#d6c4eb` | `#e3403b` | `#169841` | `#a18117` | `#3b81e3` | `#f7f5fa` |
| `purple-vivid-night` | dark | `#191023` | `#221530` | `#2b1c3e` | `#eae5f0` | `#9d91ac` | `#9e55f1` | `#f155f1` | `#34214a` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#000000` |
| `red-muted-day` | light | `#f4eeee` | `#ece2e2` | `#e2d5d4` | `#412625` | `#836463` | `#b8726f` | `#b8996f` | `#ddcdcd` | `#b96764` | `#42945e` | `#9b8746` | `#6488b9` | `#281615` |
| `red-muted-night` | dark | `#241c1c` | `#2e2424` | `#392d2d` | `#f0e5e5` | `#ac9191` | `#c88b89` | `#c8ac89` | `#433535` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#281615` |
| `red-pastel-day` | light | `#fbf1f1` | `#f7e1e0` | `#f3cfce` | `#412625` | `#836463` | `#e89492` | `#dba257` | `#f0c5c4` | `#cd5551` | `#2e9e53` | `#9e842e` | `#5185cd` | `#281615` |
| `red-pastel-night` | dark | `#2e1a1a` | `#392120` | `#462827` | `#f0e5e5` | `#ac9191` | `#ea9d9a` | `#eac79a` | `#522f2e` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#281615` |
| `red-vivid-day` | light | `#f9eeee` | `#f4dfde` | `#eececd` | `#412625` | `#836463` | `#e62019` | `#e68d19` | `#ebc5c4` | `#e3403b` | `#169841` | `#a18117` | `#3b81e3` | `#000000` |
| `red-vivid-night` | dark | `#231010` | `#301615` | `#3e1d1c` | `#f0e5e5` | `#ac9191` | `#f0514c` | `#f0a94c` | `#4a2321` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#281615` |
| `yellow-muted-day` | light | `#f4f2ee` | `#ece9e2` | `#e2dfd4` | `#413b25` | `#77705a` | `#bcab76` | `#9eb569` | `#ddd9cd` | `#b96764` | `#469b62` | `#9b8746` | `#6488b9` | `#282315` |
| `yellow-muted-night` | dark | `#24221c` | `#2e2b24` | `#39362d` | `#f0eee5` | `#aca591` | `#cbbd90` | `#b9cb90` | `#434035` | `#d39e9c` | `#9cd3af` | `#dcd2b2` | `#9cb3d3` | `#282315` |
| `yellow-pastel-day` | light | `#fbf9f1` | `#f7f2e0` | `#f3eace` | `#413b25` | `#7d765e` | `#d2ac2d` | `#8db927` | `#f0e6c4` | `#cd5551` | `#2e9e53` | `#a68b30` | `#5185cd` | `#282315` |
| `yellow-pastel-night` | dark | `#2e291a` | `#393320` | `#463f27` | `#f0eee5` | `#aca591` | `#ebdaa2` | `#d5eba2` | `#52492e` | `#df9390` | `#90dfab` | `#e6d7a8` | `#90b1df` | `#282315` |
| `yellow-vivid-day` | light | `#f9f7ee` | `#f4efde` | `#eee7cd` | `#413b25` | `#7d765e` | `#d3a717` | `#8dc115` | `#ebe2c4` | `#e3403b` | `#17a145` | `#aa8818` | `#3b81e3` | `#282315` |
| `yellow-vivid-night` | dark | `#231f10` | `#302915` | `#3e361c` | `#f0eee5` | `#aca591` | `#f1cd55` | `#c2f155` | `#4a4021` | `#ed8682` | `#82eda6` | `#f1dd9d` | `#82afed` | `#282315` |

