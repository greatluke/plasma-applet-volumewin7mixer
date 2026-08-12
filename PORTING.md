# Plasma 6 port notes

Ported from `Zren/plasma-applet-volumewin7mixer` (Plasma 5, widget v26) following
<https://zren.github.io/2024/03/13/commandoutput-dailyforecast-condensedweather-ported-to-plasma6>
and <https://develop.kde.org/docs/plasma/widget/porting_kf6/>.

## Deleted

| Removed | Why |
| --- | --- |
| `plugin/` (C++ `VolumePeaks`) | Replaced by `VolumeMonitor` from plasma-pa. No compiling needed anymore. |
| `package/contents/code/peak/*` (python peak monitor) | Same. `VolumeMonitor.volume` is already normalised 0..1. |
| `VolumePeaksManager.qml` | Same. |
| `PlasmaVolume.GlobalActionCollection` block in `main.qml` | Deleted from plasma-pa. Multimedia keys are owned by the `kded6` audioshortcuts service in Plasma 6; registering them here would fight with it. |
| `PlasmaVolume.VolumeOSD` | Deleted from plasma-pa. The OSD is now a DBus call to `org.kde.plasmashell /org/kde/osdService`. See `osdCall()` in `main.qml`. |
| `Mpris2DataSource.qml` | The `mpris2` DataEngine is gone. Replaced by `Mpris2Source.qml`, wrapping `org.kde.plasma.private.mpris` (libkmpris) and keeping the old property names. |
| `IconToolButton.qml` | Only used by commented-out code, and depended on `QtQuick.Controls.Private`. |
| `ConfigStreamRestore.qml` | Was already disabled, and used `TableView` from Controls 1. |
| `lib/AppletIcon.qml` | Unused. |
| `metadata.desktop` | Plasma 6 requires `metadata.json` with `KPackageStructure`. |
| `translate/build`, `translate/merge`, `translate/plasmoidlocaletest` | Obsolete; use `kpac i18n` (translations still need regenerating, see below). |

## Rewritten (not mechanical)

* **`VerticalVolumeSlider.qml`** — `QtQuick.Controls.Styles.Plasma.SliderStyle` is gone.
  Rebuilt on `PC3.Slider`. Note QQC1 rotated its whole panel for vertical sliders (which
  is why the win7 groove/wedge art in `volumeslider.svg` is drawn horizontally); QQC2 does
  not, so the groove now lives in a container rotated `-90` degrees. `minimumValue`/
  `maximumValue` became `from`/`to`.
* **`MixerItemGroup.qml`** — Controls 1 `GroupBox` + `GroupBoxStyle` replaced with a
  `KSvg.FrameSvgItem` frame and a header `ToolButton`.
* **`MixerItem.qml`** — `PlasmaComponents2.ListItem` replaced with a plain `Item` plus a
  listitem FrameSvgItem (PlasmaExtras.ListItem is a Control and would swallow slider
  clicks). `KAddons.MouseEventListener` wheel blocking replaced with the slider's own
  `WheelHandler` (`wheelUp`/`wheelDown` signals).
* **`PulseObjectDialog.qml`** — `TableView`/`TableViewColumn` replaced with a `ListView`.
* **`config/ConfigApplet.qml`** — QQC2; `ExclusiveGroup` became `ButtonGroup`, `SpinBox`
  uses `from`/`to`.
* **`DialogApplet.qml`** — deleted, merged into `main.qml`. The hand-rolled
  `PlasmaCore.Dialog` popup became the standard `PlasmoidItem.fullRepresentation`, since
  Plasma 6's shell manages applet popups itself; `openDialog()`/`closeDialog()`/
  `dialogVisible` are kept as wrappers around `expanded`.
  **`PlasmoidItem` must be the root object declared in `main.qml` itself** — it cannot be
  subclassed into another .qml file. `AppletQuickItem::classBegin()` requires the item's
  QQmlContext parent to be the `AppletContext`; one extra level of indirection leaves
  `applet` null and everything fails with "Could not create attached properties object
  'PlasmaQuick::PlasmoidAttached'".

## Mechanical replacements

`PlasmaCore.IconItem`→`Kirigami.Icon`, `PlasmaCore.Svg*`/`FrameSvgItem`→`KSvg.*`,
`PlasmaCore.DataSource`→`Plasma5Support.DataSource`, `PlasmaCore.SortFilterModel`→
`KItemModels.KSortFilterProxyModel`, `PlasmaComponents2.ContextMenu/MenuItem`→
`PlasmaExtras.Menu/MenuItem`, `units.*`→`Kirigami.Units.*`, `theme.*`→`Kirigami.Theme.*`
(`smallestFont`→`smallFont`), `org.kde.kcoreaddons`→`org.kde.coreaddons`,
`plasmoid.setAction()`→`Plasmoid.contextualActions` + `PlasmaCore.Action`,
`plasmoid.file()`→`Qt.resolvedUrl()`, `Item {` root→`PlasmoidItem {`, versionless imports,
and Qt 6's explicit signal handler parameters (`onClicked: (mouse) => {}`,
`Connections { function onFooChanged() {} }`).

Two deliberate deviations from `kpac`'s automated rules:

1. `units.devicePixelRatio` was **not** mapped to `Screen.devicePixelRatio`. That factor was
   a font-derived fudge in Plasma 5; Qt 6 already scales logical pixels, so multiplying by
   the real DPR would double-scale on HiDPI. The hardcoded sizes in `AppletConfig.qml` are
   expressed in `Kirigami.Units` instead.
2. `SinkModel.defaultSink` / `SourceModel.defaultSource` no longer exist in PulseAudioQt.
   The default devices moved to the `Server` singleton
   (`PulseAudioQt::Context::instance()->server()`), which plasma-pa registers for QML as
   `PlasmaVolume.Server`. All call sites now use `PlasmaVolume.Server.defaultSink` /
   `.defaultSource`. (`Device.default` is unchanged and still used for "make default".)
3. `DynamicFilterModel.get(row)` returns the `PulseObject` directly, because
   `KSortFilterProxyModel` has no `get()`. Call sites that used `model.get(i).PulseObject`
   and the card role names (`card.Index`, `card.ActiveProfileIndex`, `card.Profiles`) now
   use the lowercase `Card` properties.

## Still to do

* Translations are built: `contents/locale/{fr,nl}/LC_MESSAGES/*.mo` ship in the package.
  60 strings translated per language, 5 new ones (added by this port) still English.
  Re-run `python3 ./kpac i18n` after changing any `i18n()` call; needs `gettext`.
* `showVolumeTickmarks` and the volume-boost spinbox are still non-functional placeholders,
  as they were in v26.
* Orphaned-module cleanup: the widget's context menu can unload loopback / echo-cancel
  modules bound to a source index that is no longer present (indices are reassigned when a
  device is replugged or the server restarts, stranding modules with no UI to toggle).
* Runtime testing on a real Plasma 6 session — in particular the rotated slider groove
  geometry, drag-and-drop between streams and devices, and the submenu (Profile) teardown.

## Dependencies

`plasma-pa` (org.kde.plasma.private.volume), `plasma-workspace` (org.kde.plasma.private.mpris),
`plasma5support`, `kdeclarative` (org.kde.draganddrop), `kitemmodels`, `ksvg`, `kirigami`,
`kcoreaddons`, and `dbus-send` for the OSD.
