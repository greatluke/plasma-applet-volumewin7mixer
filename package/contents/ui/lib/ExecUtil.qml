import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

// The "executable" DataEngine lives in plasma5support in Plasma 6.
Plasma5Support.DataSource {
	id: executable
	engine: "executable"
	connectedSources: []
	onNewData: (sourceName, data) => {
		var exitCode = data["exit code"]
		var exitStatus = data["exit status"]
		var stdout = data["stdout"]
		var stderr = data["stderr"]
		exited(sourceName, exitCode, exitStatus, stdout, stderr)
		disconnectSource(sourceName) // cmd finished
	}
	function exec(cmd) {
		connectSource(cmd)
	}
	signal exited(string command, int exitCode, int exitStatus, string stdout, string stderr)

	function trimOutput(stdout) {
		return stdout.replace('\n', ' ').trim()
	}

	property var callbacks: ({})
	function execAwait(cmd, callback) {
		connectSource(cmd)
		if (typeof callback === "function") {
			if (callbacks[cmd]) {
				console.log('ExecUtil.callbacks[cmd] already registered', cmd)
			} else {
				callbacks[cmd] = callback
			}
		}
	}
	onExited: (command, exitCode, exitStatus, stdout, stderr) => {
		if (callbacks[command]) {
			callbacks[command](command, exitCode, exitStatus, stdout, stderr)
			delete callbacks[command]
		}
	}
}
