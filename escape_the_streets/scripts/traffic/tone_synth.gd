class_name ToneSynth
extends AudioStreamPlayer3D
## Tiny procedural sound maker so the prototype has a siren, horn and bike bell
## without audio files. Replace with real samples (AudioStreamPlayer3D + .ogg) later.
## Hearing a siren before seeing it is part of what children should learn.

enum Pattern { NONE, SIREN, HORN, BELL }

const RATE := 22050.0

var pattern := Pattern.NONE
## Free this node when a one-shot sound has finished.
var free_when_done := false

var _t := 0.0
var _phase := 0.0
var _duration := -1.0
var _playback: AudioStreamGeneratorPlayback


static func one_shot(parent: Node3D, p: Pattern, seconds: float) -> void:
	var synth := ToneSynth.new()
	synth.free_when_done = true
	parent.add_child(synth)
	synth.play_pattern(p, seconds)


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.12
	stream = gen
	unit_size = 10.0
	max_distance = 140.0
	volume_db = -6.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func play_pattern(p: Pattern, seconds: float = -1.0) -> void:
	pattern = p
	_t = 0.0
	_duration = seconds


func stop_pattern() -> void:
	pattern = Pattern.NONE


func _process(_delta: float) -> void:
	if _playback == null:
		if free_when_done and _t >= 0.0:
			queue_free()
		return
	var frames := _playback.get_frames_available()
	for i in frames:
		var s := 0.0
		if pattern != Pattern.NONE:
			s = _sample()
			_t += 1.0 / RATE
			if _duration > 0.0 and _t >= _duration:
				pattern = Pattern.NONE
		_playback.push_frame(Vector2(s, s))
	if free_when_done and pattern == Pattern.NONE:
		queue_free()


func _sample() -> float:
	match pattern:
		Pattern.SIREN:
			# Two-tone siren, switching every 0.6 s.
			var f := 450.0 if fmod(_t, 1.2) < 0.6 else 600.0
			_phase = fmod(_phase + f / RATE, 1.0)
			return (0.6 * sin(TAU * _phase) + 0.25 * signf(sin(TAU * _phase))) * 0.5
		Pattern.HORN:
			_phase = fmod(_phase + 392.0 / RATE, 1.0)
			var saw := _phase * 2.0 - 1.0
			return saw * 0.35 * clampf(_t * 30.0, 0.0, 1.0)
		Pattern.BELL:
			# "Tring tring": two strikes with a fast decay.
			var local := fmod(_t, 0.22)
			var env := exp(-local * 18.0) if _t < 0.44 else 0.0
			_phase = fmod(_phase + 2400.0 / RATE, 1.0)
			return sin(TAU * _phase) * env * 0.5
	return 0.0
