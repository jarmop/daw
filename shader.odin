package daw

import "core:fmt"
import "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"

ui_program: u32
color_program: u32

shader_init :: proc() {
	shaders_ok: bool
	ui_program, shaders_ok = gl.load_shaders_file("./shaders/ui.vs", "./shaders/ui.fs")
	if !shaders_ok {
		fmt.println("Shaders not ok")
		os.exit(-1)
	}

	shaders2_ok: bool
	color_program, shaders2_ok = gl.load_shaders_file("./shaders/color.vs", "./shaders/color.fs")
	if !shaders2_ok {
		fmt.println("Shaders not ok")
		os.exit(-1)
	}
}

shader_set_vec2 :: proc(program_id: u32, name: cstring, value_param: glsl.vec2) {
	value := value_param
	gl.Uniform2fv(gl.GetUniformLocation(program_id, name), 1, raw_data(&value))
}

shader_set_vec4 :: proc(program_id: u32, name: cstring, value_param: glsl.vec4) {
	value := value_param
	gl.Uniform4fv(gl.GetUniformLocation(program_id, name), 1, raw_data(&value))
}

vbo_init :: proc(vbo: ^u32) {
	gl.GenBuffers(1, vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)

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

vbo_update :: proc(vbo: ^u32, vertices: []Vertex) {
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
}

vbo_color_init :: proc(vbo: ^u32) {
	gl.GenBuffers(1, vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)

	gl.VertexAttribPointer(
		0,
		2,
		gl.FLOAT,
		gl.FALSE,
		size_of(ColorVertex),
		offset_of(ColorVertex, pos),
	)
	gl.EnableVertexAttribArray(0)

	gl.VertexAttribPointer(
		1,
		4,
		gl.FLOAT,
		gl.FALSE,
		size_of(ColorVertex),
		offset_of(ColorVertex, color),
	)
	gl.EnableVertexAttribArray(1)
}

vbo_color_update :: proc(vbo: ^u32, vertices: []ColorVertex) {
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(ColorVertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
}
