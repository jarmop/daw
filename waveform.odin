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

	vbo_init(&waveform_vbo)
}

waveform_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})
	shader_set_vec2(ui_program, "mesh_pos", wave_form_pos)
	c: f32 = 0.4
	shader_set_vec4(ui_program, "color", {c, c, c, 1})

	gl.BindVertexArray(waveform_vao)
	gl.DrawArrays(gl.LINE_STRIP, 0, i32(len(waveform_vertices)))
}

waveform_vertices_update :: proc() {
	samples_count := 40
	waveform_vertices = make([]Vertex, samples_count)
	defer delete(waveform_vertices)

	for i in 0 ..< samples_count {
		phase := f32(i) / f32(samples_count - 1)
		sample := waveform_function_map[selected_waveform](phase)

		// Flip Y by using negative sample. Also divide Y by two so the total
		// height of the waveform is equal to the length.
		waveform_vertices[i].pos = Vec2{phase, -sample / 2} * waveform_size
	}

	vbo_update(&waveform_vbo, waveform_vertices[:])
}
