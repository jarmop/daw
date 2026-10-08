#+feature dynamic-literals

package daw

import "core:fmt"
import "core:math"
import "core:slice"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

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
	midi:     int,
	start:    f32,
	duration: f32,
}

tracks: [4][dynamic]TrackItem

track_vao: u32
track_vbo: u32
track_vertices: []ColorVertex

tracks_size: Vec2
tracks_pos: Vec2

track_px_per_ms: f32 = 0.1
track_ms_per_px := 1 / track_px_per_ms

notes_vao: u32
notes_vbo: u32
notes_vertices: [dynamic]ColorVertex

track_init_data :: proc() {
	tracks[0] = {
		{midi = 60, start = 0, duration = 2000},
		{midi = 60, start = 3000, duration = 500},
	}
}

track_init_ui :: proc() {
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
		tracks_duration = max(get_track_duration(track_items[:]), tracks_duration)
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

get_tracks_duration :: proc(tracks: [][dynamic]TrackItem) -> f32 {
	tracks_duration: f32 = 0
	for track_items in tracks {
		tracks_duration = max(get_track_duration(track_items[:]), tracks_duration)
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
	item := track_items[item_i]
	item_start := item.start
	item_end := item.start + item.duration

	if item_start >= item_end {
		return false
	}

	for item2, i in track_items {
		if i == item_i {
			continue
		}

		item2_start := item2.start
		item2_end := item2.start + item2.duration
		is_fully_before := item_end < item2_start
		is_fully_after := item_start > item2_end

		if is_fully_before || is_fully_after {
			continue
		}

		return false
	}

	return true
}

sort_tracks :: proc() {
	for track_items, track_i in tracks {
		slice.sort_by(track_items[:], compare_track_items)
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


// ------------------------------------------------
//
//                 WINDOW CALLBACKS
//
// ------------------------------------------------

TrackItemHold :: enum {
	Center,
	Left,
	Right,
}

track_item_hold: TrackItemHold

selected_item_backup: TrackItem

selected_track_i: int = -1
hovered_track_i: int = -1
selected_track_item_i: int = -1
hovered_track_item_i: int = -1

total_diff_ms: f32 = 0

track_key_callback :: proc(key: i32, scancode: int, mode: i32) {
	music_key := 0 // C = 0, C# = 1, B = 11
	octave := 4 // -1 - 9
	midi := (octave + 1) * 12 + music_key

	music_key_scancode_start := 16 // "Q"
	music_key_scancode_end := music_key_scancode_start + 11 // The key after "Å"

	note_selected := selected_track_item_i > -1
	if note_selected {
		selected_note := &tracks[selected_track_i][selected_track_item_i]
		if scancode >= music_key_scancode_start && scancode <= music_key_scancode_end {
			scale_i := scancode - music_key_scancode_start
			midi := (octave + 1) * 12 + scale_i
			selected_note.midi = midi
		} else if key == glfw.KEY_LEFT || key == glfw.KEY_RIGHT {
			movement: f32 = mode == glfw.MOD_SHIFT ? 10 : 1
			selected_note.start += key == glfw.KEY_LEFT ? -movement : movement
		}
	}

	if key == glfw.KEY_SPACE {
		toggle_playback()
	} else if key == glfw.KEY_DELETE && selected_track_item_i > -1 {
		ordered_remove(&tracks[selected_track_i], selected_track_item_i)
		selected_track_item_i = -1
	} else if key == glfw.KEY_S {
		// wav_save()
	}
}

track_mouse_button_callback :: proc(window: glfw.WindowHandle, button, action: i32) {
	if button == glfw.MOUSE_BUTTON_LEFT {
		x64, y64 := glfw.GetCursorPos(window)
		x := f32(x64)
		y := f32(y64)

		if action == glfw.PRESS {
			selected_track_i = hovered_track_i
			selected_track_item_i = hovered_track_item_i
			if selected_track_item_i > -1 {
				copy_track_item(
					tracks[selected_track_i][selected_track_item_i],
					&selected_item_backup,
				)
			}
		} else {
			total_diff_ms = 0
			if selected_track_item_i > -1 {
				if !item_is_valid(tracks[selected_track_i][:], selected_track_item_i) {
					copy_track_item(
						selected_item_backup,
						&tracks[selected_track_i][selected_track_item_i],
					)
					return
				}
				sort_tracks()
				// Update the selected_track_item_i after sorting items
				track_handle_hovered_item(tracks[selected_track_i][:])
				selected_track_item_i = hovered_track_item_i
			} else if selected_track_i > -1 {
				start := math.round((x - tracks_pos.x) * track_ms_per_px)
				append(
					&tracks[selected_track_i],
					TrackItem{midi = 60, start = start, duration = 300},
				)
				added_item_i := len(tracks[selected_track_i]) - 1

				if !item_is_valid(tracks[selected_track_i][:], added_item_i) {
					pop(&tracks[selected_track_i])
					return
				}

				sort_tracks()
				// Update the selected_track_item_i after sorting items
				selected_track_item_i = hovered_track_item_i
			}
		}
	}
}

track_cursor_drag_callback :: proc(x, x_diff: f32) {
	if selected_track_item_i > -1 {
		selected_note := &tracks[selected_track_i][selected_track_item_i]

		diff_ms := math.round(x_diff / track_px_per_ms)
		total_diff_ms += diff_ms

		switch track_item_hold {
		case .Center:
			new_start := math.round((selected_item_backup.start + total_diff_ms) / 100) * 100
			old_start := math.round(selected_note.start / 100) * 100
			if new_start != old_start {
				selected_note.start = new_start
			}
		// selected_note.start += diff_ms
		case .Left:
			new_start := math.round((selected_item_backup.start + total_diff_ms) / 100) * 100
			old_start := math.round(selected_note.start / 100) * 100
			if new_start != old_start {
				d := new_start - selected_note.start
				selected_note.start = new_start
				selected_note.duration -= d
			}
		// selected_note.start += diff_ms
		// selected_note.duration -= diff_ms
		case .Right:
			new_duration := math.round((selected_item_backup.duration + total_diff_ms) / 100) * 100
			old_duration := math.round(selected_note.duration / 100) * 100
			if new_duration != old_duration {
				selected_note.duration = new_duration
			}
		// selected_note.duration += diff_ms
		}
	}
}

track_cursor_hover_callback :: proc(window: glfw.WindowHandle) -> bool {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)
	y := f32(y64)

	hovered_track_i = -1
	hovered_track_item_i = -1

	if x >= tracks_pos.x &&
	   x <= tracks_pos.x + tracks_size.x &&
	   y >= tracks_pos.y &&
	   y <= tracks_pos.y + tracks_size.y {
		track_pos := tracks_pos
		for track, i in tracks {
			if y >= track_pos.y && y <= track_pos.y + line_height {
				hovered_track_i = i
				break
			}
			track_pos.y += line_height
		}
		return track_handle_hovered_item(tracks[hovered_track_i][:])
	}

	return false
}

copy_track_item :: proc(from: TrackItem, to: ^TrackItem) {
	to.duration = from.duration
	to.duration = from.duration
	to.start = from.start
}

track_handle_hovered_item :: proc(track_items: []TrackItem) -> bool {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)

	for item, i in track_items {
		note_x_start := tracks_pos.x + item.start * track_px_per_ms
		note_x_end := note_x_start + item.duration * track_px_per_ms
		o: f32 = max(8, (note_x_end - note_x_start) / 10)
		if x >= note_x_start && x <= note_x_end {
			if x < note_x_start + o {
				glfw.SetCursor(window, glfw.CreateStandardCursor(glfw.RESIZE_EW_CURSOR))
				track_item_hold = .Left
			} else if x > note_x_end - o {
				glfw.SetCursor(window, glfw.CreateStandardCursor(glfw.RESIZE_EW_CURSOR))
				track_item_hold = .Right
			} else {
				glfw.SetCursor(window, glfw.CreateStandardCursor(glfw.POINTING_HAND_CURSOR))
				track_item_hold = .Center
			}
			hovered_track_item_i = i
			return true
		}
	}

	return false
}
