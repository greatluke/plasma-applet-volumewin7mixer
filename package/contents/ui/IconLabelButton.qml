import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ToolButton {
	id: iconLabelButton
	height: iconLabelButtonRow.height
	flat: true
	// The content is drawn manually below.
	display: PlasmaComponents.AbstractButton.IconOnly
	icon.name: ""

	property alias labelText: textLabel.rawText
	property alias iconItemHeight: icon.height
	property string iconFallback: "audio-card"

	// A list of icon names to try in order. Kirigami.Icon reports
	// status === Error when a name isn't in the theme, so walk the list until
	// one loads. Set `iconItemSource` instead for a single known-good name.
	property var iconCandidates: []
	property int iconCandidateIndex: 0
	onIconCandidatesChanged: iconCandidateIndex = 0
	property string iconItemSource: ''
	// Kirigami.Icon has no `overlays` property (PlasmaCore.IconItem did), so
	// emblems are drawn as a small corner icon instead.
	property var iconItemOverlays: []

	Column {
		id: iconLabelButtonRow
		width: parent.width

		Kirigami.Icon {
			id: icon
			width: parent.width
			active: iconLabelButton.hovered

			source: {
				var list = iconLabelButton.iconCandidates
				if (list && list.length > 0) {
					var i = Math.min(iconLabelButton.iconCandidateIndex, list.length - 1)
					return list[i]
				}
				return iconLabelButton.iconItemSource
			}

			// Walk to the next candidate when this one isn't in the theme.
			onStatusChanged: {
				if (status === Kirigami.Icon.Error
						&& iconLabelButton.iconCandidateIndex < iconLabelButton.iconCandidates.length - 1) {
					iconLabelButton.iconCandidateIndex += 1
				}
			}

			// Last resort once every candidate has failed.
			fallback: iconLabelButton.iconFallback

			Kirigami.Icon {
				id: emblem
				visible: iconLabelButton.iconItemOverlays.length > 0
				source: visible ? iconLabelButton.iconItemOverlays[0] : ""
				width: Math.round(parent.width / 2)
				height: width
				anchors.right: parent.right
				anchors.bottom: parent.bottom
			}
		}

		PlasmaComponents.Label {
			id: textLabel
			width: parent.width

			property string rawText: ''
			text: rawText + '\n'
			function updateLineCount() {
				if (lineCount === 1) {
					text = rawText + '\n'
				} else if (truncated) {
					text = rawText
				}
			}
			onLineCountChanged: updateLineCount()
			onTruncatedChanged: updateLineCount()
			opacity: iconLabelButton.hovered ? 1 : 0.6
			wrapMode: Text.Wrap
			elide: Text.ElideRight
			maximumLineCount: 2
			horizontalAlignment: Text.AlignHCenter
		}
	}
}
