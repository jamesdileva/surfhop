extends SceneTree

## Synthesizes placeholder SFX/music as PCM WAV files under assets/audio/.
## Run: godot --headless --path . --script res://tools/generate_sfx.gd

const RATE := 44100


func _append_le16(out: PackedByteArray, v: int) -> void:
	out.append(v & 0xFF)
	out.append((v >> 8) & 0xFF)


func _append_le32(out: PackedByteArray, v: int) -> void:
	for i in 4:
		out.append((v >> (8 * i)) & 0xFF)


func _write_wav(path: String, samples: PackedFloat32Array) -> void:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in samples.size():
		pcm.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	_append_le32(out, 36 + pcm.size())
	out.append_array("WAVEfmt ".to_ascii_buffer())
	_append_le32(out, 16)
	_append_le16(out, 1)
	_append_le16(out, 1)
	_append_le32(out, RATE)
	_append_le32(out, RATE * 2)
	_append_le16(out, 2)
	_append_le16(out, 16)
	out.append_array("data".to_ascii_buffer())
	_append_le32(out, pcm.size())
	out.append_array(pcm)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
	print("%s (%d samples)" % [path.get_file(), samples.size()])


## Simple one-pole low-pass for shaping noise.
func _lowpass(samples: PackedFloat32Array, alpha: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var acc := 0.0
	for i in samples.size():
		acc += alpha * (samples[i] - acc)
		out[i] = acc
	return out


func _initialize() -> void:
	var n: int
	var s := PackedFloat32Array()

	# jump: rising sine sweep, fast decay
	n = int(0.18 * RATE)
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var freq := lerpf(180.0, 340.0, float(i) / n)
		s[i] = sin(t * freq * TAU) * exp(-t * 14.0)
	_write_wav("res://assets/audio/sfx/jump.wav", s)

	# land: low-passed noise thud, sharp decay
	n = int(0.15 * RATE)
	s.resize(n)
	var noise := PackedFloat32Array()
	noise.resize(n)
	for i in n:
		noise[i] = randf_range(-1.0, 1.0)
	noise = _lowpass(noise, 0.12)
	for i in n:
		var t := float(i) / RATE
		s[i] = noise[i] * 2.2 * exp(-t * 22.0)
	_write_wav("res://assets/audio/sfx/land.wav", s)

	# footsteps: two short filtered clicks
	for variant: int in [0, 1]:
		n = int(0.07 * RATE)
		s.resize(n)
		noise.resize(n)
		for i in n:
			noise[i] = randf_range(-1.0, 1.0)
		noise = _lowpass(noise, 0.30 if variant == 0 else 0.18)
		for i in n:
			var t := float(i) / RATE
			s[i] = noise[i] * 1.8 * exp(-t * 40.0)
		_write_wav("res://assets/audio/sfx/footstep_%s.wav" % ["a" if variant == 0 else "b"], s)

	# surf_loop: loopable airy noise with slow amplitude swell
	n = int(1.2 * RATE)
	s.resize(n)
	noise.resize(n)
	for i in n:
		noise[i] = randf_range(-1.0, 1.0)
	noise = _lowpass(noise, 0.08)
	var fade_n := int(0.05 * RATE)
	for i in n:
		var t := float(i) / n  # 0..1 across the loop
		var swell := 0.7 + 0.3 * sin(t * TAU)
		var edge := minf(float(i) / fade_n, minf(float(n - i) / fade_n, 1.0))
		s[i] = noise[i] * 1.6 * swell * edge
	_write_wav("res://assets/audio/sfx/surf_loop.wav", s)

	# finish: three-note chime arpeggio
	n = int(0.95 * RATE)
	s.resize(n)
	var notes := [[440.0, 0.0], [554.0, 0.22], [659.0, 0.44]]
	for note in notes:
		var start_i := int(note[1] * RATE)
		for i in range(start_i, n):
			var t := float(i - start_i) / RATE
			s[i] += sin(t * note[0] * TAU) * exp(-t * 5.0) * 0.5
	_write_wav("res://assets/audio/sfx/finish.wav", s)

	# ui_click: tiny tick
	n = int(0.03 * RATE)
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(t * 1100.0 * TAU) * exp(-t * 90.0) * 0.6
	_write_wav("res://assets/audio/sfx/ui_click.wav", s)

	# achievement: bright two-note fanfare, distinct from the finish chime
	n = int(0.8 * RATE)
	s.resize(n)
	var ach_notes := [[659.0, 0.0], [987.77, 0.16]]
	for note in ach_notes:
		var start_i := int(note[1] * RATE)
		for i in range(start_i, n):
			var t := float(i - start_i) / RATE
			s[i] += sin(t * note[0] * TAU) * exp(-t * 4.5) * 0.45 \
				+ sin(t * note[0] * 2.0 * TAU) * exp(-t * 6.0) * 0.12
	_write_wav("res://assets/audio/sfx/achievement.wav", s)

	# menu music placeholder: 9.6s loopable pad, Am - F - C - G feel
	var chords := [
		[220.0, 261.63, 329.63],
		[174.61, 220.0, 261.63],
		[130.81, 164.81, 196.0],
		[196.0, 246.94, 293.66],
	]
	var chord_len := 2.4
	n = int(chord_len * chords.size() * RATE)
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var chord_idx := int(t / chord_len) % chords.size()
		var local_t := fmod(t, chord_len)
		var v := 0.0
		for freq_v in chords[chord_idx]:
			v += sin(local_t * freq_v * TAU) * 0.16
			v += sin(local_t * freq_v * 2.003 * TAU) * 0.06  # slight detune shimmer
		var swell := 0.75 + 0.25 * sin(local_t / chord_len * PI)
		s[i] = v * swell
	# crossfade tail into head for seamless looping
	var xf := int(0.1 * RATE)
	for i in xf:
		var blend := float(i) / xf
		var tail := s[n - xf + i]
		s[i] = s[i] * blend + tail * (1.0 - blend)
	_write_wav("res://assets/audio/music/menu_placeholder.wav", s)

	print("ALL SFX GENERATED")
	quit()
