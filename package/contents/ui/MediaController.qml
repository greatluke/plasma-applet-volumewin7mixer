import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.coreaddons as KCoreAddons

Item {
	id: mediaController
	property bool disablePositionUpdate: false
	property bool keyPressed: false

	Item {
		anchors.fill: parent
		anchors.topMargin: seekRow.height

		Item {
			anchors.fill: parent
			anchors.rightMargin: rightSide.width

			Item {
				id: albumArtContainer
				anchors.left: parent.left
				width: height
				height: parent.height

				Kirigami.Icon {
					id: playerIcon
					anchors.fill: parent
					source: mpris2Source.playerIcon
				}

				Image {
					id: albumArt
					anchors.fill: parent
					source: mpris2Source.albumArt
					asynchronous: true
					fillMode: Image.PreserveAspectCrop
					sourceSize: Qt.size(width, height)
					visible: !!mpris2Source.track && status === Image.Ready
				}
			}

			Column {
				id: leftSide
				anchors.fill: parent
				anchors.leftMargin: albumArtContainer.width + Kirigami.Units.smallSpacing

				// MediaControllerCompact's style
				PlasmaComponents.Label {
					id: track
					width: parent.width
					opacity: 0.9
					height: parent.height / 2

					elide: Text.ElideRight
					text: mpris2Source.track
				}

				PlasmaComponents.Label {
					id: artist
					width: parent.width
					opacity: 0.7
					height: parent.height / 2

					elide: Text.ElideRight
					text: mpris2Source.artist
				}
			}
		}

		Row {
			id: rightSide
			width: childrenRect.width
			height: parent.height
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter

			PlasmaComponents.ToolButton {
				icon.name: "media-skip-backward"
				display: PlasmaComponents.AbstractButton.IconOnly
				width: height
				height: parent.height
				enabled: mpris2Source.canGoPrevious
				onClicked: {
					seekSlider.value = 0 // Let the media start from beginning. Bug 362473 (org.kde.plasma.mediacontroller)
					mpris2Source.previous()
				}
			}
			PlasmaComponents.ToolButton {
				icon.name: mpris2Source.isPlaying ? "media-playback-pause" : "media-playback-start"
				display: PlasmaComponents.AbstractButton.IconOnly
				width: height
				height: parent.height
				enabled: mpris2Source.canControl
				onClicked: mpris2Source.playPause()
			}
			PlasmaComponents.ToolButton {
				icon.name: "media-skip-forward"
				display: PlasmaComponents.AbstractButton.IconOnly
				width: height
				height: parent.height
				enabled: mpris2Source.canGoNext
				onClicked: {
					seekSlider.value = 0 // Let the media start from beginning. Bug 362473 (org.kde.plasma.mediacontroller)
					mpris2Source.next()
				}
			}
		}
	}

	RowLayout {
		id: seekRow
		anchors.left: parent.left
		anchors.top: parent.top
		anchors.right: parent.right
		height: config.mediaControllerSliderHeight

		// org.kde.plasma.mediacontroller
		// ensure the layout doesn't shift as the numbers change and measure roughly
		// the longest text that could occur with the current song
		TextMetrics {
			id: timeMetrics
			text: i18ndc("plasma_applet_org.kde.plasma.mediacontroller", "Remaining time for song e.g -5:42", "-%1",
						KCoreAddons.Format.formatDuration(seekSlider.to / 1000, KCoreAddons.FormatTypes.FoldHours))
			font: Kirigami.Theme.smallFont
		}

		PlasmaComponents.Label {
			visible: plasmoid.configuration.showMediaTimeElapsed
			Layout.preferredWidth: timeMetrics.width
			Layout.fillHeight: true
			verticalAlignment: Text.AlignVCenter
			horizontalAlignment: Text.AlignRight
			text: KCoreAddons.Format.formatDuration(seekSlider.value / 1000, KCoreAddons.FormatTypes.FoldHours)
			opacity: 0.6
			font: Kirigami.Theme.smallFont
		}

		PlasmaComponents.Slider {
			id: seekSlider
			Layout.fillWidth: true
			Layout.fillHeight: true
			enabled: mpris2Source.canSeek
			z: 999

			from: 0
			to: 1
			value: 0

			opacity: hovered ? 1 : 0.75
			Behavior on opacity {
				NumberAnimation { duration: Kirigami.Units.longDuration }
			}

			onValueChanged: {
				if (!mediaController.disablePositionUpdate) {
					// delay setting the position to avoid race conditions
					queuedPositionUpdate.restart()
				}
			}
			onToChanged: mpris2Source.retrievePosition()

			Connections {
				target: mpris2Source

				function onPositionChanged() {
					// we don't want to interrupt the user dragging the slider
					if (!seekSlider.pressed && !mediaController.keyPressed && !queuedPositionUpdate.running) {
						// we also don't want passive position updates
						mediaController.disablePositionUpdate = true
						if (seekSlider.to !== mpris2Source.length) { // onLengthChanged isn't always called.
							seekSlider.to = Math.max(1, mpris2Source.length)
						}
						seekSlider.value = mpris2Source.position
						mediaController.disablePositionUpdate = false
					}
				}
				function onLengthChanged() {
					mediaController.disablePositionUpdate = true
					seekSlider.to = Math.max(1, mpris2Source.length)
					mediaController.disablePositionUpdate = false
				}
			}

			Timer {
				id: queuedPositionUpdate
				interval: 100
				onTriggered: {
					if (!mediaController.disablePositionUpdate) {
						mpris2Source.setPosition(seekSlider.value)
					}
				}
			}

			Timer {
				id: seekTimer
				interval: 1000
				repeat: true
				running: mpris2Source.isPlaying && main.dialogVisible && !mediaController.keyPressed
				onTriggered: {
					// some players don't continuously update the seek slider position via mpris
					// add one second; value in microseconds
					if (!seekSlider.pressed) {
						mediaController.disablePositionUpdate = true
						if (seekSlider.value === seekSlider.to) {
							mpris2Source.retrievePosition();
						} else {
							seekSlider.value += 1000000
						}
						mediaController.disablePositionUpdate = false
					}
				}
			}
		}

		PlasmaComponents.Label {
			visible: plasmoid.configuration.showMediaTimeLeft
			Layout.preferredWidth: timeMetrics.width
			Layout.fillHeight: true
			verticalAlignment: Text.AlignVCenter
			text: i18nc("Remaining time for song e.g -5:42", "-%1",
						KCoreAddons.Format.formatDuration((seekSlider.to - seekSlider.value) / 1000, KCoreAddons.FormatTypes.FoldHours))
			opacity: 0.6
			font: Kirigami.Theme.smallFont
		}

		PlasmaComponents.Label {
			visible: plasmoid.configuration.showMediaTotalDuration
			Layout.preferredWidth: timeMetrics.width
			Layout.fillHeight: true
			verticalAlignment: Text.AlignVCenter
			horizontalAlignment: Text.AlignRight
			text: KCoreAddons.Format.formatDuration(seekSlider.to / 1000, KCoreAddons.FormatTypes.FoldHours)
			opacity: 0.6
			font: Kirigami.Theme.smallFont
		}
	}
}
