#version 330
in vec2 offset;
uniform float radius;
uniform vec4 colour;
out vec4 fragColour;

void main() {
	float alpha = clamp(radius + 0.5 - length(offset), 0.0, 1.0);
  // NOTE: we discard alpha <= X.X to insure the resulting draw is circular,
  // not square. The value is greater than zero to produce "nicer" circles.
	if (alpha <= 0.1) discard;
	fragColour = colour;
}
