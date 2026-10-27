class_name AudioSynth
extends RefCounted
## Runtime PCM so the web export does not depend on imported wav files.
## Streams are built once at boot from a fixed seed, not from gameplay RNG.


static func bank() -> Dictionary:
	return {
		"ui": _tone(740.0, 0.045, 0.35, "sine", 3),
		"connect": _sweep(420.0, 760.0, 0.16, 0.4, 5),
		"reject": _tone(110.0, 0.14, 0.45, "square", 7),
		"hurt": _tone(180.0, 0.12, 0.5, "noise", 11),
		"evade": _sweep(280.0, 640.0, 0.09, 0.32, 13),
		"shock": _tone(90.0, 0.08, 0.4, "noise", 17),
		"danger": _tone(196.0, 0.22, 0.35, "square", 19),
		"death": _sweep(360.0, 80.0, 0.4, 0.4, 23),
		"victory": _arp([523.0, 659.0, 784.0, 1046.0], 0.14, 0.32, 29),
		"pickup": _tone(988.0, 0.07, 0.3, "sine", 31),
	}


static func music_loop() -> AudioStreamWAV:
	var rate := 22050
	var dur := 8.0
	var notes: Array = [196.0, 233.0, 220.0, 174.0, 196.0, 146.0, 174.0, 220.0]
	var count := int(rate * dur)
	var peer := _peer(count)
	for i in count:
		var t := float(i) / float(rate)
		var step := int(t / 1.0) % notes.size()
		var freq: float = notes[step]
		var env := 0.55 + 0.45 * sin(TAU * t * 0.5)
		var sample := sin(TAU * freq * t) * 0.22 * env
		sample += sin(TAU * freq * 0.5 * t) * 0.08
		_put(peer, i, sample)
	return _wav(peer.data_array, rate, true)


static func ambience_loop() -> AudioStreamWAV:
	var rate := 22050
	var count := rate * 2
	var peer := _peer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var hold := 0.0
	for i in count:
		hold = lerpf(hold, rng.randf_range(-1.0, 1.0), 0.02)
		var t := float(i) / float(rate)
		var hum := sin(TAU * 55.0 * t) * 0.15
		_put(peer, i, hold * 0.08 + hum)
	return _wav(peer.data_array, rate, true)


static func _tone(freq: float, dur: float, vol: float, kind: String, salt: int) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * dur))
	var peer := _peer(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	for i in count:
		var t := float(i) / float(rate)
		var env := pow(1.0 - t / dur, 1.4)
		var s := sin(TAU * freq * t)
		if kind == "square":
			s = 1.0 if s >= 0.0 else -1.0
		elif kind == "noise":
			s = rng.randf_range(-1.0, 1.0)
		_put(peer, i, s * env * vol)
	return _wav(peer.data_array, rate, false)


static func _sweep(a: float, b: float, dur: float, vol: float, _salt: int) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(rate * dur))
	var peer := _peer(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(a, b, t)
		phase += TAU * freq / float(rate)
		_put(peer, i, sin(phase) * sin(PI * t) * vol)
	return _wav(peer.data_array, rate, false)


static func _arp(notes: Array, step: float, vol: float, _salt: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * step * notes.size())
	var peer := _peer(count)
	for i in count:
		var t := float(i) / float(rate)
		var idx := mini(int(t / step), notes.size() - 1)
		var local := t - float(idx) * step
		var env := pow(1.0 - local / step, 1.2)
		_put(peer, i, sin(TAU * float(notes[idx]) * t) * env * vol)
	return _wav(peer.data_array, rate, false)


static func _put(peer: StreamPeerBuffer, i: int, sample: float) -> void:
	var clamped := int(clampf(sample, -1.0, 1.0) * 32767.0)
	peer.seek(i * 2)
	peer.put_16(clamped)


static func _peer(count: int) -> StreamPeerBuffer:
	var peer := StreamPeerBuffer.new()
	peer.big_endian = false
	peer.resize(count * 2)
	return peer


static func _wav(pcm: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = pcm
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = pcm.size() / 2
	return stream
