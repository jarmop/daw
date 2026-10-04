#+feature dynamic-literals

package daw

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import ma "vendor:miniaudio"

Waveform :: enum {
	Sine,
	Square,
	Triangle,
	Sawtooth,
}

WaveformFunc :: proc "c" (phase: f32) -> f32

waveform_function_map := map[Waveform]WaveformFunc {
	.Sine     = get_sine_sample,
	.Square   = get_square_sample,
	.Triangle = get_triangle_sample,
	.Sawtooth = get_sawtooth_sample,
}

selected_waveform: Waveform = .Sine

sample_rate :: 48000
ms_per_frame :: 1000.0 / sample_rate

// frequency: f32 = 440
frequency: f32 = 261.63
max_frequency: f32 = 1000
amplitude: f32 = 0.2
max_amplitude: f32 = 1.0
phase: f32 = 0
playing := false

EnvelopeSegment :: struct {
	duration:   f32,
	amp_target: f32,
}

envelope_max_duration: f32 = 400

envelope_i := 0

play_sound :: proc() {
	// note := "C"
	// octave := 4
	// midi := 0 // C-1
	// midi := 24 // C1
	midi := 60 // C4
	// midi := 60 // C8
	// midi := 127 // G9

	frequency = midi_to_freq(midi)

	update_envelope()

	config := ma.device_config_init(ma.device_type.playback)

	config.playback.format = ma.format.f32
	config.playback.channels = 1
	config.sampleRate = u32(sample_rate)
	// config.dataCallback = data_callback_realtime
	config.dataCallback = data_callback_buffered

	device: ma.device

	result := ma.device_init(nil, &config, &device)
	if result != .SUCCESS {
		fmt.println("Failed to initialize audio device")
		return
	}

	result = ma.device_start(&device)
	if result != .SUCCESS {
		fmt.println("Failed to start audio device")
		ma.device_uninit(&device)
		return
	}

	buf: [256]byte
	os.read(os.stdin, buf[:])

	ma.device_uninit(&device)
}

envelope: []EnvelopeSegment = {{duration = 20}, {duration = 50}, {duration = 200}, {duration = 20}}

envelope_sus_amp_ratio: f32 = 0.5

update_envelope :: proc() {
	sustain_amplitude := amplitude * envelope_sus_amp_ratio
	envelope[0].amp_target = amplitude
	envelope[1].amp_target = sustain_amplitude
	envelope[2].amp_target = sustain_amplitude
	envelope[3].amp_target = 0
}

frame_amplitude: f32 = 0
segment: EnvelopeSegment
segment_timer: f32 = 0
amp_increment_per_frame: f32

data_callback_realtime :: proc "c" (
	device: ^ma.device,
	output: rawptr,
	input: rawptr,
	frame_count: u32,
) {
	context = runtime.default_context()

	samples := cast([^]f32)output
	for i in 0 ..< int(frame_count) {
		if !playing {
			samples[i] = 0
			continue
		}

		if segment_timer >= segment.duration {
			if envelope_i == len(envelope) - 1 {
				toggle_playback()
				samples[i] = 0
				continue
			} else {
				envelope_i += 1
				segment, segment_timer, amp_increment_per_frame = segment_start(envelope_i)
			}
		}

		samples[i] = waveform_function_map[selected_waveform](phase) * frame_amplitude

		phase += frequency / sample_rate
		if phase >= 1 {
			phase -= 1
		}

		frame_amplitude += amp_increment_per_frame

		segment_timer += ms_per_frame
	}
}

sample_i := 0
generated_samples: []f32

data_callback_buffered :: proc "c" (
	device: ^ma.device,
	output: rawptr,
	input: rawptr,
	frame_count: u32,
) {
	context = runtime.default_context()

	samples := cast([^]f32)output
	for i in 0 ..< int(frame_count) {
		if !playing {
			samples[i] = 0
			continue
		}

		samples[i] = generated_samples[sample_i]
		sample_i += 1

		if sample_i == len(generated_samples) {
			sample_i = 0
			playing = false
		}
	}
}

get_sine_sample :: proc "c" (phase: f32) -> f32 {
	return math.sin(phase * 2 * math.PI)
}

get_square_sample :: proc "c" (phase: f32) -> f32 {
	return (phase < 0.5 ? 1 : -1) * 0.4
}

get_triangle_sample :: proc "c" (phase: f32) -> f32 {
	return 2 / math.PI * math.asin(get_sine_sample(phase))
}

get_sawtooth_sample :: proc "c" (phase: f32) -> f32 {
	return (phase * 2 - 1) * 0.4
}

toggle_playback :: proc() {
	playing = !playing
	if playing {
		generated_samples = generate_samples()
		envelope_i = 0
		frame_amplitude = 0
		segment, segment_timer, amp_increment_per_frame = segment_start(envelope_i)
	}
}

segment_start :: proc(envelope_i: int) -> (EnvelopeSegment, f32, f32) {
	segment := envelope[envelope_i]
	segment_timer: f32 = 0
	amp_start: f32 = envelope_i == 0 ? 0 : envelope[envelope_i - 1].amp_target
	amp_end := segment.amp_target
	amp_d := amp_end - amp_start
	amp_increment_per_ms := amp_d / segment.duration
	amp_increment_per_frame := amp_increment_per_ms / 48

	return segment, segment_timer, amp_increment_per_frame
}

midi_to_freq :: proc(midi: int) -> f32 {
	a4: f32 = 440
	return a4 * math.pow_f32(2, (f32(midi) - 69) / 12)
}

music_keys: []string = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

midi_to_text :: proc(midi: int) {
	octave := midi / 12 - 1
	scale_i := midi % 12
	fmt.println(music_keys[scale_i], octave)
}
