import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

/*
** Example:
**
ConfigComboBox {
	configKey: "appDescription"
	model: [
		{ value: "hidden", text: i18n("Hidden") },
		{ value: "after", text: i18n("After") },
	]
}
*/
RowLayout {
	id: configComboBox
	spacing: 2
	Layout.maximumWidth: 300

	property alias label: label.text
	property alias horizontalAlignment: label.horizontalAlignment

	property string configKey: ''
	readonly property string value: configKey ? plasmoid.configuration[configKey] : ""
	onValueChanged: comboBox.selectValue(value)
	function setValue(val) { comboBox.selectValue(val) }

	property alias model: comboBox.model

	signal populate()
	Component.onCompleted: populate()

	QQC2.Label {
		id: label
		text: "Label"
		Layout.fillWidth: horizontalAlignment === Text.AlignRight
		horizontalAlignment: Text.AlignLeft
	}

	QQC2.ComboBox {
		id: comboBox
		Layout.fillWidth: label.horizontalAlignment === Text.AlignLeft
		textRole: "text"
		valueRole: "value"

		onCurrentIndexChanged: {
			if (currentIndex >= 0 && typeof model !== 'number') {
				var val = model[currentIndex].value
				if (configKey && val) {
					plasmoid.configuration[configKey] = val
				}
			}
		}

		function size() {
			if (typeof model === "number") {
				return model
			} else if (typeof model.count === "number") {
				return model.count
			} else if (typeof model.length === "number") {
				return model.length
			} else {
				return 0
			}
		}

		function findValue(val) {
			for (var i = 0; i < size(); i++) {
				if (model[i].value === val) {
					return i
				}
			}
			return -1
		}

		function selectValue(val) {
			var index = comboBox.findValue(val)
			if (index >= 0) {
				comboBox.currentIndex = index
			}
		}
	}
}
