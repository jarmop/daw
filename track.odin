package daw

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"

track_vao: u32
track_vbo: u32
track_vertices: []Vertex

track_size: Vec2 = {200, line_height}
track_pos: Vec2

track_init :: proc() {
	gl.GenVertexArrays(1, &track_vao)
	gl.BindVertexArray(track_vao)

	vbo_init(&track_vbo)
}

track_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "mesh_pos", track_pos)
	shader_set_vec4(ui_program, "color", {1, 1, 1, 0.5})

	gl.BindVertexArray(track_vao)
	gl.DrawArrays(gl.LINES, 0, i32(len(track_vertices)))
}

track_vertices_update :: proc() {
	step_length_ms: f32 = 100
	px_per_ms: f32 = 0.4
	step_length_px: f32 = step_length_ms * px_per_ms
	track_steps := int(get_track_duration(track_items) / step_length_ms + 0.5)
	// fmt.println(track_steps)
	vertex_count_steps := 2 * (track_steps + 1)
	vertex_count_stylus := 2
	track_vertices = make([]Vertex, vertex_count_steps + vertex_count_stylus)
	defer delete(track_vertices)

	i := 0

	p: Vec2 = {0, 0}
	for s in 0 ..= track_steps {
		track_vertices[i].pos = p
		track_vertices[i + 1].pos = p + {0, -10}
		i += 2
		p.x += step_length_px
	}

	progress := f32(sample_i) * ms_per_frame * px_per_ms
	// fmt.println(progress)
	track_vertices[i].pos = {progress, 0}
	track_vertices[i + 1].pos = {progress, -10}

	for item in track_items {
		text_pos := track_pos + {item.start * px_per_ms, 0}
		text_add_vertices(midi_to_text(item.midi), text_pos, item.duration * px_per_ms)
	}


	vbo_update(&track_vbo, track_vertices[:])
}

get_track_duration :: proc(track: []TrackItem) -> f32 {
	last_item := track_items[len(track_items) - 1]
	return last_item.start + last_item.duration
}
