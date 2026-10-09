#version 330
in vec2 offset;
uniform float radius;
uniform vec4 colour;
out vec4 fragColour;

void main() {
	float alpha = clamp(radius + 0.5 - length(offset), 0.0, 1.0);
	if (alpha <= 0.0) discard;
	fragColour = vec4(colour.rgb, colour.a * alpha);
}
