import QtQuick

// Resolves an app icon by reading `Icon=` out of the installed .desktop files.
//
// Needed because an app's PulseAudio properties often don't match any icon
// name in the theme. Helium, for example, reports a binary/app name that has
// no themed icon, while its desktop entry declares `Icon=helium-browser`.
// PulseAudioQt's own iconName() can't bridge that gap -- it only checks names
// the stream itself advertises.
//
// One shell command at startup builds the table; there's no per-stream cost.
// The awk program avoids gawk's ENDFILE (mawk lacks it) and is fed by find |
// xargs so that missing directories don't abort the scan.
Item {
	id: desktopEntryIcons
	visible: false

	// "helium-browser" (desktop file id) -> "helium-browser" (Icon= value)
	property var iconById: ({})
	// "helium-browser" (Exec basename)  -> "helium-browser"
	property var iconByExec: ({})
	// Bumped when the table is (re)built, so QML bindings re-evaluate: plain
	// JS objects are not observable.
	property int revision: 0

	readonly property string scanCommand: "find /usr/share/applications /usr/local/share/applications \"$HOME/.local/share/applications\" /var/lib/flatpak/exports/share/applications \"$HOME/.local/share/flatpak/exports/share/applications\" /var/lib/snapd/desktop/applications -maxdepth 1 -name '*.desktop' 2>/dev/null | xargs -r awk 'function emit(){if(f!=\"\"&&i!=\"\"){n=f;sub(/.*\\//,\"\",n);sub(/\\.desktop$/,\"\",n);print n\"\\t\"e\"\\t\"i}} FNR==1{emit();f=FILENAME;e=\"\";i=\"\"} /^Exec=/&&e==\"\"{sub(/^Exec=/,\"\");split($0,a,\" \");e=a[1];sub(/.*\\//,\"\",e)} /^Icon=/&&i==\"\"{sub(/^Icon=/,\"\");i=$0} END{emit()}'"

	function refresh(execUtil) {
		execUtil.execAwait(scanCommand, function(command, exitCode, exitStatus, stdout, stderr) {
			var byId = ({})
			var byExec = ({})
			var lines = ('' + stdout).split('\n')
			for (var i = 0; i < lines.length; i++) {
				var cols = lines[i].split('\t')
				if (cols.length < 3) {
					continue
				}
				var id = cols[0].toLowerCase()
				var exec = cols[1].toLowerCase()
				var icon = cols[2]
				if (!icon) {
					continue
				}
				if (id && byId[id] === undefined) {
					byId[id] = icon
				}
				if (exec && byExec[exec] === undefined) {
					byExec[exec] = icon
				}
			}
			desktopEntryIcons.iconById = byId
			desktopEntryIcons.iconByExec = byExec
			desktopEntryIcons.revision += 1
		})
	}

	// Try each name as both a desktop-file id and an Exec basename.
	function lookup(names) {
		for (var i = 0; i < names.length; i++) {
			var n = ('' + (names[i] || '')).toLowerCase()
			if (!n) {
				continue
			}
			if (iconById[n]) {
				return iconById[n]
			}
			if (iconByExec[n]) {
				return iconByExec[n]
			}
		}
		return ''
	}
}
