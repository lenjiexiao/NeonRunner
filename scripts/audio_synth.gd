class_name NeonAudio
extends RefCounted
## 用代码直接合成 16 位 PCM 音效，整个游戏零外部素材。

static func tone(f0: float, f1: float, dur: float, vol: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var n := maxi(1, int(dur * rate))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(n))
		phase += TAU * f / float(rate)
		var s := 0.0
		match kind:
			"square":
				s = 1.0 if fmod(phase, TAU) < PI else -1.0
			"saw":
				s = fmod(phase, TAU) / PI - 1.0
			"noise":
				s = randf() * 2.0 - 1.0
			_:
				s = sin(phase)
		var env := pow(1.0 - float(i) / float(n), 1.5)
		bytes.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav
