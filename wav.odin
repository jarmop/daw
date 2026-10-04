package daw

import "core:fmt"
import ma "vendor:miniaudio"

encoder: ma.encoder

wav_save :: proc() {
	wav_init()

	frames_written: u64
	frames := generate_samples()
	result := ma.encoder_write_pcm_frames(
		&encoder,
		raw_data(frames),
		u64(len(frames)),
		&frames_written,
	)
	if result != ma.result.SUCCESS {
		fmt.println("wav save fail:", result)
	} else {
		fmt.printfln("wrote %d frames", frames_written)
	}

	ma.encoder_uninit(&encoder)
}

// According to the miniaudio documentation, s16 (16-bit signed integer) "seems
// to be the most widely supported format".
wav_init :: proc() {
	config := ma.encoder_config_init(ma.encoding_format.wav, ma.format.f32, 1, sample_rate)
	result := ma.encoder_init_file("test.wav", &config, &encoder)
	if result != ma.result.SUCCESS {
		fmt.println("wav init fail:", result)
	}
}

generate_samples :: proc() -> []f32 {
	total_duration: f32 = 0
	for e in envelope {
		total_duration += e.duration
	}

	samples_count := int(frames_per_ms * total_duration)
	samples := make([]f32, samples_count)
	phase: f32 = 0
	frame_amplitude: f32 = 0

	envelope_i = 0
	segment, segment_timer, amp_increment_per_frame := segment_start(envelope, envelope_i)

	for i in 0 ..< samples_count {
		if segment_timer >= segment.duration {
			if envelope_i == len(envelope) - 1 {
				samples[i] = 0
				continue
			} else {
				envelope_i += 1
				segment, segment_timer, amp_increment_per_frame = segment_start(
					envelope,
					envelope_i,
				)
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

	return samples
}
