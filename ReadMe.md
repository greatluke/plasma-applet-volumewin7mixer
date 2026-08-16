# Audio Volume (Win7 Mixer) — Plasma 6

A Windows 7 style volume mixer for KDE Plasma, with vertical per-application sliders.

This is a **Plasma 6 port** of [Zren/plasma-applet-volumewin7mixer](https://github.com/Zren/plasma-applet-volumewin7mixer), which itself began as a fork of the default volume plasmoid from [plasma-pa](https://invent.kde.org/plasma/plasma-pa).

> **Plasma 5 users:** use [Zren's original](https://github.com/Zren/plasma-applet-volumewin7mixer) (v26). This will not load on Plasma 5.

## Screenshot

![Audio Volume (Win7 Mixer) running on Plasma 6](https://github.com/user-attachments/assets/9179efb1-741d-4e13-910e-be7a4927e535)

## Requirements

Plasma 6, plus the packages the widget builds on. These are present on almost any Plasma 6 desktop, but if the widget fails to load, a missing one is the usual cause:

* `plasma-pa` — the audio models (`org.kde.plasma.private.volume`)
* `plasma-workspace` — the media controller (`org.kde.plasma.private.mpris`)
* `plasma5support`, `kitemmodels`, `ksvg`, `kirigami`, `kcoreaddons`, `kdeclarative`
* `pulseaudio` or `pipewire-pulse` — `pactl` is used for the loopback / echo-cancel options

There is **nothing to compile**. The C++ plugin the Plasma 5 version needed was dropped; peak metering now uses `VolumeMonitor` from plasma-pa.

## Install

```
git clone https://github.com/greatluke/plasma6-applet-volumewin7mixer.git
cd plasma-applet-volumewin7mixer
./install
```

Then restart plasmashell, or use `./reinstall`, which does both.

Afterwards: **System Tray Settings → Entries → set "Audio Volume" to Disabled**, so the default widget isn't sitting alongside this one. Then drag "Audio Volume (Win7 Mixer)" onto your panel, or enable it in the system tray.

To update later: `git pull && ./reinstall`.

Note that `./install` removes any previously installed copy before installing, rather than upgrading in place. This matters because the port deletes files, and `kpackagetool6 --upgrade` leaves orphans behind that QML will still resolve.

## Usage

* **Scroll** over the panel icon to adjust the default output, or over any column in the popup to adjust that stream.
* **Middle-click** the panel icon to mute.
* **Right-click** a stream for mute, volume boost, per-channel sliders, port and profile selection, and properties.
* **Drag** an app's icon onto a device column to move that stream to the device.
* **Keyboard:** arrow keys move between streams and change volume, `M` mutes, `0`–`9` set volume directly, `Enter` makes a device default, `Menu` opens the context menu.

Media keys (Volume Up/Down/Mute) are handled by Plasma itself in Plasma 6, not by this widget.

## Development

```
./run                       # run in plasmoidviewer (needs plasma-sdk)
./build                     # produce a .plasmoid zip
python3 ./kpac i18n         # rebuild translations (needs gettext)
```

Debug output from an installed copy:

```
journalctl -f -t plasmashell
```

## Translations

French and Dutch are included, inherited from the original. A handful of strings added by this port are still untranslated and fall back to English.

To add a language, copy `package/translate/template.pot` to `<locale>.po`, fill in the `msgstr ""` entries, and run `python3 ./kpac i18n`.

## Porting notes

[PORTING.md](PORTING.md) documents every API change this port required, including several that KDE's [porting guide](https://develop.kde.org/docs/plasma/widget/porting_kf6/) doesn't mention — `PlasmoidItem` having to be the literal root object of `main.qml`, `SinkModel.defaultSink` moving to the `Server` singleton, `hasVolume` existing only on streams, and the system tray's wheel-event heuristic.

## Credits

* [Harald Sitter](https://invent.kde.org/plasma/plasma-pa) and the KDE team — the original plasma-pa applet
* [Chris Holland (Zren)](https://github.com/Zren) — the Win7 Mixer widget
* French translation by [@RValeye](https://github.com/RValeye), Dutch by [@Vistaus](https://github.com/Vistaus)

## License

GPL, as the original.
