import QtQuick
import org.kde.kirigami as Kirigami

// NOTE: Plasma 5's `units.devicePixelRatio` was a font based scaling factor and
// no longer exists in Plasma 6 (Qt 6 scales logical pixels itself, so
// multiplying by the real Screen.devicePixelRatio would double scale on HiDPI).
// The hardcoded pixel sizes have been re-expressed in Kirigami.Units instead.
Item {
	id: appletConfig
	visible: false

	// was: 16 * units.devicePixelRatio
	property int mediaControllerSliderHeight: Kirigami.Units.gridUnit
	// was: 64 * units.devicePixelRatio
	property int mediaControllerHeight: Math.round(Kirigami.Units.gridUnit * 3.5)
	property int mixerGroupHeight: Kirigami.Units.gridUnit * 24
	// was: 100 * units.devicePixelRatio
	property int mixerItemWidth: Math.round(Kirigami.Units.gridUnit * 5.5)
	// was: 48 * units.devicePixelRatio
	property int volumeSliderWidth: Kirigami.Units.iconSizes.huge

	// KSvg wants a filesystem path, not a file:// url.
	function svgPath(relativePath) {
		return Qt.resolvedUrl(relativePath).toString().replace(/^file:\/\//, '')
	}

	property string volumeSliderDesktopThemeId: "widgets/volumeslider"
	property string volumeSliderUrl: {
		if (plasmoid.configuration.volumeSliderTheme === "default") {
			return svgPath("../images/volumeslider-default.svg")
		} else { // "desktoptheme" / "colortheme"
			return svgPath("../images/volumeslider.svg")
		}
	}

	property color selectedStreamOutline: appletConfig.withAlpha(Kirigami.Theme.textColor, 0.25)
	property color selectedStreamOutlinePulse: Kirigami.Theme.textColor

	function withAlpha(c1, alpha) {
		var c2 = Qt.darker(c1, 1)
		c2.a = alpha
		return c2
	}
}
