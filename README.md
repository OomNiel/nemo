![build](https://github.com/linuxmint/nemo/actions/workflows/build.yml/badge.svg)

Nemo
====
Nemo is a free and open-source software and official file manager of the Cinnamon desktop environment. 
It is a fork of GNOME Files (formerly named Nautilus).

Nemo also manages the Cinnamon desktop.
Since Cinnamon 6.0 (Mint 21.3), users can enhance their own Nemo with Spices named Actions.


History
====
Nemo started as a fork of the GNOME file manager Nautilus v3.4. Version 1.0.0 was released in July 2012 along with version 1.6 of Cinnamon,
reaching version 1.1.2 in November 2012.

Developer Gwendal Le Bihan named the project "nemo" after Jules Verne's famous character Captain Nemo, who is the captain of the Nautilus.

Features
====
Nemo v1.0.0 had the following features as described by the developers:
1. Ability to SSH into remote servers
2. Native support for FTP (File Transfer Protocol) and MTP (Media Transfer Protocol)
3. All the features Nautilus 3.4 had and which are missing in Nautilus 3.6 (all desktop icons, compact view, etc.)
4. Open in terminal (integral part of Nemo)
5. Open as root (integral part of Nemo)
6. Uses GVfs and GIO
7. File operations progress information (when copying or moving files, one can see the percentage and information about the operation on the window title and so also in the window list)
8. Proper GTK bookmarks management
9. Full navigation options (back, forward, up, refresh)
10. Ability to toggle between the path entry and the path breadcrumb widgets
11. Many more configuration options

MyNemo fork — changes from upstream
====
This repository is a personal fork of [linuxmint/nemo](https://github.com/linuxmint/nemo)
(`origin` = `OomNiel/nemo`, `upstream` = `linuxmint/nemo`). It adds the following on top of
upstream.

Green folder names in the list view
----
Directory names are drawn in a theme-aware green so that folders stand out from files.

- Light themes use dark green (`#006400`); dark themes use light green (`#90ee90`).
- The theme is classified by the luminance of its base colour (`theme_base_color`, with the
  text colour as a fallback), so it adapts to any light/dark theme.
- Selected rows keep the theme's selection colour, so the text stays readable.

Implemented in `src/nemo-list-view.c` (`filename_cell_data_func()`,
`filename_cell_set_folder_color()` and `nemo_list_view_theme_is_dark()`). Only the list view
is affected — the icon view and the desktop icons are unchanged.

"Backup" context-menu item
----
Adds **Backup** to the file/folder context menu. It makes a copy of each selected item in its
parent folder, named `<name>_YYYY-MM-DD_HH:MM:SS`; all items in one batch share a single
timestamp.

- `src/nemo-view.c` — `action_backup_callback()`, `nemo_view_backup_selection()`,
  `nemo_get_backup_name()`, the action entry and its menu visibility.
- `src/nemo-actions.h` — `NEMO_ACTION_BACKUP` and its configurable-menu-item info.
- `gresources/nemo-directory-view-ui.xml` — the menu item.
- `gresources/nemo-file-management-properties.glade` — the "Backup" toggle.
- `libnemo-private/org.nemo.gschema.xml` — the `selection-menu-backup` key
  (`org.nemo.preferences.menu-config`, default `true`).
- `libnemo-private/nemo-file-operations.c` — clears the one-shot `target_name` once the
  top-level destination has been resolved, so backing up a folder no longer renames every
  child instead of keeping its own name.

"Extra Pane" (split view) persistence
----
The dual-pane toggle state is remembered between sessions, even when the right pane holds no
restorable tab URIs (for example a search location).

- `src/nemo-window-menus.c` — writes `saved-split-view` as soon as the pane is toggled.
- `src/nemo-window.c` — restores the saved split state instead of requiring saved tab URIs.

Packaging
----
- `build-nemo-complete.sh` — builds the standard packages with `dpkg-buildpackage` and merges
  them into a single `nemo-complete` `.deb` (`nemo`, `nemo-data`, `libnemo-extension1`,
  `libnemo-extension-dev`, `gir1.2-nemo-3.0`; the `-dbg` package is omitted). It aborts if the
  bundled `libnemo-extension.so` does not contain the Backup menu item, because the menu/UI
  definitions live in that library rather than in the `nemo` binary.
- `packaging/nemo-complete.control` — control template for the combined package (it
  `Conflicts`/`Replaces` the standard packages).
- `data/nemo.appdata.xml` — AppStream metadata using the unique component id
  `io.github.OomNiel.MyNemo`, so graphical package stores (Zorin Store / GNOME Software) map
  "Files" to this package instead of an unrelated one.
- `data/meson.build` and `debian/nemo-data.install` — install the AppStream file into
  `share/metainfo`.
- `debian/rules` — additional `dh_girepository` staging so the build can use the local
  dependency prefix.
