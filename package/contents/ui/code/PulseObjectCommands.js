var maximumValue = 65536

function bound(value, min, max) {
	return Math.max(min, Math.min(value, max))
}

function volumePercent(volume) {
	return Math.round(volume / maximumValue * 100.0)
}

function toggleMute(pulseObject) {
	var toMute = !pulseObject.muted
	pulseObject.muted = toMute
	return toMute
}

function setPercent(pulseObject, percent) {
	var volume = maximumValue * percent/100
	return setVolume(pulseObject, volume)
}

function setVolume(pulseObject, volume) {
	// console.log('setVolume', pulseObject.volume, '=>', volume)
	if ((volume > 0 && pulseObject.muted) || (volume == 0 && !pulseObject.muted)) {
		toggleMute(pulseObject)
	}
	pulseObject.volume = volume
	return volume
}

function calcVolume(min, current, max, step) {
	step = Math.ceil(step)
	var volume = bound(current + step, min, max)
	if (max - volume < step * 0.5) {
		volume = max
	} else if (volume < step * 0.5) {
		volume = min
	}
	return volume
}

function addVolume(pulseObject, step) {
	// console.log('addVolume', pulseObject, step)
	var volume = calcVolume(0, pulseObject.volume, maximumValue, step)
	return setVolume(pulseObject, volume)
}

function increaseVolume(pulseObject) {
	// console.log('increaseVolume', pulseObject)
	var totalSteps = plasmoid.configuration.volumeUpDownSteps
	var step = maximumValue / totalSteps
	return addVolume(pulseObject, step)
}


function decreaseVolume(pulseObject) {
	// console.log('decreaseVolume', pulseObject)
	var totalSteps = plasmoid.configuration.volumeUpDownSteps
	var step = maximumValue / totalSteps
	return addVolume(pulseObject, -step)
}

function addChannelVolume(pulseObject, channelIndex, step) {
	var volume = calcVolume(0, pulseObject.channelVolumes[channelIndex], maximumValue, step)
	return pulseObject.setChannelVolume(channelIndex, volume)
}

function increaseChannelVolume(pulseObject, channelIndex) {
	var totalSteps = plasmoid.configuration.volumeUpDownSteps
	var step = maximumValue / totalSteps
	return addChannelVolume(pulseObject, channelIndex, step)
}

function decreaseChannelVolume(pulseObject, channelIndex) {
	var totalSteps = plasmoid.configuration.volumeUpDownSteps
	var step = maximumValue / totalSteps
	return addChannelVolume(pulseObject, channelIndex, -step)
}


// module toggle utils
function getProperty(pulseObject, key, defaultValue) {
	// Not necessarily a Source
	if (typeof pulseObject.properties === "undefined")
		return defaultValue

	var value = pulseObject.properties[key]
	if (value) {
		return parseInt(value, 10)
	} else {
		return defaultValue
	}
}

// The Plasma 5 widget persisted module ids into the source's proplist with
// `pacmd update-source-proplist`. PipeWire's pulse server (pipewire-pulse) does
// not implement pacmd at all, so that command silently failed, the id was never
// stored, and every toggle loaded ANOTHER module instead of unloading the old
// one -- leaking module-loopback / module-echo-cancel instances.
//
// Rather than remember an id we were told once, the live module list is the
// single source of truth: it is re-read after every load/unload, and disabling
// unloads EVERY matching module for that source. That way any leaked duplicates
// (from an older build, or a crash) get cleaned up by one toggle.
//
// A single JS import is shared by all instances of the importing QML document,
// so every MixerItem sees the same table.
var loadedModules = [] // [{ id, name, sourceId }]

function moduleNameFor(key) {
	return key === 'echo_cancel.module_id' ? 'module-echo-cancel' : 'module-loopback'
}

// Every module for `sourceId` of that type, newest first.
function findModuleIds(sourceId, key) {
	var name = moduleNameFor(key)
	var ids = []
	for (var i = 0; i < loadedModules.length; i++) {
		var m = loadedModules[i]
		if (m.name === name && m.sourceId === sourceId) {
			ids.push(m.id)
		}
	}
	return ids
}

function parseModuleList(stdout) {
	var result = []
	var lines = ('' + stdout).split('\n')
	for (var i = 0; i < lines.length; i++) {
		var cols = lines[i].split('\t')
		if (cols.length < 3) {
			continue
		}
		var id = parseInt(cols[0], 10)
		var name = cols[1]
		var args = cols[2]
		if (isNaN(id)) {
			continue
		}
		if (name !== 'module-loopback' && name !== 'module-echo-cancel') {
			continue
		}
		// "source=N" also appears inside loopback.source=N / echo_cancel.source=N,
		// which carry the same value, so a plain match is fine.
		var m = args.match(/source=(\d+)/)
		if (!m) {
			continue
		}
		result.push({ id: id, name: name, sourceId: parseInt(m[1], 10) })
	}
	return result
}

// Re-read the live module list. Called on startup and after every toggle.
function syncModuleIds(execUtil) {
	execUtil.execAwait('pactl list short modules', function(command, exitCode, exitStatus, stdout, stderr) {
		if (exitCode !== 0) {
			console.log('syncModuleIds failed:', stderr)
			return
		}
		loadedModules = parseModuleList(stdout)
		// Plain JS state is not observable, so nudge the QML bindings.
		main.moduleRevision += 1
	})
}

// --- Orphaned modules -------------------------------------------------------
//
// A loopback / echo-cancel module is bound to a source *index*. Indices are
// reassigned when a device is replugged or the audio server restarts, so a
// module can end up attached to an index that no longer exists. Nothing in the
// mixer represents it, so there is no item to right-click and toggle off -- but
// it keeps routing audio. These helpers find and unload them.

// Source indices currently present in the mixer.
function liveSourceIds(sourceModelList) {
	var ids = []
	for (var m = 0; m < sourceModelList.length; m++) {
		var model = sourceModelList[m]
		for (var i = 0; i < model.count; i++) {
			var obj = model.get(i)
			if (obj && typeof obj.index === 'number' && ids.indexOf(obj.index) === -1) {
				ids.push(obj.index)
			}
		}
	}
	return ids
}

// Modules whose source is not among the live ones.
function findOrphanedModules(sourceModelList) {
	var live = liveSourceIds(sourceModelList)
	var orphans = []
	for (var i = 0; i < loadedModules.length; i++) {
		var mod = loadedModules[i]
		if (live.indexOf(mod.sourceId) === -1) {
			orphans.push(mod)
		}
	}
	return orphans
}

function orphanedModuleCount(sourceModelList) {
	return findOrphanedModules(sourceModelList).length
}

function unloadOrphanedModules(sourceModelList) {
	var orphans = findOrphanedModules(sourceModelList)
	for (var i = 0; i < orphans.length; i++) {
		console.log('unloadOrphanedModules: unloading', orphans[i].name,
			orphans[i].id, 'bound to missing source', orphans[i].sourceId)
		executable.exec('pactl unload-module ' + orphans[i].id)
	}
	if (orphans.length > 0) {
		syncModuleIds(executable)
	}
	return orphans.length
}

function getSourceProperty(pulseObject, key, defaultValue) {
	var ids = findModuleIds(pulseObject.index, key)
	if (ids.length > 0) {
		return ids[0]
	}
	// Fall back to the proplist, for a real PulseAudio server where the older
	// pacmd-based bookkeeping still works.
	return getProperty(pulseObject, key, defaultValue)
}

// Unload every module of this type bound to the source, then re-sync.
function disableModulesFor(pulseObject, key) {
	var ids = findModuleIds(pulseObject.index, key)
	var proplistId = getProperty(pulseObject, key, -1)
	if (proplistId >= 0 && ids.indexOf(proplistId) === -1) {
		ids.push(proplistId)
	}
	if (ids.length === 0) {
		console.log('disableModulesFor: nothing loaded for source', pulseObject.index, key)
		return
	}
	for (var i = 0; i < ids.length; i++) {
		console.log('disableModule.command pactl unload-module', ids[i])
		executable.exec('pactl unload-module ' + ids[i])
	}
	syncModuleIds(executable)
}

function disableModule(moduleId) {
	var command = 'pactl unload-module ' + moduleId
	console.log('disableModule.command', command)
	executable.exec(command)
	syncModuleIds(executable)
}

function hasIdProperty(pulseObject, key) {
	return getProperty(pulseObject, key, -1) >= 0
}

// module-loopback
// https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Modules/#module-loopback
// We use source.properties['loopback.module_id'] != -1 serialize the state.
function getLoopbackModuleId(pulseObject) {
	return getSourceProperty(pulseObject, 'loopback.module_id', -1)
}
function hasLoopbackModuleId(pulseObject) {
	return getLoopbackModuleId(pulseObject) >= 0
}
function toggleModuleLoopback(pulseObject) {
	if (hasLoopbackModuleId(pulseObject)) {
		disableModulesFor(pulseObject, 'loopback.module_id')
	} else {
		enableModuleLoopback(pulseObject.index)
	}
}

function enableModuleLoopback(sourceId) {
	var command = 'pactl load-module module-loopback'
	command += ' latency_msec=1'
	command += ' source=' + sourceId
	command += ' source_output_properties="loopback.source=' + sourceId + '"'
	command += ' sink_input_properties="loopback.source=' + sourceId + '"'
	console.log('enableModuleLoopback.command', command)
	var callback = loadModuleLoopbackCallback.bind(null, sourceId)
	executable.execAwait(command, callback)
}

function loadModuleLoopbackCallback(sourceId, command, exitCode, exitStatus, stdout, stderr) {
	console.log('LoopbackCallback.sourceId', sourceId)
	if (exitCode !== 0) {
		console.log('enableModuleLoopback failed:', stderr)
		return
	}
	// Don't trust the printed id; re-read the authoritative module list.
	syncModuleIds(executable)
}


// module-echo-cancel
// https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Modules/#module-echo-cancel
// https://github.com/pulseaudio/pulseaudio/blob/master/src/modules/echo-cancel/module-echo-cancel.c
// We use source.properties['echo_cancel.module_id'] != -1 serialize the state.
function getEchoCancelModuleId(pulseObject) {
	return getSourceProperty(pulseObject, 'echo_cancel.module_id', -1)
}
function hasEchoCancelModuleId(pulseObject) {
	return getEchoCancelModuleId(pulseObject) >= 0
}
function toggleModuleEchoCancel(pulseObject) {
	var moduleId = getEchoCancelModuleId(pulseObject)
	console.log('toggleModuleEchoCancel.moduleId', moduleId)
	if (moduleId >= 0) {

		// If the generated stream has loopback enabled, we need to...
		if (true) {
			// ... disable the other stream first.
			var loopbackedStream = main.getStream(filteredSourceModel, function(stream) {
				// console.log('findStream', getProperty(stream, 'echo_cancel.source', -1), pulseObject.index, hasLoopbackModuleId(stream))
				return getProperty(stream, 'echo_cancel.source', -1) == pulseObject.index // The generated echo cancelled source (microphone)
					&& hasLoopbackModuleId(stream) // which also has loopback enabled
			})
			console.log('toggleModuleEchoCancel.loopbackedStream', loopbackedStream)
			if (loopbackedStream) {
				var loopbackModuleId = getLoopbackModuleId(loopbackedStream)
				console.log('toggleModuleEchoCancel.loopbackModuleId', loopbackModuleId)
				if (loopbackModuleId >= 0) {
					disableModule(loopbackModuleId)
					// We don't need to block execution, since if echo cancel is disabled first
					// the loopback will attach itself to the microphone directly.
					// We should block execution if someone complains a noise when cancelling both.
				}
			}
		} else {
			// ... move the "loopback.module_id" to the current stream
			// Since the loopback will automatically attach itself to the echo cancelled source (this stream)
			// TODO: 
		}
		

		disableModulesFor(pulseObject, 'echo_cancel.module_id')
	} else {
		enableModuleEchoCancel(pulseObject.index)
	}
}

function enableModuleEchoCancel(sourceId) {
	var command = 'pactl load-module module-echo-cancel'
	command += ' source_master=' + sourceId
	command += ' source_properties="echo_cancel.source=' + sourceId + '"'
	command += ' sink_properties="echo_cancel.source=' + sourceId + '"'
	// command += ' adjust_threshold="0"'
	command += ' aec_method="webrtc"'
	// command += ' aec_args="drift_compensation=0"'

	// command += " source_properties=echo_cancel.source=\\'" + sourceId + "\\'application.id=\\'org.PulseAudio.pavucontrol\\'"
	// command += " sink_properties=echo_cancel.source=\\'" + sourceId + "\\'application.id=\\'org.PulseAudio.pavucontrol\\'"
	
	console.log('enableModuleEchoCancel.command', command)
	var callback = loadModuleEchoCancelCallback.bind(null, sourceId)
	executable.execAwait(command, callback)
}

function loadModuleEchoCancelCallback(sourceId, command, exitCode, exitStatus, stdout, stderr) {
	if (exitCode !== 0) {
		console.log('enableModuleEchoCancel failed:', stderr)
		return
	}
	// Don't trust the printed id; re-read the authoritative module list.
	syncModuleIds(executable)
}
