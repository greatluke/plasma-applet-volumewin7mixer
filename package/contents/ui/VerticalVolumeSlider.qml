import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.private.volume as PlasmaVolume

/*
	QtQuick.Controls 1 (and QtQuick.Controls.Styles.Plasma) are gone in Qt 6, so
	the old SliderStyle had to be rebuilt on top of the QQC2 based PC3.Slider.

	Gotcha: QQC1's SliderStyle rotated its whole panel for vertical sliders,
	which is why the win7 groove/wedge artwork in volumeslider.svg is drawn
	horizontally. QQC2 does *not* rotate anything, so the groove lives inside a
	container rotated -90 degrees (container +x maps to screen "up", which lines
	up with QQC2's vertical visualPosition where the minimum is at the bottom).
*/
PlasmaComponents.Slider {
	id: slider

	orientation: Qt.Vertical

	property real hundredPercentValue: 65536
	// 100% is 65863.68, not 65536... Bleh. Just trigger at a round number.
	property bool isVolumeBoosted: value > hundredPercentValue
	property bool isBoostable: to > hundredPercentValue

	from: 0
	to: hundredPercentValue * 1.05

	readonly property int percentage: Math.round(value / hundredPercentValue * 100)
	readonly property int maxPercentage: Math.ceil(to / hundredPercentValue * 100)
	stepSize: to / Math.max(1, maxPercentage)

	// PC3.Slider does its own wheel handling in steps of stepSize (1%). We want
	// the configured volumeUpDownSteps instead, so the parent hooks these up.
	signal wheelUp()
	signal wheelDown()

	property bool showPercentageLabel: true
	property bool showVisualFeedback: plasmoid.configuration.showVisualFeedback

	// Replaces the old org.kde.plasma.private.volumewin7mixer C++ plugin and its
	// python peak_monitor.py helper. plasma-pa ships this since Plasma 5.20.
	property var volumeObject: null
	PlasmaVolume.VolumeMonitor {
		id: peakMonitor
		target: (slider.showVisualFeedback && slider.visible && main.dialogVisible) ? slider.volumeObject : null
	}
	readonly property bool isPeaking: peakMonitor.available && peakMonitor.volume > 0
	readonly property real peakRatio: peakMonitor.volume

	property int grooveThickness: Math.round(Kirigami.Units.gridUnit / 3)
	property string svgUrl: config.volumeSliderUrl

	readonly property int numTicks: Math.ceil(maxPercentage / 10) + 1 // 0% .. 100% by 10 = 11 ticks (or ...150% = 16 ticks)
	readonly property real handleLength: handle ? handle.height : 0
	readonly property real travel: Math.max(0, availableHeight - handleLength)
	readonly property real fillLength: position * travel

	KSvg.Svg {
		id: grooveSvg
		imagePath: slider.svgUrl
	}

	wheelEnabled: false
	// See https://bugreports.qt.io/browse/QTBUG-93081
	WheelHandler {
		orientation: Qt.Vertical | Qt.Horizontal
		property int wheelDelta: 0
		acceptedButtons: Qt.NoButton
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		onWheel: (wheel) => {
			const delta = (wheel.inverted ? -1 : 1)
				* (wheel.angleDelta.y ? wheel.angleDelta.y : -wheel.angleDelta.x)
			// Reset on direction change so a leftover remainder doesn't carry.
			if ((wheelDelta > 0 && delta < 0) || (wheelDelta < 0 && delta > 0)) {
				wheelDelta = 0
			}
			wheelDelta += delta
			// Magic number 120 for common "one click"
			while (wheelDelta >= 120) {
				wheelDelta -= 120
				slider.wheelUp()
			}
			while (wheelDelta <= -120) {
				wheelDelta += 120
				slider.wheelDown()
			}
		}
	}

	function calcTickWidth(tickIndex, tickAvailableHeight) {
		if (tickIndex === 0) {
			return 0 // 0% has no tick
		} else if (tickIndex % 5 === 0) {
			// 50%, 100%, 150% have medium length ticks
			// 50%: 2/10, 100%: 3/10, 150%: 4/10, >=200%: 5/10
			return tickAvailableHeight * (1 + Math.min(tickIndex / 5, 4)) / 5
		} else {
			return tickAvailableHeight * 1 / 5 // 10%, 20%, ... have short ticks
		}
	}

	handle: Item {
		id: handleItem

		implicitWidth: handleSvgItem.naturalSize.width
		implicitHeight: handleSvgItem.naturalSize.height

		x: Math.round(slider.leftPadding + (slider.availableWidth - width) / 2)
		y: Math.round(slider.topPadding + slider.visualPosition * (slider.availableHeight - height))

		KSvg.SvgItem {
			id: handleSvgItem
			anchors.fill: parent
			svg: grooveSvg
			elementId: {
				if (slider.visualFocus || slider.pressed) {
					return "vertical-slider-focus"
				} else if (slider.hovered) {
					return "vertical-slider-hover"
				} else {
					return "vertical-slider-handle"
				}
			}
		}

		PlasmaComponents.Label {
			id: percentageLabel
			visible: slider.showPercentageLabel
			text: slider.percentage
			anchors.right: parent.left
			anchors.rightMargin: Kirigami.Units.smallSpacing
			anchors.verticalCenter: parent.verticalCenter
			verticalAlignment: Text.AlignVCenter
			horizontalAlignment: Text.AlignRight
		}
	}

	background: Item {
		id: backgroundItem

		Item {
			id: rotatedGroove

			// Drawn in "horizontal" coordinates, then rotated so that +x is up.
			width: slider.availableHeight
			height: slider.availableWidth
			anchors.centerIn: parent
			rotation: -90

			readonly property real tickAvailableHeight: (height - slider.grooveThickness) / 2

			KSvg.FrameSvgItem {
				id: groove
				imagePath: slider.svgUrl
				prefix: "groove"
				height: slider.grooveThickness
				opacity: slider.enabled ? 1 : 0.6

				anchors.left: parent.left
				anchors.right: parent.right
				anchors.leftMargin: slider.handleLength / 2
				anchors.rightMargin: slider.handleLength - slider.handleLength / 2
				anchors.verticalCenter: parent.verticalCenter

				KSvg.FrameSvgItem {
					id: highlight
					imagePath: slider.svgUrl
					prefix: slider.percentage <= 100 ? "groove-highlight" : "groove-danger"
					height: groove.height
					width: slider.fillLength
					visible: width > 0
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
				}

				KSvg.FrameSvgItem {
					id: peakHighlight
					imagePath: slider.svgUrl
					prefix: "groove-peaking"
					height: groove.height
					width: slider.fillLength * slider.peakRatio
					visible: slider.isPeaking && width > 0
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
				}

				KSvg.SvgItem {
					id: grooveTriangle
					svg: grooveSvg
					elementId: "groove-triangle"
					height: slider.calcTickWidth(slider.numTicks - 1, rotatedGroove.tickAvailableHeight)
					anchors.left: parent.left
					anchors.right: parent.right
					anchors.top: groove.bottom

					Item {
						height: grooveTriangle.height
						width: slider.fillLength
						clip: true

						KSvg.SvgItem {
							id: grooveHighlightTriangle
							svg: grooveSvg
							elementId: slider.percentage <= 100 ? "groove-highlight-triangle" : "groove-danger-triangle"
							height: grooveTriangle.height
							width: grooveTriangle.width
							visible: slider.value > 0
						}
					}

					Item {
						height: grooveTriangle.height
						width: slider.fillLength * slider.peakRatio
						clip: true

						KSvg.SvgItem {
							id: groovePeakHighlightTriangle
							svg: grooveSvg
							elementId: "groove-peaking-triangle"
							height: grooveTriangle.height
							width: grooveTriangle.width
							visible: slider.isPeaking && slider.value > 0
						}
					}
				}
			}

			Repeater {
				id: tickRepeater
				model: slider.numTicks

				Rectangle {
					required property int index

					function setAlpha(c, a) {
						var c2 = Qt.darker(c, 1)
						c2.a = a
						return c2
					}
					color: Kirigami.Theme.textColor === Kirigami.Theme.backgroundColor
						? Kirigami.Theme.backgroundColor
						: setAlpha(Kirigami.Theme.textColor, 0.3)
					width: 1
					height: slider.calcTickWidth(index, rotatedGroove.tickAvailableHeight)
					y: rotatedGroove.height / 2 + slider.grooveThickness / 2
					x: slider.handleLength / 2
						+ index * (slider.travel / Math.max(1, tickRepeater.count - 1))
						- 1
				}
			}
		}
	}
}
