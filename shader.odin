package daw

import "core:math/linalg/glsl"
import gl "vendor:OpenGL"

shader_set_vec2 :: proc(program_id: u32, name: cstring, value_param: glsl.vec2) {
	value := value_param
	gl.Uniform2fv(gl.GetUniformLocation(program_id, name), 1, raw_data(&value))
}

shader_set_vec4 :: proc(program_id: u32, name: cstring, value_param: glsl.vec4) {
	value := value_param
	gl.Uniform4fv(gl.GetUniformLocation(program_id, name), 1, raw_data(&value))
}
