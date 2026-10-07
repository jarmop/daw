#version 330 core

in vec2 frag_uv;
out vec4 out_color;

uniform sampler2D tex;
uniform vec4 color;

void main() {
	float a = texture(tex, frag_uv).r * color.a;
	// float c = 0.6;
	// out_color = vec4(c, c, c, a);
	out_color = vec4(color.rgb, a);
}