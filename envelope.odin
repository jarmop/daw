package daw

import "core:fmt"
import gl "vendor:OpenGL"

envelope_vao: u32
envelope_vbo: u32
envelope_vertices: [5]Vertex

envelope_size: Vec2 = {200, 100}
envelope_pos: Vec2

envelope_init :: proc() {
	gl.GenVertexArrays(1, &envelope_vao)
	gl.BindVertexArray(envelope_vao)

	vbo_init(&envelope_vbo)
}

envelope_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "mesh_pos", envelope_pos)
	shader_set_vec4(ui_program, "color", {1, 1, 1, 1})

	gl.BindVertexArray(envelope_vao)
	gl.DrawArrays(gl.LINE_STRIP, 0, i32(len(envelope_vertices)))
}

envelope_vertices_update :: proc() {
	total_duration: f32 = 0
	for e in envelope {
		total_duration += e.duration
	}

	x: f32 = 0
	envelope_vertices[0].pos = {x, 0}
	for i in 0 ..< len(envelope_vertices) - 1 {
		e := envelope[i]
		x += e.duration / total_duration * envelope_size.x
		y := -e.amp_target / amplitude * envelope_size.y
		envelope_vertices[i + 1].pos = {x, y}
	}

	vbo_update(&envelope_vbo, envelope_vertices[:])
}
