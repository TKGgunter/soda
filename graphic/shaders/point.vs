#version 330
layout(location = 0) in float x; // fraction of the target's width
layout(location = 1) in float y; // fraction of the target's height
uniform vec2 resolution;         // target size in pixels
uniform float radius;            // circle radius in pixels
uniform vec2 translate;          // translate circle centers by translate values, (0, 0) = no shift
uniform vec2 scale;              // scales the, (1, 1) = no zoom
out vec2 offset;                 // pixel offset from the circle's centre

// Counter-clockwise on screen, because raylib leaves back-face culling enabled.
const vec2 corners[6] = vec2[6](
	vec2(-1.0, -1.0), vec2(1.0, 1.0), vec2(1.0, -1.0),
	vec2(-1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0, 1.0)
);

void main() {
    // One extra pixel of padding leaves room for the anti-aliased edge.
    offset = corners[gl_VertexID] * (radius + 1.0);
    vec2 center = vec2(x, 1.0 - y) * scale + translate;
    vec2 pixel = center * resolution + offset;
    // Same mapping as raylib's 2D projection: origin top-left, y pointing down.
    gl_Position = vec4(
        pixel.x / resolution.x * 2.0 - 1.0,
        1.0 - pixel.y / resolution.y * 2.0,
        0.0,
        1.0
    );
}
