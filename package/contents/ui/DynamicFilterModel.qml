import QtQuick
import org.kde.kitemmodels as KItemModels

// Plasma 6 removed PlasmaCore.SortFilterModel; KSortFilterProxyModel is the
// replacement.
//
// NOTE: KSortFilterProxyModel is a QObject, not an Item, so it has NO default
// property -- no child objects may be declared inside it (a nested
// `Connections {}` fails with "Cannot assign to non-existent default
// property"). Config changes are handled with a mirrored property + change
// handler on the root object instead.
//
// Role numbers come from PulseAudioQt's AbstractModel::role(), which is
// Q_INVOKABLE, rather than the KRoleNames attached property. PulseAudioQt
// derives role names from the object's Q_PROPERTYs with the first letter
// upper-cased, so `virtualStream` becomes the "VirtualStream" role.
KItemModels.KSortFilterProxyModel {
	id: dynamicFilterModel

	readonly property int pulseObjectRole: sourceModel ? sourceModel.role("PulseObject") : -1
	readonly property int virtualStreamRole: sourceModel ? sourceModel.role("VirtualStream") : -1
	readonly property int nameRole: sourceModel ? sourceModel.role("Name") : -1

	// Infrastructure streams that aren't apps. plasma-pa's own applet hides
	// exactly these two, so the widget stays consistent with it.
	// NOTE: MicTest-Record / MicTest-Playback are deliberately NOT hidden --
	// they're real streams from a running microphone test, and plasma-pa shows
	// them too, so suppressing them would hide something genuinely playing.
	readonly property var hiddenStreamNames: [
		"auto_null", // the dummy output
	]

	readonly property bool showVirtualStreams: plasmoid.configuration.showVirtualStreams
	onShowVirtualStreamsChanged: invalidateFilter()

	// Returns the PulseObject directly (the old SortFilterModel returned a row
	// you reached `.PulseObject` through).
	function get(row) {
		if (row < 0 || row >= count || pulseObjectRole < 0) {
			return null
		}
		var idx = dynamicFilterModel.index(row, 0)
		if (!idx.valid) {
			return null
		}
		return dynamicFilterModel.data(idx, pulseObjectRole)
	}

	filterRowCallback: function(source_row, source_parent) {
		var idx = sourceModel.index(source_row, 0, source_parent)

		if (dynamicFilterModel.nameRole >= 0) {
			var name = sourceModel.data(idx, dynamicFilterModel.nameRole)
			if (dynamicFilterModel.hiddenStreamNames.indexOf(name) >= 0) {
				return false
			}
			// libcanberra plays the system notification sounds; it appears and
			// vanishes constantly, which makes the mixer jump around.
			if (name === "libcanberra") {
				return false
			}
		}

		if (dynamicFilterModel.virtualStreamRole < 0) {
			return true // model has no VirtualStream role (Sink/Source/Card)
		}
		var isVirtual = sourceModel.data(idx, dynamicFilterModel.virtualStreamRole)
		if (isVirtual && !dynamicFilterModel.showVirtualStreams) {
			return false
		}
		return true
	}
}
