import QtQuick
import org.kde.plasma.private.mpris as Mpris

// Plasma 6 deleted the "mpris2" DataEngine. libkmpris (shipped by
// plasma-workspace as org.kde.plasma.private.mpris) replaces it.
// This wrapper keeps the property/function names the old Mpris2DataSource had
// so MediaController.qml barely changed.
Item {
	id: mpris2Source
	visible: false

	Mpris.Mpris2Model {
		id: mpris2Model
	}

	readonly property var currentPlayer: mpris2Model.currentPlayer
	readonly property bool hasPlayer: !!currentPlayer

	readonly property int playbackStatus: currentPlayer ? currentPlayer.playbackStatus : Mpris.PlaybackStatus.Stopped
	readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
	readonly property bool isPaused: playbackStatus === Mpris.PlaybackStatus.Paused

	readonly property int loopStatus: currentPlayer ? currentPlayer.loopStatus : Mpris.LoopStatus.None
	readonly property bool isNotLooping: loopStatus === Mpris.LoopStatus.None
	readonly property bool isLoopingTrack: loopStatus === Mpris.LoopStatus.Track
	readonly property bool isLoopingPlaylist: loopStatus === Mpris.LoopStatus.Playlist
	readonly property bool isShuffling: currentPlayer ? currentPlayer.shuffle === Mpris.ShuffleStatus.On : false

	readonly property bool canControl: currentPlayer ? currentPlayer.canControl : false
	readonly property bool canGoPrevious: currentPlayer ? currentPlayer.canGoPrevious : false
	readonly property bool canGoNext: currentPlayer ? currentPlayer.canGoNext : false
	readonly property bool canRaise: currentPlayer ? currentPlayer.canRaise : false
	readonly property bool canShuffle: canControl
	readonly property bool canLoop: canControl
	readonly property bool canSeekMpris: currentPlayer ? currentPlayer.canSeek : false
	readonly property bool canSeek: canSeekMpris && length > 0

	readonly property string playerIcon: currentPlayer ? currentPlayer.iconName : ''
	readonly property string albumArt: currentPlayer ? currentPlayer.artUrl : ''
	readonly property string track: currentPlayer ? currentPlayer.track : ''
	readonly property string artist: currentPlayer ? currentPlayer.artist : ''

	// Both are microseconds, same units the DataEngine used.
	readonly property double length: currentPlayer ? currentPlayer.length : 0
	readonly property double position: currentPlayer ? currentPlayer.position : 0

	function retrievePosition() {
		if (currentPlayer) {
			currentPlayer.updatePosition()
		}
	}

	function setPosition(value) {
		if (currentPlayer) {
			currentPlayer.position = value
		}
	}

	function playPause() {
		if (currentPlayer) {
			if (isPlaying) {
				currentPlayer.Pause()
			} else {
				currentPlayer.Play()
			}
		}
	}

	function previous() {
		if (currentPlayer) {
			currentPlayer.Previous()
		}
	}

	function next() {
		if (currentPlayer) {
			currentPlayer.Next()
		}
	}

	function stop() {
		if (currentPlayer) {
			currentPlayer.Stop()
		}
	}

	function raise() {
		if (currentPlayer) {
			currentPlayer.Raise()
		}
	}

	function setShuffle(value) {
		if (currentPlayer) {
			currentPlayer.shuffle = value ? Mpris.ShuffleStatus.On : Mpris.ShuffleStatus.Off
		}
	}

	function toggleShuffle() {
		setShuffle(!isShuffling)
	}

	function setLoopState(value) {
		if (currentPlayer) {
			currentPlayer.loopStatus = value
		}
	}

	function toggleLoopState() {
		if (isNotLooping) {
			setLoopState(Mpris.LoopStatus.Track)
		} else if (isLoopingTrack) {
			setLoopState(Mpris.LoopStatus.Playlist)
		} else {
			setLoopState(Mpris.LoopStatus.None)
		}
	}

	Connections {
		target: main
		function onDialogVisibleChanged() {
			if (main.dialogVisible) {
				mpris2Source.retrievePosition()
			}
		}
	}
}
