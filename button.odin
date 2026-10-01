package daw

import "core:fmt"
import gl "vendor:OpenGL"

button_vao: u32
button_vertices: [4]Vertex
button_triangle_indices: [6]u32 = {0, 1, 3, 3, 2, 1}

Button :: struct {
	pos:      Vec2,
	on_click: proc(),
}

buttons: [1]Button

button_padding_x :: padding * 2
button_width :: 50
button_height :: 28

button_init :: proc() {
	gl.GenVertexArrays(1, &button_vao)
	gl.BindVertexArray(button_vao)

	vbo: u32
	vbo_init(&vbo)
	button_vertices = make_quad_outline(button_width, button_height)
	vbo_update(&vbo, button_vertices[:])

	ebo: u32
	gl.GenBuffers(1, &ebo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(button_triangle_indices) * size_of(u32),
		&button_triangle_indices,
		gl.STATIC_DRAW,
	)
}

button_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})

	for button in buttons {
		shader_set_vec2(ui_program, "mesh_pos", button.pos)
		shader_set_vec4(ui_program, "color", {1.0, 1.0, 1.0, 1})
		gl.BindVertexArray(button_vao)

		// Background
		gl.DrawElements(gl.TRIANGLES, i32(len(button_triangle_indices)), gl.UNSIGNED_INT, nil)

		shader_set_vec4(ui_program, "color", {0.2, 0.2, 0.2, 1})

		// Border
		gl.LineWidth(2.0)
		gl.DrawArrays(gl.LINE_LOOP, 0, i32(len(button_vertices)))
		gl.LineWidth(1.0)

		// Border corners
		gl.PointSize(2.0)
		gl.DrawArrays(gl.POINTS, 0, i32(len(button_vertices)))
		gl.PointSize(1.0)
	}
}
