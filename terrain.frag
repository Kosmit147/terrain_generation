#version 460 core

in float Y;

out vec4 out_color;

void main() {
	float white_factor = Y + 1.0 * 0.5;
	float white = white_factor * (0.6) + 0.3;
	out_color = vec4(white, white, white, 1.0);
}
