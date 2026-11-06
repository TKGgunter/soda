#version 330
layout(location = 0) in float x; // data value, in data units
layout(location = 1) in float y; // data value, in data units
uniform vec2 data_min;           // data value mapped to the plot's left/bottom edge
uniform vec2 data_range;         // data_max - data_min, mapped to the plot's full width/height
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
    // Normalize data units to 0-1 across the plot area.
    vec2 normalized = (vec2(x, y) - data_min) / data_range;
    vec2 center = vec2(normalized.x, 1.0 - normalized.y) * scale + translate;
    vec2 pixel = center * resolution + offset;
    // Same mapping as raylib's 2D projection: origin top-left, y pointing down.
    gl_Position = vec4(
        pixel.x / resolution.x * 2.0 - 1.0,
        1.0 - pixel.y / resolution.y * 2.0,
        0.0,
        1.0
    );
}
