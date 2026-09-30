#version 330 core

layout(location = 0) in vec2 in_pos;
layout(location = 1) in vec2 in_uv;

out vec2 frag_uv;

uniform vec2 screen_size;

void main() {
	vec2 p = in_pos / screen_size * 2.0 - 1.0;

	// Flip Y
	p.y = -p.y;

	gl_Position = vec4(p, 0.0, 1.0);
	frag_uv = in_uv;
}