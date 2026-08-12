import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

// QtQuick.Controls 1's TableView/TableViewColumn are gone in Qt 6, so this is a
// plain ListView with a two column delegate and section headers.
Window {
	id: pulseObjectDialog

	property var pulseObject

	width: Kirigami.Units.gridUnit * 34
	height: Kirigami.Units.gridUnit * 34
	title: (pulseObject ? pulseObject.name : '') + ' — ' + i18nd("plasma_applet_org.kde.plasma.volume", "Audio Volume")
	color: Kirigami.Theme.backgroundColor

	ListModel {
		id: propertyModel
	}

	QQC2.ScrollView {
		anchors.fill: parent

		ListView {
			id: listView
			model: propertyModel
			clip: true

			section.property: 'section'
			section.delegate: Kirigami.Heading {
				required property string section
				text: section
				level: 3
				width: ListView.view.width
			}

			delegate: RowLayout {
				id: row
				width: ListView.view.width
				required property string key
				required property string value

				QQC2.Label {
					text: row.key
					Layout.preferredWidth: Kirigami.Units.gridUnit * 11
					elide: Text.ElideRight
				}
				QQC2.Label {
					text: row.value
					Layout.fillWidth: true
					wrapMode: Text.Wrap
				}
			}
		}
	}

	function findEntry(section, key) {
		for (var i = 0; i < propertyModel.count; i++) {
			var item = propertyModel.get(i)
			if (item.section === section && item.key === key) {
				return i
			}
		}
		return -1
	}

	function addEntry(key, value, section) {
		propertyModel.append({
			key: '' + key,
			value: '' + value,
			section: ('' + section) || '',
		})
	}

	function setEntry(key, value, section) {
		// Scan for existing property
		var entryIndex = findEntry(section, key)
		if (entryIndex >= 0) {
			var item = propertyModel.get(entryIndex)
			var newValueStr = '' + value
			if (item.value !== newValueStr) {
				propertyModel.setProperty(entryIndex, "value", newValueStr)
			}
		} else {
			// Property doesn't yet exist.
			addEntry(key, value, section)
		}
	}

	function addPulseObjectEntry(key, section) {
		if (typeof pulseObject[key] !== 'undefined') {
			setEntry(key, pulseObject[key], section)
		}
	}

	function addPortEntry(i, port, key, section) {
		if (typeof port[key] !== 'undefined') {
			setEntry('port[' + i + '].' + key, port[key], section)
		}
	}

	function addPropertiesEntries(obj, section) {
		if (typeof obj.properties !== 'undefined') {
			for (var key in obj.properties) {
				setEntry(key, obj.properties[key], section)
			}
		}
	}

	function update() {
		if (!pulseObject) {
			return
		}

		addPulseObjectEntry('name', '')

		// https://invent.kde.org/libraries/pulseaudio-qt/-/blob/master/src/pulseobject.h
		addPulseObjectEntry('index', 'PulseObject')
		addPulseObjectEntry('iconName', 'PulseObject')

		// https://invent.kde.org/libraries/pulseaudio-qt/-/blob/master/src/volumeobject.h
		addPulseObjectEntry('volume', 'VolumeObject')
		addPulseObjectEntry('muted', 'VolumeObject')
		addPulseObjectEntry('hasVolume', 'VolumeObject')
		addPulseObjectEntry('volumeWritable', 'VolumeObject')
		addPulseObjectEntry('channels', 'VolumeObject')
		addPulseObjectEntry('channelVolumes', 'VolumeObject')
		addPulseObjectEntry('rawChannels', 'VolumeObject')

		// https://invent.kde.org/libraries/pulseaudio-qt/-/blob/master/src/device.h
		addPulseObjectEntry('state', 'Device')
		addPulseObjectEntry('description', 'Device')
		addPulseObjectEntry('cardIndex', 'Device')
		addPulseObjectEntry('activePortIndex', 'Device')
		addPulseObjectEntry('default', 'Device')

		if (typeof pulseObject.ports !== 'undefined') {
			for (var i = 0; i < pulseObject.ports.length; i++) {
				var port = pulseObject.ports[i];
				var section = 'Device.ports[' + i + ']'
				addPortEntry(i, port, 'name', section)
				addPortEntry(i, port, 'description', section)
				addPortEntry(i, port, 'priority', section)
				addPortEntry(i, port, 'availability', section)
				addPropertiesEntries(port, section)
			}
		}

		// https://invent.kde.org/libraries/pulseaudio-qt/-/blob/master/src/stream.h
		addPulseObjectEntry('virtualStream', 'Stream')
		addPulseObjectEntry('deviceIndex', 'Stream')
		addPulseObjectEntry('corked', 'Stream')

		addPropertiesEntries(pulseObject, 'PulseObject.properties')
	}

	Component.onCompleted: {
		update()
	}

	Timer {
		running: pulseObjectDialog.visible
		repeat: true
		interval: 1000
		onTriggered: update()
	}

	onVisibleChanged: {
		if (!visible) {
			destroy()
		}
	}
}
