#version 330 core

layout(location = 0) in vec2 in_pos;

uniform vec2 screen_size;
uniform vec2 model;
uniform vec4 color;

out vec4 vert_color;

void main() {
	vec2 p = (in_pos + model) / screen_size * 2.0 - 1.0;

	// Flip Y
	p.y = -p.y;

	gl_Position = vec4(p, 0.0, 1.0);

	vert_color = color;
}