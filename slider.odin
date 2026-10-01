package daw

import "core:fmt"
import "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"

ui_program: u32

slider_bar_vao: u32
slider_bar_vertices: [6]Vertex

slider_handle_vao: u32
slider_handle_vertices: [6]Vertex

Slider :: struct {
	pos:              Vec2,
	value:            ^f32,
	max:              f32,
	on_value_changed: proc(),
}

bar_width: f32 = 100
bar_height: f32 = 2
handle_size: f32 = font_size

slider_init :: proc() {

	// -----------------------------------------
	// Load shaders
	// -----------------------------------------

	shaders_ok: bool
	ui_program, shaders_ok = gl.load_shaders_file("./shaders/ui.vs", "./shaders/ui.fs")
	if !shaders_ok {
		fmt.println("Shaders not ok")
		os.exit(-1)
	}

	// --------------
	// Slider bar
	// --------------

	gl.GenVertexArrays(1, &slider_bar_vao)
	gl.BindVertexArray(slider_bar_vao)

	slider_bar_vbo: u32
	vbo_init(&slider_bar_vbo)

	slider_bar_vertices = make_quad(bar_width, bar_height)
	vbo_update(&slider_bar_vbo, slider_bar_vertices[:])

	// --------------
	// Slider handle
	// --------------

	gl.GenVertexArrays(1, &slider_handle_vao)
	gl.BindVertexArray(slider_handle_vao)

	slider_handle_vbo: u32
	vbo_init(&slider_handle_vbo)

	x2: f32 = -handle_size / 2
	y2: f32 = (-handle_size + bar_height) / 2
	slider_handle_vertices = make_quad(handle_size, handle_size, x2, y2)
	vbo_update(&slider_handle_vbo, slider_handle_vertices[:])
}

slider_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})

	for slider in sliders {
		shader_set_vec2(ui_program, "mesh_pos", slider.pos)
		shader_set_vec4(ui_program, "color", {0.2, 0.2, 0.2, 1})
		gl.BindVertexArray(slider_bar_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, i32(len(slider_bar_vertices)))

		handle_x := slider.value^ / slider.max * bar_width
		handle_pos := slider.pos + {handle_x, 0}

		shader_set_vec2(ui_program, "mesh_pos", handle_pos)
		shader_set_vec4(ui_program, "color", {0, 0, 0, 1})
		gl.BindVertexArray(slider_handle_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, i32(len(slider_handle_vertices)))
	}
}
