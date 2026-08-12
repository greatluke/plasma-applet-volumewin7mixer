/*
	Copyright 2014-2015 Harald Sitter <sitter@kde.org>

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License as
	published by the Free Software Foundation; either version 2 of
	the License or (at your option) version 3 or any later version
	accepted by the membership of KDE e.V. (or its successor approved
	by the membership of KDE e.V.), which shall act as a proxy
	defined in Section 14 of version 3 of the license.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

import org.kde.plasma.private.volume as PlasmaVolume

import "./code/Utils.js" as Utils
import "./code/PulseObjectCommands.js" as PulseObjectCommands
import "lib"

PlasmoidItem {
	id: main

	AppletConfig { id: config }

	property string draggedStreamType: ''
	property QtObject draggedStream: null
	function startDrag(pulseObject, type) {
		draggedStreamType = type
		draggedStream = pulseObject
	}
	function clearDrag() {
		draggedStream = null
		draggedStreamType = ''
	}

	// NOTE: Plasma 5's SinkModel.defaultSink / SourceModel.defaultSource were
	// removed from PulseAudioQt. The default devices now live on the Server
	// singleton (PulseAudioQt::Context::instance()->server()), exposed to QML
	// by plasma-pa as PlasmaVolume.Server.
	property string displayName: i18nd("plasma_applet_org.kde.plasma.volume", "Audio Volume")
	property string speakerIcon: Utils.iconNameForStream(PlasmaVolume.Server.defaultSink)

	onCompactItemClicked: (mouse) => {
		if (mouse.button === Qt.LeftButton) {
			main.toggleDialog(false)
		} else if (mouse.button === Qt.MiddleButton) {
			toggleDefaultSinksMute()
		}
	}

	Plasmoid.icon: {
		if (mpris2Source.hasPlayer && mpris2Source.albumArt) {
			return mpris2Source.albumArt
		} else {
			return speakerIcon
		}
	}
	toolTipMainText: {
		if (mpris2Source.hasPlayer && mpris2Source.track) {
			return mpris2Source.track
		} else {
			return displayName
		}
	}
	toolTipSubText: {
		var lines = []
		if (mpris2Source.hasPlayer && mpris2Source.artist) {
			if (mpris2Source.isPaused) {
				lines.push(mpris2Source.artist ? i18ndc("plasma_applet_org.kde.plasma.mediacontroller", "Artist of the song", "by %1 (paused)", mpris2Source.artist) : i18nd("plasma_applet_org.kde.plasma.mediacontroller", "Paused"))
			} else if (mpris2Source.artist) {
				lines.push(i18ndc("plasma_applet_org.kde.plasma.mediacontroller", "Artist of the song", "by %1", mpris2Source.artist))
			}
		}
		if (PlasmaVolume.Server.defaultSink) {
			var sinkVolumePercent = Math.round(PulseObjectCommands.volumePercent(PlasmaVolume.Server.defaultSink.volume))
			lines.push(i18nd("plasma_applet_org.kde.plasma.volume", "Volume at %1%", sinkVolumePercent))
			lines.push(PlasmaVolume.Server.defaultSink.description)
		}
		return lines.join('\n')
	}

	property bool showMediaController: Plasmoid.configuration.showMediaController
	property string mediaControllerLocation: Plasmoid.configuration.mediaControllerLocation || 'bottom'
	property bool mediaControllerVisible: showMediaController && mpris2Source.hasPlayer

	fullRepresentation: Item {
		id: dialogContents

		readonly property int contentHeight: config.mixerGroupHeight + (main.mediaControllerVisible ? config.mediaControllerHeight : 0)

		implicitWidth: mixerItemRow.width
		implicitHeight: contentHeight

		Layout.minimumWidth: implicitWidth
		Layout.maximumWidth: implicitWidth
		Layout.preferredWidth: implicitWidth
		Layout.minimumHeight: implicitHeight
		Layout.preferredHeight: implicitHeight

		// Keyboard Navigation/Controls
		InputManager { id: inputManager }
		focus: true
		Keys.forwardTo: inputManager.hasSelection ? [inputManager.selectedMixerItem] : []
		Keys.onLeftPressed: (event) => inputManager.selectLeft()
		Keys.onRightPressed: (event) => inputManager.selectRight()
		Keys.onEscapePressed: (event) => main.closeDialog(true)
		function fireKeyOnDefault(keyName, event) {
			if (!inputManager.hasSelection) {
				inputManager.selectDefault()
				var fnName = 'on' + keyName + 'Pressed'
				// Manually trigger since it hasn't been forwarded yet.
				inputManager.selectedMixerItem.Keys[fnName](event)
			}
		}
		Keys.onUpPressed: (event) => fireKeyOnDefault('Up', event)
		Keys.onDownPressed: (event) => fireKeyOnDefault('Down', event)
		Keys.onPressed: (event) => fireKeyOnDefault('', event)

		MediaController {
			id: mediaController
			visible: main.mediaControllerVisible
			anchors.left: parent.left
			anchors.right: parent.right
			y: main.mediaControllerLocation === 'top' ? 0 : parent.height - height
			height: main.mediaControllerVisible ? config.mediaControllerHeight : 0
		}

		Row {
			id: mixerItemRow
			anchors.right: parent.right
			y: (main.mediaControllerVisible && main.mediaControllerLocation === 'top') ? config.mediaControllerHeight : 0
			width: childrenRect.width
			height: parent.height - (main.mediaControllerVisible ? config.mediaControllerHeight : 0)
			spacing: Kirigami.Units.smallSpacing * 2

			MixerItemGroup {
				id: sourceOutputMixerItemGroup
				height: parent.height
				title: i18n("Recording Apps")

				model: appOutputsModel
				mixerGroupType: 'SourceOutput'
			}

			MixerItemGroup {
				id: sinkInputMixerItemGroup
				height: parent.height
				title: i18n("Apps")

				model: appsModel
				mixerGroupType: 'SinkInput'
			}

			MixerItemGroup {
				id: sourceMixerItemGroup
				height: parent.height
				title: i18n("Mics")

				model: filteredSourceModel
				mixerGroupType: 'Source'
			}

			MixerItemGroup {
				id: sinkMixerItemGroup
				height: parent.height
				title: i18n("Speakers")

				model: filteredSinkModel
				mixerGroupType: 'Sink'
			}
		}

		PlasmaComponents.ToolButton {
			id: pinButton
			anchors.top: parent.top
			anchors.right: parent.right
			anchors.topMargin: (main.mediaControllerVisible && main.mediaControllerLocation === 'top') ? config.mediaControllerHeight : 0
			width: Math.round(Kirigami.Units.gridUnit * 1.25)
			height: width
			checkable: true
			checked: !main.hideOnWindowDeactivate
			icon.name: "window-pin"
			display: PlasmaComponents.AbstractButton.IconOnly
			onToggled: main.hideOnWindowDeactivate = !checked
		}
	}

	function increaseDefaultSinkVolume() {
		if (!PlasmaVolume.Server.defaultSink) {
			return
		}
		PlasmaVolume.Server.defaultSink.muted = false
		var volume = PulseObjectCommands.increaseVolume(PlasmaVolume.Server.defaultSink)
		showVolumeOsd(volume)
		playFeedback()
	}

	function decreaseDefaultSinkVolume() {
		if (!PlasmaVolume.Server.defaultSink) {
			return
		}
		PlasmaVolume.Server.defaultSink.muted = false
		var volume = PulseObjectCommands.decreaseVolume(PlasmaVolume.Server.defaultSink)
		showVolumeOsd(volume)
		playFeedback()
	}

	function toggleDefaultSinksMute() {
		if (!PlasmaVolume.Server.defaultSink) {
			return
		}
		var toMute = PulseObjectCommands.toggleMute(PlasmaVolume.Server.defaultSink)
		showVolumeOsd(toMute ? 0 : PlasmaVolume.Server.defaultSink.volume)
		playFeedback()
	}

	function increaseDefaultSourceVolume() {
		if (!PlasmaVolume.Server.defaultSource) {
			return
		}
		PlasmaVolume.Server.defaultSource.muted = false
		var volume = PulseObjectCommands.increaseVolume(PlasmaVolume.Server.defaultSource)
		showMicOsd(volume)
	}

	function decreaseDefaultSourceVolume() {
		if (!PlasmaVolume.Server.defaultSource) {
			return
		}
		PlasmaVolume.Server.defaultSource.muted = false
		var volume = PulseObjectCommands.decreaseVolume(PlasmaVolume.Server.defaultSource)
		showMicOsd(volume)
	}

	function toggleDefaultSourceMute() {
		if (!PlasmaVolume.Server.defaultSource) {
			return
		}
		var toMute = PulseObjectCommands.toggleMute(PlasmaVolume.Server.defaultSource)
		showMicOsd(toMute ? 0 : PlasmaVolume.Server.defaultSource.volume)
	}

	//--- OSD
	// Plasma 6 removed PlasmaVolume.VolumeOSD. plasmashell exposes the OSD over
	// DBus instead, and kded6 (audioshortcuts) uses the same interface.
	// https://invent.kde.org/plasma/plasma-pa/-/blob/master/src/dbus/osdService.xml
	function osdCall(method, args) {
		var cmd = 'dbus-send --type=method_call'
		cmd += ' --dest=org.kde.plasmashell /org/kde/osdService'
		cmd += ' org.kde.osdService.' + method
		for (var i = 0; i < args.length; i++) {
			cmd += ' int32:' + args[i]
		}
		executable.exec(cmd)
	}

	function showVolumeOsd(volume) {
		if (!Plasmoid.configuration.showOsd) {
			return
		}
		var volPercent = Math.round(PulseObjectCommands.volumePercent(volume))
		var maxPercent = volPercent > 100 ? 150 : 100
		osdCall('volumeChanged', [volPercent, maxPercent])
	}

	function showMicOsd(volume) {
		if (!Plasmoid.configuration.showOsd) {
			return
		}
		var volPercent = Math.round(PulseObjectCommands.volumePercent(volume))
		osdCall('microphoneVolumeChanged', [volPercent])
	}

	ExecUtil {
		id: executable
	}

	// Bumped by PulseObjectCommands whenever a loopback / echo-cancel module is
	// loaded or unloaded. The registry there is a plain JS object, which QML
	// cannot observe, so bindings depend on this counter to re-evaluate.
	property int moduleRevision: 0

	// Maps app binaries / desktop ids to the Icon= declared in their .desktop
	// file, for apps whose PulseAudio properties don't match any themed icon.
	DesktopEntryIcons {
		id: desktopIcons
	}

	Component.onCompleted: {
		// Rebuild the module registry from what's actually loaded, so a
		// plasmashell restart doesn't orphan anything.
		PulseObjectCommands.syncModuleIds(executable)
		desktopIcons.refresh(executable)
	}

	PlasmaVolume.VolumeFeedback {
		id: feedback
	}

	function playFeedback(sinkIndex) {
		if (!Plasmoid.configuration.volumeChangeFeedback) {
			return
		}
		if (sinkIndex === undefined) {
			if (!PlasmaVolume.Server.defaultSink) {
				return
			}
			sinkIndex = PlasmaVolume.Server.defaultSink.index
		}
		feedback.play(sinkIndex)
	}

	Mpris2Source {
		id: mpris2Source
	}

	// https://invent.kde.org/plasma/plasma-pa/-/tree/master/src
	DynamicFilterModel {
		id: appsModel
		sourceModel: PlasmaVolume.SinkInputModel {}
	}
	DynamicFilterModel {
		id: appOutputsModel
		sourceModel: PlasmaVolume.SourceOutputModel {}
	}
	DynamicFilterModel {
		id: filteredSourceModel
		sourceModel: PlasmaVolume.SourceModel {
			id: sourceModel
		}
	}
	DynamicFilterModel {
		id: filteredSinkModel
		sourceModel: PlasmaVolume.SinkModel {
			id: sinkModel
		}
	}
	DynamicFilterModel {
		id: filteredCardModel
		sourceModel: PlasmaVolume.CardModel {
			id: cardModel
		}
	}

	// NOTE: DynamicFilterModel.get() returns the PulseObject directly now,
	// the old PlasmaCore.SortFilterModel returned a row you reached
	// `.PulseObject` through.
	function findStream(model, predicate) {
		for (var i = 0; i < model.count; i++) {
			var stream = model.get(i)
			if (stream && predicate(stream, i)) {
				return i
			}
		}
		return -1
	}
	function getStream(model, predicate) {
		for (var i = 0; i < model.count; i++) {
			var stream = model.get(i)
			if (stream && predicate(stream, i)) {
				return stream
			}
		}
		return null
	}

	// Plasma 5's plasmoid.setAction() was replaced with Plasmoid.contextualActions.
	// The "Configure..." entry is added automatically in Plasma 6.
	Plasmoid.contextualActions: [
		PlasmaCore.Action {
			text: i18n("PulseAudio Control")
			icon.name: "configure"
			onTriggered: executable.exec("pavucontrol")
		},
		PlasmaCore.Action {
			text: i18n("AlsaMixer")
			icon.name: "configure"
			onTriggered: executable.exec("konsole -e alsamixer")
		},
		PlasmaCore.Action {
			// A loopback / echo-cancel module is bound to a source *index*, and
			// indices are reassigned when a device is replugged or the audio
			// server restarts. A module can then be attached to an index no
			// longer in the mixer: nothing to right-click, but it still routes
			// audio. This unloads those.
			text: main.orphanedModuleCount > 0
				? i18np("Clean Up %1 Orphaned Audio Module", "Clean Up %1 Orphaned Audio Modules", main.orphanedModuleCount)
				: i18n("No Orphaned Audio Modules")
			icon.name: "edit-clear-all"
			enabled: main.orphanedModuleCount > 0
			onTriggered: main.cleanUpOrphanedModules()
		}
	]

	readonly property var sourceModelList: [filteredSourceModel, appOutputsModel]

	// Recomputed whenever the module registry changes (moduleRevision) or the
	// set of sources changes.
	readonly property int orphanedModuleCount: {
		moduleRevision
		filteredSourceModel.count
		appOutputsModel.count
		return PulseObjectCommands.orphanedModuleCount(main.sourceModelList)
	}

	function cleanUpOrphanedModules() {
		var n = PulseObjectCommands.unloadOrphanedModules(main.sourceModelList)
		console.log('cleanUpOrphanedModules: unloaded', n, 'module(s)')
	}


	//--- merged from the old DialogApplet.qml
	// PlasmoidItem MUST be the root object declared in main.qml itself:
	// AppletQuickItem::classBegin() requires its QQmlContext's parent to be
	// the AppletContext, so subclassing it in another .qml file leaves
	// Plasmoid/applet null.


	property string compactItemIcon: main.speakerIcon

	signal compactItemPressed(var mouse)
	signal compactItemClicked(var mouse)

	readonly property bool dialogVisible: main.expanded

	signal dialogOpened(bool usedKeyboard)
	signal dialogClosed(bool usedKeyboard)

	property bool usedKeyboardToToggle: false

	hideOnWindowDeactivate: true
	activationTogglesExpanded: true

	onExpandedChanged: {
		if (main.expanded) {
			main.dialogOpened(usedKeyboardToToggle)
		} else {
			main.dialogClosed(usedKeyboardToToggle)
		}
		usedKeyboardToToggle = false
	}

	function openDialog(usedKeyboard) {
		usedKeyboardToToggle = !!usedKeyboard
		main.expanded = true
	}
	function closeDialog(usedKeyboard) {
		usedKeyboardToToggle = !!usedKeyboard
		main.expanded = false
	}
	function toggleDialog(usedKeyboard) {
		if (main.expanded) {
			closeDialog(usedKeyboard)
		} else {
			openDialog(usedKeyboard)
		}
	}

	// Plasmoid.onActivated (global shortcut) is handled by activationTogglesExpanded,
	// but we want to know that the keyboard was used so the first stream gets selected.
	Connections {
		target: Plasmoid
		function onActivated() {
			main.usedKeyboardToToggle = true
		}
	}

	compactRepresentation: MouseArea {
		id: compactItem

		// The System Tray does not deliver wheel events to applets directly: it
		// searches the compact representation for a MouseArea and calls its
		// wheel() signal (systemtray/qml/PlasmoidItem.qml findMouseArea()).
		// The heuristic wants a MouseArea that covers the whole item, so fill
		// the parent explicitly rather than relying on implicit sizing.
		anchors.fill: parent

		readonly property bool inPanel: (Plasmoid.location === PlasmaCore.Types.TopEdge
			|| Plasmoid.location === PlasmaCore.Types.RightEdge
			|| Plasmoid.location === PlasmaCore.Types.BottomEdge
			|| Plasmoid.location === PlasmaCore.Types.LeftEdge)

		Layout.minimumWidth: {
			switch (Plasmoid.formFactor) {
			case PlasmaCore.Types.Vertical:
				return 0;
			case PlasmaCore.Types.Horizontal:
				return height;
			default:
				return Kirigami.Units.gridUnit * 3;
			}
		}

		Layout.minimumHeight: {
			switch (Plasmoid.formFactor) {
			case PlasmaCore.Types.Vertical:
				return width;
			case PlasmaCore.Types.Horizontal:
				return 0;
			default:
				return Kirigami.Units.gridUnit * 3;
			}
		}

		// units.iconSizeHints.panel is gone in Plasma 6; Kicker et al. hardcode 48.
		Layout.maximumWidth: inPanel ? 48 : -1
		Layout.maximumHeight: inPanel ? 48 : -1

		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton

		onPressed: (mouse) => main.compactItemPressed(mouse)
		onClicked: (mouse) => main.compactItemClicked(mouse)

		// Accumulate to 120 units ("one click") rather than acting on every
		// event: a touchpad or high-resolution wheel sends many small deltas,
		// which would otherwise slam the volume to 0 or 100 instantly.
		property int wheelDelta: 0
		onWheel: (wheel) => {
			const delta = (wheel.inverted ? -1 : 1)
				* (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x)
			// Reset on direction change so a leftover remainder doesn't carry.
			if ((wheelDelta > 0 && delta < 0) || (wheelDelta < 0 && delta > 0)) {
				wheelDelta = 0
			}
			wheelDelta += delta
			while (wheelDelta >= 120) {
				wheelDelta -= 120
				main.increaseDefaultSinkVolume()
			}
			while (wheelDelta <= -120) {
				wheelDelta += 120
				main.decreaseDefaultSinkVolume()
			}
		}

		KSvg.FrameSvgItem {
			id: expandedItem
			anchors.fill: parent
			imagePath: "widgets/tabbar"
			visible: fromCurrentImageSet && opacity > 0
			prefix: {
				var prefix;
				switch (Plasmoid.location) {
					case PlasmaCore.Types.LeftEdge:
						prefix = "west-active-tab";
						break;
					case PlasmaCore.Types.TopEdge:
						prefix = "north-active-tab";
						break;
					case PlasmaCore.Types.RightEdge:
						prefix = "east-active-tab";
						break;
					default:
						prefix = "south-active-tab";
					}
					if (!hasElementPrefix(prefix)) {
						prefix = "active-tab";
					}
					return prefix;
				}
			opacity: main.expanded ? 1 : 0
			Behavior on opacity {
				NumberAnimation {
					duration: Kirigami.Units.shortDuration
					easing.type: Easing.InOutQuad
				}
			}
		}

		Kirigami.Icon {
			anchors.fill: parent
			source: main.compactItemIcon
			active: compactItem.containsMouse
		}
	}

	// NOTE: Plasma 6 removed PlasmaVolume.GlobalActionCollection. The multimedia
	// keys (Volume Up/Down/Mute, Mic Mute...) are now owned by the kded6
	// "audioshortcuts" service which ships with plasma-pa, so the widget no
	// longer registers (or needs to register) them itself.
}
