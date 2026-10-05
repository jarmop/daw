package daw

import "core:fmt"
import ma "vendor:miniaudio"

encoder: ma.encoder

wav_save :: proc() {
	wav_init()

	frames_written: u64
	// frames := generate_envelope_samples(envelope, frequency)
	frames := generate_track_samples(track_items)
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
