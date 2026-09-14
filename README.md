# Omicon

Pick any installed application from a searchable top-bar panel, choose an image, and use it as the app icon. Omicon creates a user-level desktop entry, so system launchers remain untouched.

## Requirements

Omicon uses `imagemagick`, `desktop-file-utils`, `python`, `python-gobject`, and `gtk3`. These are included with a standard Omarchy installation. It runs helper processes with your user permissions and writes icon copies to `~/.local/share/icons/esh.omicon`, launcher overrides to `~/.local/share/applications`, and restoration data to `~/.local/state/esh.omicon`.

## Install

```bash
omarchy plugin add https://github.com/ESHAYAT102/omicon-omarchy-plugin.git --enable
```

During local development, link this checkout instead:

```bash
ln -s "$PWD" ~/.config/omarchy/plugins/esh.omicon
omarchy-shell shell rescanPlugins
omarchy plugin enable esh.omicon
```

## Usage

Click the image icon in the top bar, or drop an image onto it and then choose the target app. You can also open it with:

```bash
omarchy-shell shell summon esh.omicon '{}'
```

That command can also be assigned to a Hyprland keybinding or added to the Omarchy menu.

Changed images are copied into Omicon's data directory, so deleting the source image does not affect the app icon. Use the restore button beside a changed app to restore its original icon.

## Remove

Restore any icons you no longer want changed, then remove the plugin:

```bash
omarchy plugin remove esh.omicon
```

Icons left changed continue to work after removal because their copied files remain in your user data directory.

## Development

Run `./test.sh` to check the desktop-entry override.
