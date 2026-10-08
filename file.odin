package daw

import "core:fmt"
import "core:os"
import "core:slice"

SavedTrackItem :: struct {
	midi:     int,
	start:    f32,
	duration: f32,
	track_i:  int,
}

tracks_filename := "data/tracks"

save_tracks :: proc(tracks: Tracks) {
	track_items_count := 0
	for track_items in tracks {
		track_items_count += len(track_items)
	}

	all_track_items := make([]SavedTrackItem, track_items_count)
	for track_items, track_i in tracks {
		for item, i in track_items {
			all_track_items[i] = {
				midi     = item.midi,
				start    = item.start,
				duration = item.duration,
				track_i  = track_i,
			}
		}
	}

	bytes := slice.to_bytes(all_track_items[:])
	write_err := os.write_entire_file(tracks_filename, bytes)
	if (write_err != nil) {
		fmt.println(write_err)
	} else {
		fmt.printfln("saved %d bytes", len(bytes))
	}
}

load_tracks :: proc() -> Tracks {
	bytes, read_err := os.read_entire_file(tracks_filename, context.allocator)
	defer delete(bytes)

	if (read_err != nil) {
		fmt.println(read_err)
	}

	all_track_items := slice.reinterpret([]SavedTrackItem, bytes)

	track_count := 0
	for item in all_track_items {
		track_count = max(track_count, item.track_i + 1)
	}

	tracks := make(Tracks, track_count)
	for item in all_track_items {
		append(
			&tracks[item.track_i],
			TrackItem{midi = item.midi, start = item.start, duration = item.duration},
		)
	}

	return tracks
}
