package daw

import "core:fmt"
import "core:math"
import "core:slice"
import gl "vendor:OpenGL"

// Track :: struct {
// 	// attack:            f32,
// 	// decay:             f32,
// 	// release:           f32,
// 	// amplitude:         f32,
// 	// sustain_amplitude: f32,
// 	items: struct {
// 		// sustain = duration - (a+d+r)
// 		duration:  f32,
// 		frequency: f32,
// 	},
// }

TrackItem :: struct {
	midi:      int,
	frequency: f32,
	start:     f32,
	duration:  f32,
}

track1_items: []TrackItem
track2_items: []TrackItem
track3_items: []TrackItem
tracks: [4][]TrackItem

track_vao: u32
track_vbo: u32
track_vertices: []ColorVertex

tracks_size: Vec2
tracks_pos: Vec2

track_px_per_ms: f32 = 0.1

notes_vao: u32
notes_vbo: u32
notes_vertices: [dynamic]ColorVertex

track_init :: proc() {
	gl.GenVertexArrays(1, &track_vao)
	gl.BindVertexArray(track_vao)
	vbo_color_init(&track_vbo)

	gl.GenVertexArrays(1, &notes_vao)
	gl.BindVertexArray(notes_vao)
	vbo_color_init(&notes_vbo)
}

track_draw :: proc() {
	gl.UseProgram(color_program)

	shader_set_vec2(color_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "mesh_pos", tracks_pos)

	// --------------
	// Tracks
	// --------------
	gl.BindVertexArray(track_vao)
	gl.DrawArrays(gl.LINES, 0, i32(len(track_vertices)))

	// --------------
	// Notes
	// --------------
	gl.BindVertexArray(notes_vao)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(notes_vertices)))
}

track_vertices_update :: proc() {
	step_length_ms: f32 = 100
	step_length_px: f32 = step_length_ms * track_px_per_ms
	tracks_duration: f32 = 0
	for track_items in tracks {
		tracks_duration = max(get_track_duration(track_items), tracks_duration)
	}
	// track_steps := int(tracks_duration / step_length_ms + 0.5)
	// tracks_size = {f32(track_steps) * step_length_px, f32(len(tracks)) * line_height}
	tracks_size = {f32(WINDOW_WIDTH) - 2 * padding, f32(len(tracks)) * line_height}
	track_steps := int(tracks_size.x / step_length_px)
	vertex_count_steps := 2 * (track_steps + 1)
	vertex_count_stylus := 2
	track_vertices = make([]ColorVertex, vertex_count_steps + vertex_count_stylus)
	defer delete(track_vertices)

	i := 0

	// ---------------
	// Steps
	// ---------------
	p: Vec2 = {0, 0}
	step_color: Vec4 = {1, 1, 1, 0.1}
	step_color2: Vec4 = {1, 1, 1, 0.3}
	for s in 0 ..= track_steps {
		p.x = f32(s) * step_length_px
		track_vertices[i].pos = p
		track_vertices[i + 1].pos = p + {0, tracks_size.y}
		track_vertices[i + 1].color = step_color

		if s % 10 == 0 {
			track_vertices[i].color = step_color2
			track_vertices[i + 1].color = step_color2
			text_pos := tracks_pos + p - {4, 4}
			text_add_vertices(fmt.tprint(s / 10), text_pos, 20)
		} else {
			track_vertices[i].color = step_color
			track_vertices[i + 1].color = step_color
		}

		i += 2
	}

	// ---------------
	// Stylus
	// ---------------
	stylus_color: Vec4 = {1, 0, 0, 0.4}
	progress := f32(sample_i) * ms_per_frame * track_px_per_ms
	track_vertices[i].pos = {progress, 0}
	track_vertices[i].color = stylus_color
	track_vertices[i + 1].pos = {progress, tracks_size.y}
	track_vertices[i + 1].color = stylus_color

	vbo_color_update(&track_vbo, track_vertices[:])

	// ---------------
	// Notes
	// ---------------
	clear(&notes_vertices)
	track_pos_abs := tracks_pos
	track_pos_rel: Vec2 = {0, 0}
	i = 0
	selected_note_color: Vec4 = {1, 1, 1, 0.2}
	note_color: Vec4 = {1, 1, 1, 0.08}
	for track_items, track_i in tracks {
		for item, item_i in track_items {
			note_pos_abs := track_pos_abs + {item.start * track_px_per_ms, 0}
			text_pos := note_pos_abs + {0, line_height - 3}
			note_width := item.duration * track_px_per_ms
			text_add_vertices(midi_to_text(item.midi), text_pos, note_width)

			note_pos_rel := track_pos_rel + {item.start * track_px_per_ms, 0}
			color: Vec4 =
				track_i == selected_track_i && item_i == selected_track_item_i ? selected_note_color : note_color
			quad := make_quad_color(note_width, line_height, note_pos_rel.x, note_pos_rel.y, color)
			append(&notes_vertices, ..quad[:])
			i += 1
		}
		track_pos_abs.y += line_height
		track_pos_rel.y += line_height
	}

	vbo_color_update(&notes_vbo, notes_vertices[:])
}

get_tracks_duration :: proc(tracks: [][]TrackItem) -> f32 {
	tracks_duration: f32 = 0
	for track_items in tracks {
		tracks_duration = max(get_track_duration(track_items), tracks_duration)
	}
	return tracks_duration
}

get_track_duration :: proc(track: []TrackItem) -> f32 {
	if len(track) == 0 {
		return 0
	}
	last_item := track[len(track) - 1]
	return last_item.start + last_item.duration
}

item_is_valid :: proc(track_items: []TrackItem, item_i: int) -> bool {
	item1 := track_items[item_i]
	item1_start := item1.start
	item1_end := item1.start + item1.duration
	for item2, i in track_items {
		if i == item_i {
			continue
		}

		item2_start := item2.start
		item2_end := item2.start + item2.duration
		is_fully_before := item1_end < item2_start
		is_fully_after := item1_start > item2_end

		if is_fully_before || is_fully_after {
			continue
		}

		return false // invalid
	}
	return true
}

sort_tracks :: proc() {
	for track_items, track_i in tracks {
		slice.sort_by(track_items, compare_track_items)
	}

	// for track_items, track_i in tracks {
	// 	for item, item_i in track_items {
	// 		fmt.println(item.midi)
	// 	}
	// }
}

compare_track_items :: proc(lhs, rhs: TrackItem) -> bool {
	return lhs.start < rhs.start
}
