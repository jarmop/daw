package daw

import gl "vendor:OpenGL"

waveform_vao: u32
waveform_vbo: u32
waveform_vertices: []Vertex

waveform_size: Vec2 = {18, 10}
wave_form_pos: Vec2

waveform_init :: proc() {
	gl.GenVertexArrays(1, &waveform_vao)
	gl.BindVertexArray(waveform_vao)

	gl.GenBuffers(1, &waveform_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, waveform_vbo)

	gl.VertexAttribPointer(
		0,
		size_of(Vertex) / size_of(f32),
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		0,
	)
	gl.EnableVertexAttribArray(0)
}

waveform_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "model", wave_form_pos)
	shader_set_vec4(ui_program, "color", {1, 1, 1, 1})

	gl.BindVertexArray(waveform_vao)
	gl.DrawArrays(gl.LINE_STRIP, 0, i32(len(waveform_vertices)))
}
