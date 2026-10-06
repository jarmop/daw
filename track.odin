package daw

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"

track_vao: u32
track_vbo: u32
track_vertices: []Vertex

tracks_size: Vec2
tracks_pos: Vec2

track_px_per_ms: f32 = 0.4

notes_vao: u32
notes_vbo: u32
notes_vertices: [dynamic]ColorVertex

track_init :: proc() {
	gl.GenVertexArrays(1, &track_vao)
	gl.BindVertexArray(track_vao)
	vbo_init(&track_vbo)

	gl.GenVertexArrays(1, &notes_vao)
	gl.BindVertexArray(notes_vao)
	vbo_color_init(&notes_vbo)
}

track_draw :: proc() {
	// --------------
	// Tracks
	// --------------
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "mesh_pos", tracks_pos)
	shader_set_vec4(ui_program, "color", {1, 1, 1, 0.5})

	gl.BindVertexArray(track_vao)
	gl.DrawArrays(gl.LINES, 0, i32(len(track_vertices)))

	// --------------
	// Notes
	// --------------
	gl.UseProgram(color_program)

	shader_set_vec2(color_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})

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
	track_vertices = make([]Vertex, vertex_count_steps + vertex_count_stylus)
	defer delete(track_vertices)

	i := 0

	// ---------------
	// Steps
	// ---------------
	p: Vec2 = {0, 0}
	for s in 0 ..= track_steps {
		p.x = f32(s) * step_length_px
		track_vertices[i].pos = p
		track_vertices[i + 1].pos = p + {0, tracks_size.y}
		i += 2
	}

	// ---------------
	// Stylus
	// ---------------
	progress := f32(sample_i) * ms_per_frame * track_px_per_ms
	track_vertices[i].pos = {progress, 0}
	track_vertices[i + 1].pos = {progress, tracks_size.y}

	vbo_update(&track_vbo, track_vertices[:])

	// ---------------
	// Notes
	// ---------------
	clear(&notes_vertices)
	track_pos := tracks_pos
	i = 0
	for track_items, track_i in tracks {
		for item, item_i in track_items {
			note_pos := track_pos + {item.start * track_px_per_ms, 0}
			text_pos := note_pos + {0, line_height - 3}
			note_width := item.duration * track_px_per_ms
			text_add_vertices(midi_to_text(item.midi), text_pos, note_width)

			color: Vec4 =
				track_i == selected_track_i && item_i == selected_track_item_i ? {0, 0, 0.2, 0.2} : {0, 0, 0, 0.1}
			quad := make_quad_color(note_width, line_height, note_pos.x, note_pos.y, color)
			append(&notes_vertices, ..quad[:])
			i += 1
		}
		track_pos.y += line_height
	}

	vbo_color_update(&notes_vbo, notes_vertices[:])
}

get_track_duration :: proc(track: []TrackItem) -> f32 {
	if len(track) == 0 {
		return 0
	}
	last_item := track[len(track) - 1]
	return last_item.start + last_item.duration
}
