#version 330 core

in vec2 frag_uv;
out vec4 out_color;

uniform sampler2D tex;

void main() {
	float a = texture(tex, frag_uv).r;
	out_color = vec4(0.0, 0.0, 0.0, a);
	// out_color = vec4(0.0, 0.0, 0.0, 1);
}