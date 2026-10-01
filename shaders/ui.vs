#version 330 core

layout(location = 0) in vec2 vert_pos;

uniform vec2 screen_size;
uniform vec2 mesh_pos;
uniform vec4 color;

out vec4 vert_color;

void main() {
	vec2 p = (mesh_pos + vert_pos) / screen_size * 2.0 - 1.0;

	// Flip Y
	p.y = -p.y;

	gl_Position = vec4(p, 0.0, 1.0);

	vert_color = color;
}