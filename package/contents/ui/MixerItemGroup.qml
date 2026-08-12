import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

import "lib"

// Was a QtQuick.Controls 1 GroupBox with a PlasmaStyles.GroupBoxStyle. Both are
// gone in Qt 6, so the frame + header button are drawn directly.
Item {
	id: mixerItemGroup

	property alias view: view
	property alias spacing: view.spacing
	property alias model: view.model
	property alias delegate: view.delegate
	property string title: ''
	property int mixerItemWidth: config.mixerItemWidth
	property int volumeSliderWidth: config.volumeSliderWidth
	property string mixerGroupType: ''

	visible: view.count > 0
	width: visible ? view.width + frame.margins.left + frame.margins.right : 0

	KSvg.FrameSvgItem {
		id: frame
		anchors.fill: parent
		imagePath: "widgets/frame"
		prefix: "plain"
	}

	PlasmaComponents.ToolButton {
		id: label
		anchors.top: parent.top
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.topMargin: frame.margins.top
		anchors.leftMargin: frame.margins.left
		anchors.rightMargin: frame.margins.right
		height: Math.max(Kirigami.Theme.defaultFont.pixelSize, Kirigami.Units.gridUnit * 1.25)

		text: mixerItemGroup.title
		flat: true

		// QQC2 buttons center their label; the group headers were left aligned.
		contentItem: PlasmaComponents.Label {
			text: label.text
			font: label.font
			horizontalAlignment: Text.AlignLeft
			verticalAlignment: Text.AlignVCenter
			elide: Text.ElideRight
		}

		onClicked: contextMenu.showRelative()

		ContextMenu {
			id: contextMenu
			visualParent: label
			placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

			onBeforeOpen: (menu) => {
				for (var i = 0; i < view.model.count; i++) {
					var stream = view.model.get(i)
					if (!stream) {
						continue
					}
					var menuItem = menu.newMenuItem()
					menuItem.text = stream.name
					menuItem.checkable = true
					menuItem.checked = true
					menuItem.enabled = false
					menu.addMenuItem(menuItem)
				}
			}
		}
	}

	ListView {
		id: view
		anchors.top: label.bottom
		anchors.bottom: parent.bottom
		anchors.left: parent.left
		anchors.leftMargin: frame.margins.left
		anchors.bottomMargin: frame.margins.bottom
		width: Math.max(childrenRect.width, mixerItemGroup.mixerItemWidth) // At least 1 mixer item wide
		spacing: 0
		boundsBehavior: Flickable.StopAtBounds
		orientation: ListView.Horizontal

		delegate: MixerItem {
			height: ListView.view.height
			mixerItemWidth: mixerItemGroup.mixerItemWidth
			volumeSliderWidth: mixerItemGroup.volumeSliderWidth
			mixerItemType: mixerItemGroup.mixerGroupType
			showDefaultDeviceIndicator: {
				if (isDevice) {
					return mixerItemGroup.model.count > 1
				} else {
					return false
				}
			}
		}

		currentIndex: -1

		highlight: Rectangle {
			color: "transparent"
			anchors.fill: view.currentItem
			border.width: 1
			border.color: config.selectedStreamOutline

			SequentialAnimation on border.color {
				loops: Animation.Infinite
				ColorAnimation {
					from: config.selectedStreamOutline
					to: config.selectedStreamOutlinePulse
					duration: 1000
				}
				ColorAnimation {
					from: config.selectedStreamOutlinePulse
					to: config.selectedStreamOutline
					duration: 1000
				}
			}
		}
	}
}
