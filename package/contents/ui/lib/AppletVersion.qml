import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid

// Plasma 5 shelled out to kreadconfig5 to read the version out of
// metadata.desktop. In Plasma 6 the KPluginMetaData is right there.
QQC2.Label {
	property string version: Plasmoid.metaData.version || "?"
	text: i18n("<b>Version:</b> %1", version)
}
