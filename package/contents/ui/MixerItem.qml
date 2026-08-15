import QtQuick
import QtQuick.Layouts

import org.kde.draganddrop as DragDrop
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import org.kde.plasma.private.volume as PlasmaVolume

import "lib"
import "./code/Icon.js" as Icon
import "./code/PulseObjectCommands.js" as PulseObjectCommands

// Was PlasmaComponents2.ListItem, which no longer exists. PlasmaExtras.ListItem
// is a Control (it would eat clicks meant for the sliders), so the listitem
// frame is drawn manually instead.
Item {
	id: mixerItem
	width: mixerItemWidth + (showChannels ? numChannels * (channelSliderWidth + volumeSliderRow.spacing) : 0) + background.margins.left + background.margins.right

	property bool checked: dropArea.containsDrag
	opacity: !main.draggedStream || dropArea.canBeDroppedOn ? 1 : 0.4

	property string mixerItemType: ''
	property int mixerItemWidth: 100
	property int volumeSliderWidth: 50
	property int channelSliderWidth: volumeSliderWidth
	property bool isVolumeBoosted: false
	readonly property bool hasChannels: typeof PulseObject.channels !== 'undefined'
	readonly property int numChannels: hasChannels ? PulseObject.channels.length : 0
	property bool showChannels: false
	// main.moduleRevision is referenced so these re-evaluate when a module is
	// loaded or unloaded -- the id registry lives in a plain JS object that QML
	// cannot observe on its own.
	readonly property bool hasModuleLoopback: {
		main.moduleRevision
		return PulseObjectCommands.hasLoopbackModuleId(PulseObject)
	}
	readonly property bool hasModuleEchoCancel: {
		main.moduleRevision
		return PulseObjectCommands.hasEchoCancelModuleId(PulseObject)
	}

	property bool ignoreValueChanges: false
	function shouldIgnoreVolumeChanges() {
		return slider.ignoreValueChanges || channelRepeater.hasChannelIgnoreValueChanges()
	}

	// Scroll anywhere over this column -- icon, label, mute button, empty space
	// -- to adjust the stream. The sliders have their own WheelHandler; a
	// handler on the inner item sees the event first and accepts it, so the two
	// don't both fire.
	WheelHandler {
		id: itemWheelHandler
		orientation: Qt.Vertical | Qt.Horizontal
		acceptedButtons: Qt.NoButton
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		property int wheelDelta: 0
		onWheel: (wheel) => {
			const delta = (wheel.inverted ? -1 : 1)
				* (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x)
			if ((wheelDelta > 0 && delta < 0) || (wheelDelta < 0 && delta > 0)) {
				wheelDelta = 0
			}
			wheelDelta += delta
			while (wheelDelta >= 120) {
				wheelDelta -= 120
				PulseObjectCommands.increaseVolume(PulseObject)
				mixerItem.playFeedback()
			}
			while (wheelDelta <= -120) {
				wheelDelta += 120
				PulseObjectCommands.decreaseVolume(PulseObject)
				mixerItem.playFeedback()
			}
		}
	}

	KSvg.FrameSvgItem {
		id: background
		anchors.fill: parent
		imagePath: "widgets/listitem"
		prefix: "pressed"
		visible: mixerItem.checked
	}

	Keys.onUpPressed: (event) => PulseObjectCommands.increaseVolume(PulseObject)
	Keys.onDownPressed: (event) => PulseObjectCommands.decreaseVolume(PulseObject)
	Keys.onPressed: (event) => {
		// AlsaMixer keybindings
		if (event.key === Qt.Key_M) { PulseObjectCommands.toggleMute(PulseObject)
		} else if (event.key === Qt.Key_0) { PulseObjectCommands.setPercent(PulseObject, 0)
		} else if (event.key === Qt.Key_1) { PulseObjectCommands.setPercent(PulseObject, 10)
		} else if (event.key === Qt.Key_2) { PulseObjectCommands.setPercent(PulseObject, 20)
		} else if (event.key === Qt.Key_3) { PulseObjectCommands.setPercent(PulseObject, 30)
		} else if (event.key === Qt.Key_4) { PulseObjectCommands.setPercent(PulseObject, 40)
		} else if (event.key === Qt.Key_5) { PulseObjectCommands.setPercent(PulseObject, 50)
		} else if (event.key === Qt.Key_6) { PulseObjectCommands.setPercent(PulseObject, 60)
		} else if (event.key === Qt.Key_7) { PulseObjectCommands.setPercent(PulseObject, 70)
		} else if (event.key === Qt.Key_8) { PulseObjectCommands.setPercent(PulseObject, 80)
		} else if (event.key === Qt.Key_9) { PulseObjectCommands.setPercent(PulseObject, 90)
		} else if (event.key === Qt.Key_Return) { makeDeviceDefault()
		} else if (event.key === Qt.Key_Menu) { contextMenu.showBelow(iconLabelButton)
		} else { return // don't accept the key press
		}
		event.accepted = true
	}

	function makeDeviceDefault() {
		if (typeof PulseObject.default !== "undefined") {
			PulseObject.default = true
			if (plasmoid.configuration.moveAllAppsOnSetDefault) {
				for (var i = 0; i < appsModel.count; i++) {
					var stream = appsModel.get(i)
					if (stream) {
						stream.deviceIndex = PulseObject.index
					}
				}
			}
			if (plasmoid.configuration.closeOnSetDefault) {
				main.closeDialog(false)
			}
		}
	}

	function playFeedback() {
		if (mixerItemType === 'Sink') {
			main.playFeedback(PulseObject.index)
		}
	}

	function setActivePort(portIndex) {
		PulseObject.activePortIndex = portIndex
	}

	function getCard() {
		// NOTE: the filter model's get() now returns the PulseObject itself,
		// so the old card.Index / card.ActiveProfileIndex role names became the
		// lowercase Card properties.
		for (var i = 0; i < filteredCardModel.count; i++) {
			var card = filteredCardModel.get(i)
			if (card && PulseObject.cardIndex === card.index) {
				return card
			}
		}
		return null
	}

	function setCardProfile(profileIndex) {
		var card = getCard()
		if (card) {
			card.activeProfileIndex = profileIndex
		}
	}

	function startsWith(a, b) {
		return a.indexOf(b) === 0
	}

	function endsWith(a, b) {
		return a.lastIndexOf(b) === a.length - b.length
	}

	readonly property var invalidPortIndex: 4294967295

	// Names to try, in order, for this stream's icon. Apps are inconsistent
	// about what they advertise: some set application.icon_name, some only a
	// binary name, and some (Helium, other Chromium forks) ship their icon under
	// their reverse-DNS desktop id. IconLabelButton walks the list.
	readonly property var iconCandidates: {
		if (mixerItemType === 'SinkInput' || mixerItemType === 'SourceOutput') {
			var client = PulseObject.client
			// Virtual streams have no client object.
			if (!client) {
				return ['audio-card']
			}
			var props = client.properties
			var list = []
			function push(name) {
				if (name && list.indexOf(name) === -1) {
					list.push(name)
				}
			}

			// Strip a " (deleted)" suffix, left when a running app's binary was
			// replaced by an update.
			function clean(v) {
				return v ? ('' + v).replace(/ \(deleted\)$/, '').toLowerCase() : ''
			}

			// PulseObject.iconName is PulseAudioQt's own resolution: it walks
			// device/media/window/application icon_name, binary, name and the
			// portal app id, and -- crucially -- returns only names that
			// QIcon::hasThemeIcon() confirms exist. This is what plasma-pa uses.
			push(clean(PulseObject.iconName))

			push(clean(props['application.icon_name']))

			var appId = clean(props['application.id'])
			push(appId)
			// "net.imput.helium" also commonly installs its icon as "helium"
			if (appId.indexOf('.') >= 0) {
				push(appId.substring(appId.lastIndexOf('.') + 1))
			}

			var binary = clean(props['application.process.binary'])
			if (binary === 'chrome' || binary === 'chromium') {
				push('google-chrome')
			}
			push(binary)
			var appName = clean(props['application.name'])
			push(appName)

			// Finally, the Icon= from a matching .desktop file. Catches apps
			// like Helium whose desktop entry says `Icon=helium-browser` while
			// pulse only reports something like "helium".
			desktopIcons.revision // re-evaluate once the scan finishes
			push(desktopIcons.lookup([
				props['application.process.desktop_id'],
				appId,
				binary,
				appName,
				clean(props['application.process.binary']),
			]))

			// Match plasma-pa's generic stream icon rather than a "binary file"
			// glyph when nothing resolves.
			push('audio-card')
			return list
		}

		return [mixerItem.deviceIcon]
	}

	// Devices resolve to exactly one name, so keep that logic separate.
	property string deviceIcon: {
		if (mixerItemType === 'Sink') {
			// Speaker
			if (PulseObject.properties['device.form_factor'] === 'headset') {
				// While device.icon_name is 'audio-headset-usb', that icon is
				// not in the Breeze icon theme.
				return 'audio-headphones'
			}
			if (PulseObject.activePortIndex !== invalidPortIndex) { // not "Invalid Port" (eg: echo-cancel)
				var portName = PulseObject.ports[PulseObject.activePortIndex].name
				if (portName.indexOf('headphones') >= 0) { // Eg: analog-output-headphones
					return 'audio-headphones'
				}
			}
			if (startsWith(PulseObject.name, 'alsa_output.') && PulseObject.name.indexOf('.hdmi-') >= 0) {
				return 'video-television'
			}
			if (PulseObject.name.indexOf('bluez_sink.') === 0) {
				return 'preferences-system-bluetooth'
			}
			return 'audio-speakers-symbolic'
		} else if (mixerItemType === 'Source' || mixerItemType === 'SourceOutput') {
			return 'audio-input-microphone'
		} else {
			return 'audio-card'
		}
	}

	// Single best guess, used for the tooltip and elsewhere.
	readonly property string icon: iconCandidates.length > 0 ? iconCandidates[0] : 'audio-card'

	function labelForObject(obj) {
		var name = obj.name
		if (obj.properties['device.class'] === 'filter') {
			if (endsWith(name, '.echo-cancel')) { // Same for input and ouput stream
				// pactl load-module module-echo-cancel
				var inputName = obj.properties['device.master_device']
				return i18n("%1 (Echo Cancelled)", inputName)
			}
		}

		// obj.properties['device.class'] === 'sound'
		if (startsWith(name, 'alsa_input.')) {
			if (name.indexOf('.analog-') >= 0) {
				return i18n("Mic")
			}
		} else if (name.indexOf('alsa_output.') === 0) {
			if (obj.properties['device.form_factor'] === 'headset') {
				return i18n("Headset")
			} else if (name.indexOf('.analog-') >= 0) {
				return i18n("Speaker")
			} else if (name.indexOf('.hdmi-') >= 0) {
				return i18n("HDMI")
			}
		}

		var appName = obj.properties['application.name']
		if (appName) {
			return appName
		}

		if (obj.description) {
			return obj.description
		}

		return name
	}

	// The model backing this item, so sibling streams/devices in the same
	// group can be looked up.
	function siblingModel() {
		if (mixerItemType === 'Source') {
			return filteredSourceModel
		} else if (mixerItemType === 'Sink') {
			return filteredSinkModel
		} else if (mixerItemType === 'SinkInput') {
			return appsModel
		} else if (mixerItemType === 'SourceOutput') {
			return appOutputsModel
		}
		return null
	}

	function anotherItemHasLabel(model, labelText) {
		// Read model.count so the `label` binding it is called from depends
		// on the count property: QML can't track the rows a binding reads
		// through model.get(), so a row added or removed otherwise wouldn't
		// re-evaluate siblings' labels.
		var count = model.count
		for (var i = 0; i < count; i++) {
			var obj = model.get(i)
			if (obj && obj.index !== PulseObject.index && labelForObject(obj) === labelText) {
				return true
			}
		}
		return false
	}

	property string label: {
		var base = labelForObject(PulseObject)
		// Two items in the same group would otherwise show the same label
		// (e.g. two "Mic" sources), so fall back to the description -- or
		// the raw name -- to tell this one apart.
		var model = siblingModel()
		if (model && anotherItemHasLabel(model, base)) {
			if (PulseObject.description && PulseObject.description !== base) {
				return PulseObject.description
			}
			return PulseObject.name
		}
		return base
	}

	property bool showDefaultDeviceIndicator: false
	readonly property bool isDevice: mixerItemType === 'Sink' || mixerItemType === 'Source'
	readonly property bool isDefaultDevice: {
		if (typeof PulseObject.default === 'boolean') {
			return PulseObject.default
		} else {
			return false
		}
	}
	property bool usingDefaultDevice: {
		if (typeof PulseObject.deviceIndex !== 'undefined') {
			if (mixerItemType === 'SinkInput') {
				// `a && b` yields null (not false) when a is null, which QML
				// refuses to assign to a bool property.
				return !!(PlasmaVolume.Server.defaultSink && PulseObject.deviceIndex === PlasmaVolume.Server.defaultSink.index)
			} else if (mixerItemType === 'SourceOutput') {
				return !!(PlasmaVolume.Server.defaultSource && PulseObject.deviceIndex === PlasmaVolume.Server.defaultSource.index)
			} else {
				return false
			}
		} else {
			return true // Just pretend it's linked to the default so we don't show that it's not.
		}
	}

	property string tooltipSubText: {
		// maximum of 8 visible lines. Extra lines are cut off.
		var lines = []
		function addLine(key, value) {
			if (typeof value === 'undefined') return
			if (typeof value === 'string' && value.length === 0) return
			lines.push('<b>' + key + ':</b> ' + value)
		}
		addLine(i18n("Name"), PulseObject.name)
		addLine(i18n("Description"), PulseObject.description)
		addLine(i18n("Volume"), Math.round(PulseObjectCommands.volumePercent(PulseObject.volume)) + "%")
		if (typeof PulseObject.activePortIndex !== 'undefined' && PulseObject.activePortIndex !== invalidPortIndex) {
			addLine(i18n("Port"), '[' + PulseObject.activePortIndex +'] ' + PulseObject.ports[PulseObject.activePortIndex].description)
		}
		if (typeof PulseObject.deviceIndex !== 'undefined') {
			if (!usingDefaultDevice) {
				addLine(i18n("Device"), '[' + PulseObject.deviceIndex + '] ')
			}
		}
		function addPropertyLine(key) {
			addLine(key, PulseObject.properties[key])
		}
		addPropertyLine('alsa.mixer_name')
		addPropertyLine('application.process.binary')
		addPropertyLine('application.process.id')
		addPropertyLine('application.process.user')

		return lines.join('<br>')
	}

	DragDrop.DropArea {
		id: dropArea
		anchors.fill: parent
		property bool canBeDroppedOn: {
			if (main.draggedStream) {
				if (main.draggedStreamType === 'SinkInput') {
					return mixerItemType === 'Sink'
				} else if (main.draggedStreamType === 'Source') {
					return mixerItemType === 'SourceOutput'
				}
			}
			return false
		}

		enabled: canBeDroppedOn
		onDrop: (event) => {
			if (main.draggedStreamType === 'SinkInput') {
				main.draggedStream.deviceIndex = PulseObject.index
			} else if (main.draggedStreamType === 'Source') {
				PulseObject.deviceIndex = main.draggedStream.index
			}
		}
	}

	Row {
		id: volumeSliderRow
		height: parent.height
		width: parent.width
		spacing: Kirigami.Units.smallSpacing * 2

		ColumnLayout {
			width: mixerItem.mixerItemWidth
			height: parent.height

			PlasmaCore.ToolTipArea {
				id: tooltip
				Layout.fillWidth: true
				Layout.preferredHeight: iconLabelButton.height
				mainText: mixerItem.label
				subText: mixerItem.tooltipSubText
				icon: mixerItem.icon

				DragDrop.DragArea {
					id: dragArea
					anchors.fill: parent
					delegate: iconLabelButton
					enabled: mixerItemType === 'SinkInput' || mixerItemType === 'Source'

					mimeData {
						source: mixerItem
					}

					onDragStarted: {
						main.startDrag(PulseObject, mixerItemType)
					}
					onDrop: (event) => {
						main.clearDrag()
					}

					IconLabelButton {
						id: iconLabelButton
						width: parent.width
						iconCandidates: mixerItem.iconCandidates
						iconItemOverlays: {
							if (mixerItem.usingDefaultDevice) {
								return []
							} else {
								return ['emblem-unlocked']
							}
						}
						iconItemHeight: mixerItem.volumeSliderWidth
						labelText: mixerItem.label
						iconFallback: 'audio-card'

						onClicked: {
							if (mixerItem.isDevice && plasmoid.configuration.setDefaultOnClickIcon) {
								mixerItem.makeDeviceDefault()
							} else {
								contextMenu.showBelow(iconLabelButton)
							}
						}

						PlasmaComponents.RadioButton {
							id: defaultDeviceRadioButton
							visible: mixerItem.showDefaultDeviceIndicator
							anchors.left: parent.left
							anchors.top: parent.top
							anchors.margins: Kirigami.Units.smallSpacing
							checked: mixerItem.isDefaultDevice
							onClicked: {
								mixerItem.makeDeviceDefault()
								checked = Qt.binding(function(){ return mixerItem.isDefaultDevice })
							}

							PlasmaComponents.ToolTip {
								visible: defaultDeviceRadioButton.hovered
								text: {
									if (defaultDeviceRadioButton.checked) {
										return i18n("Is default device")
									} else {
										return i18n("Make default device")
									}
								}
								delay: 0
							}
						}
					}
				}
			}

			Item {
				Layout.fillWidth: true
				Layout.fillHeight: true

				VerticalVolumeSlider {
					id: slider
					height: parent.height
					width: mixerItem.volumeSliderWidth
					anchors.horizontalCenter: parent.horizontalCenter

					// Helper properties to allow async slider updates.
					// While we are sliding we must not react to value updates
					// as otherwise we can easily end up in a loop where value
					// changes trigger volume changes trigger value changes.
					readonly property int volume: PulseObject.volume

					property bool ready: false
					property bool ignoreValueChanges: false

					volumeObject: PulseObject

					from: 0
					// FIXME: I do wonder if exposing max through the model would be useful at all
					to: mixerItem.isVolumeBoosted ? 98304 : 65536
					// `hasVolume` only exists on PulseAudioQt's Stream (sink-inputs /
					// source-outputs), NOT on Device (sinks / sources), where it reads
					// undefined -- so only an explicit false should hide the slider.
					visible: !!PulseObject && PulseObject.hasVolume !== false
					enabled: typeof PulseObject.volumeWritable === 'undefined' || PulseObject.volumeWritable

					opacity: {
						return enabled && PulseObject.muted ? 0.5 : 1
					}

					onWheelUp: {
						PulseObjectCommands.increaseVolume(PulseObject)
						mixerItem.playFeedback()
					}
					onWheelDown: {
						PulseObjectCommands.decreaseVolume(PulseObject)
						mixerItem.playFeedback()
					}

					onVolumeChanged: {
						var oldIgnoreValueChanges = slider.ignoreValueChanges
						slider.ignoreValueChanges = true
						mixerItem.ignoreValueChanges = mixerItem.shouldIgnoreVolumeChanges()
						if (!mixerItem.isVolumeBoosted && PulseObject.volume > 66000) {
							mixerItem.isVolumeBoosted = true
						}
						value = PulseObject.volume
						slider.ignoreValueChanges = oldIgnoreValueChanges
						mixerItem.ignoreValueChanges = mixerItem.shouldIgnoreVolumeChanges()
					}

					onValueChanged: {
						if (slider.ready && !mixerItem.ignoreValueChanges) {
							PulseObjectCommands.setVolume(PulseObject, value)

							if (!pressed) {
								updateTimer.restart()
							}
						}
					}

					property bool playFeedbackOnUpdate: false
					onPressedChanged: {
						if (pressed) {
							playFeedbackOnUpdate = true
						} else {
							// Make sure to sync the volume once the button was
							// released. Otherwise it might be that the slider is
							// at v10 whereas PA rejected the volume change and is
							// still at v15 (e.g.).
							updateTimer.restart()
						}
					}

					Timer {
						id: updateTimer
						interval: 200
						onTriggered: {
							slider.value = PulseObject.volume

							// Done dragging, play feedback
							if (slider.playFeedbackOnUpdate) {
								mixerItem.playFeedback()
							}

							if (!slider.pressed) {
								slider.playFeedbackOnUpdate = false
							}
						}
					}

					Component.onCompleted: {
						slider.value = PulseObject.volume
						slider.ready = true
						// 100% is 65863.68, not 65536... Bleh. Just trigger at a round number.
						mixerItem.isVolumeBoosted = PulseObject.volume > 66000
					}
				}
			}

			PlasmaComponents.ToolButton {
				id: muteButton
				Layout.maximumWidth: mixerItem.volumeSliderWidth
				Layout.maximumHeight: mixerItem.volumeSliderWidth
				Layout.minimumWidth: Layout.maximumWidth
				Layout.minimumHeight: Layout.maximumHeight
				Layout.alignment: Qt.AlignHCenter
				flat: true
				display: PlasmaComponents.AbstractButton.IconOnly

				Kirigami.Icon {
					anchors.fill: parent
					readonly property bool isMic: mixerItemType === 'Source' || mixerItemType === 'SourceOutput'
					readonly property string prefix: isMic ? 'microphone-sensitivity' : 'audio-volume'
					source: Icon.name(PulseObject.volume, PulseObject.muted, prefix)
					active: muteButton.hovered
				}

				onClicked: {
					PulseObject.muted = !PulseObject.muted
				}
			}
		}

		Repeater {
			id: channelRepeater
			model: showChannels && hasChannels ? PulseObject.channels : 0

			function hasChannelIgnoreValueChanges() {
				for (var i = 0; i < count; i++) {
					var item = itemAt(i)
					if (item && item.ignoreValueChanges) {
						return true
					}
				}
				return false
			}

			ColumnLayout {
				id: channelColumn
				width: mixerItem.channelSliderWidth
				height: parent.height

				required property int index

				property bool ignoreValueChanges: false

				PlasmaCore.ToolTipArea {
					Layout.fillWidth: true
					Layout.preferredHeight: channelIconLabelButton.height

					IconLabelButton {
						id: channelIconLabelButton
						anchors.fill: parent
						iconItemHeight: mixerItem.volumeSliderWidth
						labelText: PulseObject.channels[channelColumn.index]
					}
				} // ToolTipArea

				Item {
					Layout.fillWidth: true
					Layout.fillHeight: true

					VerticalVolumeSlider {
						id: channelSlider
						width: mixerItem.channelSliderWidth
						height: parent.height

						showVisualFeedback: false

						// Helper properties to allow async slider updates.
						readonly property int volume: PulseObject.channelVolumes[channelColumn.index]

						property bool ready: false
						readonly property bool isChannelBoosted: volume > 66000

						from: 0
						// FIXME: I do wonder if exposing max through the model would be useful at all
						to: mixerItem.isVolumeBoosted || isChannelBoosted ? 98304 : 65536

						onWheelUp: {
							PulseObjectCommands.increaseChannelVolume(PulseObject, channelColumn.index)
							mixerItem.playFeedback()
						}
						onWheelDown: {
							PulseObjectCommands.decreaseChannelVolume(PulseObject, channelColumn.index)
							mixerItem.playFeedback()
						}

						onVolumeChanged: {
							var oldIgnoreValueChanges = channelColumn.ignoreValueChanges
							channelColumn.ignoreValueChanges = true
							mixerItem.ignoreValueChanges = mixerItem.shouldIgnoreVolumeChanges()
							value = volume
							channelColumn.ignoreValueChanges = oldIgnoreValueChanges
							mixerItem.ignoreValueChanges = mixerItem.shouldIgnoreVolumeChanges()
						}

						onValueChanged: {
							if (channelSlider.ready && !mixerItem.ignoreValueChanges) {
								PulseObject.setChannelVolume(channelColumn.index, Math.floor(value))

								if (!pressed) {
									channelUpdateTimer.restart()
								}
							}
						}

						function playFeedback() {
							mixerItem.playFeedback()
						}

						property bool playFeedbackOnUpdate: false
						onPressedChanged: {
							if (pressed) {
								playFeedbackOnUpdate = true
							} else {
								channelUpdateTimer.restart()
							}
						}

						Timer {
							id: channelUpdateTimer
							interval: 200
							onTriggered: {
								channelSlider.value = channelSlider.volume

								// Done dragging, play feedback
								if (channelSlider.playFeedbackOnUpdate) {
									channelSlider.playFeedback()
								}

								if (!channelSlider.pressed) {
									channelSlider.playFeedbackOnUpdate = false
								}
							}
						}

						Component.onCompleted: {
							channelSlider.value = channelSlider.volume
							channelSlider.ready = true
						}
					}
				}

				Item {
					Layout.fillWidth: true
					Layout.preferredHeight: muteButton.height
				}
			}
		}
	}

	// https://invent.kde.org/plasma/libplasma/-/tree/master/src/declarativeimports/plasmaextracomponents/qmenu.cpp
	ContextMenu {
		id: contextMenu

		onBeforeOpen: (menu) => {
			// Mute
			var menuItem = newMenuItem()
			menuItem.text = i18ndc("plasma_applet_org.kde.plasma.volume", "Checkable switch for (un-)muting sound output.", "Mute")
			menuItem.checkable = true
			menuItem.checked = PulseObject.muted
			menuItem.clicked.connect(function() {
				PulseObject.muted = !PulseObject.muted
			})
			contextMenu.addMenuItem(menuItem)

			// Volume Boost
			menuItem = newMenuItem()
			menuItem.text = i18n("Volume Boost (150% Volume)")
			menuItem.checkable = true
			menuItem.checked = mixerItem.isVolumeBoosted
			menuItem.clicked.connect(function() {
				mixerItem.isVolumeBoosted = !mixerItem.isVolumeBoosted
			})
			contextMenu.addMenuItem(menuItem)

			// Default
			if (typeof PulseObject.default === "boolean") {
				menuItem = newMenuItem()
				menuItem.text = i18ndc("plasma_applet_org.kde.plasma.volume", "Checkable switch to change the current default output.", "Default")
				menuItem.checkable = true
				menuItem.checked = PulseObject.default
				menuItem.clicked.connect(function() {
					mixerItem.makeDeviceDefault()
				})
				contextMenu.addMenuItem(menuItem)
			}

			// Channels
			if (mixerItem.hasChannels) {
				menuItem = newMenuItem()
				menuItem.text = i18n("Show Channels")
				menuItem.checkable = true
				menuItem.checked = mixerItem.showChannels
				menuItem.clicked.connect(function() {
					mixerItem.showChannels = !mixerItem.showChannels
				})
				contextMenu.addMenuItem(menuItem)
			}

			// Ports
			if (PulseObject.ports && PulseObject.ports.length > 1) {
				var sectionItem = newMenuItem()
				sectionItem.text = i18ndc("plasma_applet_org.kde.plasma.volume", "Heading for a list of ports of a device (for example built-in laptop speakers or a plug for headphones)", "Ports")
				sectionItem.section = true
				contextMenu.addMenuItem(sectionItem)

				for (var i = 0; i < PulseObject.ports.length; i++) {
					var port = PulseObject.ports[i]
					menuItem = newMenuItem()
					if (typeof PlasmaVolume.Port !== "undefined" && port.availability === PlasmaVolume.Port.Unavailable) {
						if (port.name === "analog-output-speaker" || port.name === "analog-input-microphone-internal") {
							menuItem.text = i18ndc("plasma_applet_org.kde.plasma.volume", "Port is unavailable", "%1 (unavailable)", port.description)
						} else {
							menuItem.text = i18ndc("plasma_applet_org.kde.plasma.volume", "Port is unplugged", "%1 (unplugged)", port.description)
						}
					} else {
						menuItem.text = port.description
					}
					menuItem.checkable = true
					menuItem.checked = i === PulseObject.activePortIndex
					menuItem.clicked.connect(mixerItem.setActivePort.bind(null, i))
					contextMenu.addMenuItem(menuItem)
				}
			}

			// Profiles
			if (typeof PulseObject.cardIndex === "number") {
				contextMenu.addMenuItem(newSeperator())
				var card = mixerItem.getCard()
				if (card) {
					var subMenu = newSubMenu()
					subMenu.text = i18n("Profile")
					contextMenu.addMenuItem(subMenu)

					var availableProfiles = card.profiles
					for (var j = 0; j < availableProfiles.length; j++) {
						var profile = availableProfiles[j]
						var profileItem = subMenu.newMenuItem()
						profileItem.text = profile.description
						profileItem.checkable = true
						profileItem.checked = card.activeProfileIndex === j
						profileItem.clicked.connect(mixerItem.setCardProfile.bind(null, j))

						subMenu.addMenuItem(profileItem)
					}
				}
			}

			// Modules: Source
			if (mixerItemType === 'Source') {
				contextMenu.addMenuItem(newSeperator())

				// module-echo-cancel
				menuItem = newMenuItem()
				menuItem.text = i18n("Echo Cancellation")
				menuItem.enabled = !PulseObjectCommands.hasIdProperty(PulseObject, 'echo_cancel.source')
				menuItem.checkable = true
				menuItem.checked = mixerItem.hasModuleEchoCancel
				menuItem.clicked.connect(function() {
					PulseObjectCommands.toggleModuleEchoCancel(PulseObject)
				})
				contextMenu.addMenuItem(menuItem)

				// module-loopback
				menuItem = newMenuItem()
				menuItem.text = i18n("Listen to Device")
				menuItem.enabled = !mixerItem.hasModuleEchoCancel && !PulseObjectCommands.hasIdProperty(PulseObject, 'loopback.source')
				menuItem.checkable = true
				menuItem.checked = mixerItem.hasModuleLoopback
				menuItem.clicked.connect(function() {
					PulseObjectCommands.toggleModuleLoopback(PulseObject)
				})
				contextMenu.addMenuItem(menuItem)
			}

			// Properties
			contextMenu.addMenuItem(newSeperator())
			menuItem = newMenuItem()
			menuItem.text = i18n("Properties")
			menuItem.clicked.connect(function() {
				mixerItem.showPropertiesDialog()
				main.closeDialog(false)
			})
			contextMenu.addMenuItem(menuItem)
		}
	}

	MouseArea {
		acceptedButtons: Qt.RightButton
		anchors.fill: parent

		onClicked: (mouse) => contextMenu.show(mouse.x, mouse.y)
	}

	Component {
		id: propertiesDialogComponent
		PulseObjectDialog {}
	}

	function showPropertiesDialog() {
		var dialog = propertiesDialogComponent.createObject(mixerItem, {
			pulseObject: PulseObject,
		})
		dialog.visible = true
	}
}
