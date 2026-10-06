#version 330 core

layout(location = 0) in vec2 vert_pos;
layout(location = 1) in vec4 vert_color;

uniform vec2 screen_size;

out vec4 frag_color;

void main() {
	vec2 p = vert_pos / screen_size * 2.0 - 1.0;

	// Flip Y
	p.y = -p.y;

	gl_Position = vec4(p, 0.0, 1.0);

	frag_color = vert_color;
}