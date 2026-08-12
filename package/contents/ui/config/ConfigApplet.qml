import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import "../lib"

ConfigPage {
	id: page
	showAppletVersion: true

	property alias cfg_volumeUpDownSteps: volumeUpDownSteps.value
	property alias cfg_showVolumeTickmarks: showVolumeTickmarks.checked
	property alias cfg_moveAllAppsOnSetDefault: moveAllAppsOnSetDefault.checked
	property alias cfg_closeOnSetDefault: closeOnSetDefault.checked
	property alias cfg_setDefaultOnClickIcon: setDefaultOnClickIcon.checked
	property alias cfg_showMediaController: showMediaController.checked
	property alias cfg_showMediaTimeElapsed: showMediaTimeElapsed.checked
	property alias cfg_showMediaTimeLeft: showMediaTimeLeft.checked
	property alias cfg_showMediaTotalDuration: showMediaTotalDuration.checked
	property alias cfg_showOsd: showOsd.checked
	property alias cfg_volumeChangeFeedback: volumeChangeFeedback.checked
	property alias cfg_showVisualFeedback: showVisualFeedback.checked
	property alias cfg_showVirtualStreams: showVirtualStreams.checked

	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Media Keys")

		ColumnLayout {
			anchors.fill: parent

			QQC2.Label {
				text: i18n("Volume Up/Down and Mute are handled by the system's audio shortcuts service in Plasma 6. This step size still applies to scrolling the widget.")
				wrapMode: Text.Wrap
				Layout.fillWidth: true
				opacity: 0.7
			}

			RowLayout {
				QQC2.Label {
					text: i18n("Volume Up/Down Steps:")
				}
				QQC2.SpinBox {
					id: volumeUpDownSteps
					from: 1
					to: 1000
				}
				QQC2.Label {
					text: i18n("One step = %1%", Math.round(1/volumeUpDownSteps.value * 100))
				}
			}
		}
	}

	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Mixer")

		ColumnLayout {
			anchors.fill: parent

			QQC2.CheckBox {
				enabled: false
				id: showVolumeTickmarks
				checked: true
				text: i18n("Show Ticks every 10%")
			}

			RowLayout {
				QQC2.Label {
					text: i18n("Volume Boost")
				}
				QQC2.SpinBox {
					enabled: false
					id: volumeBoostMaxVolume
					from: 100
					value: 150
					to: 1000
					stepSize: 10
				}
			}
		}
	}

	QQC2.ButtonGroup { id: volumeSliderThemeGroup }
	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Volume Slider Theme")

		ColumnLayout {
			anchors.fill: parent

			QQC2.RadioButton {
				text: i18n("Color Theme (Default Look)")
				QQC2.ButtonGroup.group: volumeSliderThemeGroup
				checked: plasmoid.configuration.volumeSliderTheme !== "default"
				onClicked: plasmoid.configuration.volumeSliderTheme = "desktoptheme"
			}

			QQC2.RadioButton {
				text: i18n("Light Blue on Grey (Default Look)")
				QQC2.ButtonGroup.group: volumeSliderThemeGroup
				checked: plasmoid.configuration.volumeSliderTheme === "default"
				onClicked: plasmoid.configuration.volumeSliderTheme = "default"
			}
		}
	}

	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Options")

		ColumnLayout {
			anchors.fill: parent

			QQC2.CheckBox {
				id: moveAllAppsOnSetDefault
				text: i18n("Move all Apps to device when setting default device (when set in with the context menu)")
			}

			QQC2.CheckBox {
				id: closeOnSetDefault
				text: i18n("Close the popup after setting a default device")
			}

			QQC2.CheckBox {
				id: setDefaultOnClickIcon
				text: i18n("Set default device after clicking a speaker/mic icon")
			}

			QQC2.CheckBox {
				id: showOsd
				text: i18n("Show OSD on when changing the volume.")
			}

			QQC2.CheckBox {
				id: volumeChangeFeedback
				text: i18n("Volume Feedback: Play popping noise when changing the volume.")
			}

			QQC2.CheckBox {
				id: showVisualFeedback
				text: i18n("Visual Feedback: Visualize current sound.")
			}

			QQC2.CheckBox {
				id: showVirtualStreams
				text: i18n("Show virtual streams.")
			}
		}
	}

	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Media Controller")

		ColumnLayout {
			anchors.fill: parent

			QQC2.CheckBox {
				id: showMediaController
				text: i18n("Show Media Controller")
			}

			ConfigComboBox {
				id: mediaControllerLocationControl
				configKey: "mediaControllerLocation"
				label: i18n("Position")
				model: [
					{ value: "top", text: i18n("Top") },
					{ value: "bottom", text: i18n("Bottom") },
				]
			}

			QQC2.CheckBox {
				id: showMediaTimeElapsed
				text: i18n("Show Time Elapsed")
			}

			QQC2.CheckBox {
				id: showMediaTimeLeft
				text: i18n("Show Time Left")
			}

			QQC2.CheckBox {
				id: showMediaTotalDuration
				text: i18n("Show Total Duration")
			}
		}
	}

	QQC2.GroupBox {
		Layout.fillWidth: true
		title: i18n("Keyboard Shortcuts")

		ColumnLayout {
			id: shortcutsTable
			anchors.fill: parent

			QQC2.Label {
				text: i18n("Set the Global Shortcut in the Keyboard Shortcuts tab.")
				wrapMode: Text.Wrap
				Layout.fillWidth: true
			}

			QQC2.Label {} // Whitespace

			Repeater {
				property var shortcuts: [
					{
						"label": i18n("Global Shortcut"),
						"keySequence": plasmoid.globalShortcut,
					},
					{
						"label": i18n("Selection: Select Previous Stream"),
						"keySequence": "Left",
					},
					{
						"label": i18n("Selection: Select Next Stream"),
						"keySequence": "Right",
					},
					{
						"label": i18n("Selection: Increase Volume"),
						"keySequence": "Up",
					},
					{
						"label": i18n("Selection: Decrease Volume"),
						"keySequence": "Down",
					},
					{
						"label": i18n("Selection: Make Default Device"),
						"keySequence": "Enter",
					},
					{
						"label": i18n("Selection: Toggle Mute"),
						"keySequence": "M",
					},
					{
						"label": i18n("Selection: Open Context Menu"),
						"keySequence": "Menu",
					},
				]

				Component.onCompleted: {
					for (var i = 0; i <= 10; i++) {
						shortcuts.push({
							"label": i18n("Selection: Set Volume to %1%", i*10),
							"keySequence": i < 10 ? "" + i : "",
						})
						model = shortcuts
					}
				}

				RowLayout {
					id: shortcutRow
					required property var modelData
					Layout.fillWidth: true
					QQC2.Label {
						text: shortcutRow.modelData.keySequence
						Layout.minimumWidth: Kirigami.Units.gridUnit * 5
					}
					QQC2.Label {
						text: shortcutRow.modelData.label
						font.bold: true
					}
				}
			}
		}
	}
}
