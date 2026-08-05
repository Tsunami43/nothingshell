# nothingshell

![The bar, the dashboard, the launcher, the capture panel, and a theme change](.github/assets/demo.gif)

A desktop shell for Hyprland, written in QML on top of [quickshell](https://quickshell.outfoxxed.me).
A vertical bar, a hover dashboard, a launcher, a workspace overview, a capture panel, a settings
window, a lock screen and a matching greetd login screen — one process, no panel toolkit.

Arch is the supported distribution, and the support is the packaging rather than the shell: only
there does `install.sh` install anything, through pacman and an AUR helper.

![The settings window, and the shell out of the way](.github/assets/screenshots.jpg)

## Install

```sh
git clone https://github.com/Tsunami43/nothingshell ~/.config/quickshell/nothingshell
cd ~/.config/quickshell/nothingshell
./install.sh -y     # packages, the hyprland.conf line, first start — no questions
```

The script appends the line that wires the shell into `hyprland.conf` itself. If you are doing it
by hand, or turned that step down, here it is:

```
source = ~/.config/quickshell/nothingshell/hypr/nothingshell.conf
```

The login screen (optional):

```sh
sudo ~/.config/quickshell/nothingshell/greeter/install.sh
```

## Dependencies

Three are required — `quickshell`, `hyprland`, `qt6-shadertools` — plus `qt6-declarative` and
`qt6-multimedia`, which are QML imports rather than commands and so fail as an empty panel rather
than an error. Everything else backs exactly one feature and its absence costs only that feature.

`install.sh` installs them for you: on Arch through pacman, and whatever the repositories do not
carry (`gpu-screen-recorder`, `matugen`) through an AUR helper, if you have one. The full list,
with the reasoning, is in the script itself. On other distributions it prints the list and leaves
the installing to you.

## Configuration

Most of it is in the settings window (`SUPER+N`, or the launcher's Settings entry): theme,
wallpaper, font, displays, audio, network, VPN, Bluetooth, keyboard layouts, idle and lock, bar
modules, notifications, capture defaults.

Everything the shell writes lands outside the checkout — in `~/.config/nothingshell` and
`~/.local/state/nothingshell` — so an update never walks over what you set, and deleting the
repository does not take your settings with it.

## Removing it

The checkout is the installation, so removing it means deleting the directory. The order matters
here, hence three steps.

**1. The login screen**, if you installed it — first, while the script that removes it has not
been deleted along with the checkout:

```sh
sudo ~/.config/quickshell/nothingshell/greeter/install.sh --uninstall
sudo systemctl restart greetd    # kills the current graphical session!
```

It puts `/etc/greetd/config.toml` back from a backup and takes the copied shell away. Not the
newest backup: the installer makes one on every run, including runs when nothingshell was already
installed, so the newest one usually points right back here. What is wanted is the newest backup
from before it — that is the one the script looks for.

**2. The shell itself.** Take the `source = …/hypr/nothingshell.conf` line out of `hyprland.conf`
first: a missing file in a `source` is a hard error in Hyprland, so deleting the directory ahead
of that leaves the next `hyprctl reload` walking into it. Then:

```sh
qs -c nothingshell kill                         # stop the shell
rm -rf ~/.config/quickshell/nothingshell        # this is the uninstall
hyprctl reload                                  # re-read the config, now without the source line
```

**3. Settings and generated state** live outside the tree and survive on purpose. If you want them
gone too:

```sh
rm -rf ~/.config/nothingshell ~/.local/state/nothingshell
```

## Licence, and what it does not cover

The code — QML, shaders, scripts, packaging — is MIT. See [LICENSE](LICENSE).

A licence is permission you give for your own work, so the MIT grant reaches exactly as far as
what is written here, and no further. Two kinds of file in this repository are not that:

**The wallpapers** (`assets/wallpapers/*.mp4` and their thumbnails) are animated pixel art of
existing games and films — Hollow Knight, The Last of Us, Pokémon, Cyberpunk 2077 among them.
They were collected, not made here, so they carry their own authors' rights and their subjects'
rights, and the MIT grant above does not apply to them. They are here because a theme without its
background is not the theme; if that is a problem for you, delete them and the themes fall back to
a flat colour, which is a supported state rather than a broken one.

**The fonts** (`assets/fonts/`) are redistributable, under conditions that are worth honouring
rather than assuming: Inter and Departure Mono are SIL Open Font License, Material Symbols is
Apache-2.0. Both licences require their text to travel with the files — currently it does not,
which is an open item, not a claim that it is fine.

Dropping another `.ttf`/`.otf` into `assets/fonts` makes it selectable in Settings → Appearance
without touching any code.
