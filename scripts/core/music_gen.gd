class_name MusicGen
extends RefCounted
## Tiny seeded chiptune composer. Produces an 8-bar loop (AABA phrasing) with
## lead, bass, arpeggio and drums from {tempo, root, scale, seed}. Each arena
## has its own seed so every stage gets a distinct (but consistent) theme.

const SCALES := {
	"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10],
	"dorian": [0, 2, 3, 5, 7, 9, 10], "harmonic": [0, 2, 3, 5, 7, 8, 11],
	"pentatonic": [0, 2, 4, 7, 9], "blues": [0, 3, 5, 6, 7, 10], "lydian": [0, 2, 4, 6, 7, 9, 11],
}
const PROGRESSIONS := [[0, 5, 3, 4], [0, 3, 4, 0], [0, 4, 5, 3], [5, 3, 0, 4], [0, 6, 5, 4], [0, 2, 3, 4], [0, 3, 0, 4]]


static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


static func _deg(scale: Array, root: int, degree: int) -> int:
	var l := scale.size()
	var octave := floori(degree / float(l))
	return root + scale[posmod(degree, l)] + octave * 12


static func render(p: Dictionary, sr: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1)) * 7919 + 13
	var tempo: float = p.get("tempo", 120)
	var root: int = p.get("root", 57)
	var scale: Array = SCALES.get(p.get("scale", "minor"), SCALES["minor"])
	var bars := 8
	var beat := 60.0 / tempo
	var total := bars * 4 * beat
	var n := int(total * sr)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var prog: Array = PROGRESSIONS[rng.randi_range(0, PROGRESSIONS.size() - 1)]
	var notes: Array = []  # [start_s, dur_s, freq, wave, vol]
	var sixteenth := beat / 4.0
	# Lead motifs: A and B, each 2 bars of 16th slots.
	var motifs := {}
	for key in ["A", "B"]:
		var m: Array = []
		var deg := rng.randi_range(0, 4)
		var slot := 0
		while slot < 32:
			var lens := [2, 2, 2, 4, 1, 3, 4, 6]
			var L: int = lens[rng.randi_range(0, lens.size() - 1)]
			if rng.randf() < 0.18:
				m.append([slot, L, -999])
			else:
				deg += rng.randi_range(-2, 2)
				deg = clampi(deg, -2, 9)
				m.append([slot, L, deg])
			slot += L
		motifs[key] = m
	var form := ["A", "A", "B", "A"]
	for phrase in 4:
		var mot: Array = motifs[form[phrase]]
		var base_bar := phrase * 2
		for ev in mot:
			if ev[2] == -999:
				continue
			var bar: int = base_bar + int(ev[0]) / 16
			var chord: int = prog[bar % 4]
			var d: int = ev[2] + chord
			if phrase == 1 and ev[0] >= 24:
				d += 2
			var st: float = (base_bar * 16 + ev[0]) * sixteenth
			if st >= total:
				continue
			notes.append([st, minf(ev[1] * sixteenth * 0.92, total - st), _midi(_deg(scale, root + 12, d)), 1, 0.13])
	# Bass + arp + drums per bar
	var bass_pat := [0, 0, 4, 0, 7, 0, 4, 0] if rng.randf() < 0.5 else [0, -999, 0, 4, 0, -999, 7, 4]
	for bar in bars:
		var chord: int = prog[bar % 4]
		for e in 8:
			var bp: int = bass_pat[e]
			if bp == -999:
				continue
			var semis := _deg(scale, root - 12, chord) + (0 if bp == 0 else (7 if bp == 4 else 12))
			notes.append([(bar * 8 + e) * beat / 2.0, beat / 2.0 * 0.85, _midi(semis), 2, 0.2])
		if bar >= 4 or rng.randf() < 0.5:
			for s in 16:
				var tone_i: int = [0, 2, 4, 7][s % 4]
				notes.append([(bar * 16 + s) * sixteenth, sixteenth * 0.6, _midi(_deg(scale, root, chord + (tone_i if tone_i < 7 else 7))), 3, 0.045])
		for bt in 4:
			var t0 := (bar * 4 + bt) * beat
			if bt == 0 or bt == 2:
				notes.append([t0, 0.09, 110.0, 4, 0.4])
			if bt == 1 or bt == 3:
				notes.append([t0, 0.1, 0.0, 5, 0.18])
			notes.append([t0, 0.03, 0.0, 6, 0.05])
			notes.append([t0 + beat / 2.0, 0.03, 0.0, 6, 0.04])
		if bar % 2 == 1 and rng.randf() < 0.6:
			notes.append([(bar * 4 + 3.5) * beat, 0.08, 0.0, 5, 0.12])
	# Render
	var noise_y := 0.0
	for nt in notes:
		var s0 := int(nt[0] * sr)
		var cnt := int(nt[1] * sr)
		var f: float = nt[2]
		var wave: int = nt[3]
		var vol: float = nt[4]
		var ph := 0.0
		var inc := f / sr
		for i in cnt:
			var idx := s0 + i
			if idx >= n:
				break
			var t := float(i) / cnt
			var v := 0.0
			match wave:
				1:
					ph += inc
					v = (1.0 if fmod(ph, 1.0) < 0.25 else -1.0) * (1.0 - t * 0.6) * minf(1.0, i / 60.0)
				2:
					ph += inc
					var q := fmod(ph, 1.0)
					v = (4.0 * absf(q - 0.5) - 1.0) * (1.0 - t * 0.3)
				3:
					ph += inc
					v = (1.0 if fmod(ph, 1.0) < 0.125 else -1.0) * (1.0 - t)
				4:
					ph += (110.0 * pow(0.35, t)) / sr
					v = sin(ph * TAU) * (1.0 - t)
				5:
					noise_y += 0.6 * (randf_range(-1.0, 1.0) - noise_y)
					v = noise_y * pow(1.0 - t, 2.0)
				6:
					var x := randf_range(-1.0, 1.0)
					v = (x - noise_y * 0.2) * (1.0 - t)
			buf[idx] += v * vol
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = sr
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
