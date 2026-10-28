package graphic

import "core:fmt"
import "core:math"
import "core:strings"
import rl "vendor:raylib"
import "vendor:raylib/rlgl"

// TODO: this implementation should not be visible to the user

Color :: rl.Color
Rectangle :: rl.Rectangle

FPS           :i32: 60

WIDTH         :i32: 560
HEIGHT        :i32: 560
// TODO: these values are scaled to the width and height texture size.
// when dealing with much larger textures we may need to scale with it.
POINT_RADIUS  :f32: 5
AXIS_WIDTH    :f32: 5 
TICK_WIDTH    :f32: 3
PADDING       :f32: 3

DEFAULT_FONT_PANEL_TITLE        :: InnerFont {32, .Inter_24pt_Medium }
DEFAULT_FONT_GRAPHIC_TITLE      :: InnerFont {20, .Inter_24pt_Medium }
DEFAULT_FONT_AXIS_TICK_LABEL    :: InnerFont {16, .Inter_24pt_Light }

FONT_MAP : map[InnerFont]rl.Font

CURRENT_GRAPHIC_DST_RECT          : Rectangle
CURRENT_GRAPHIC_TITLE_RECT        : Rectangle
CURRENT_GRAPHIC_X_AXIS_TITLE_RECT : Rectangle
CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT : Rectangle
CURRENT_GRAPHIC_X_AXIS_RECT       : Rectangle
CURRENT_GRAPHIC_Y_AXIS_RECT       : Rectangle
CURRENT_GRAPHIC_PLOT_RECT         : Rectangle


POINT_VERTEX_SHADER   :: #load("shaders/point.vs", string)
POINT_FRAGMENT_SHADER :: #load("shaders/point.fs", string)

INTER_24PT_MEDIUM :: #load("Inter_24pt-Medium.ttf")
INTER_24PT_LIGHT  :: #load("Inter_24pt-Light.ttf")


Panel :: struct {
    color: Color,

    title: string,
    title_alignment: Alignment,
    title_position: [2]f32,
    font: Font,
}

Graphic :: struct {
    x_axis: Axis,
    y_axis: Axis,
    x_axis_grid: bool,
    y_axis_grid: bool,

    title: string,
    title_position: [2]f32,
    font: Font,
    title_alignment: Alignment,

    // background color
    background_color: Color,
    plot_color: Color,
}

GraphicType :: enum {
    Scatter,
}

Alignment :: enum {
    Right,
    Left,
    Center
}

Orientation :: enum {
    Vertical,
    Horizontal
}

Axis :: struct {
    major_tick_config: Ticks,
    major_tick_labels: []string,
    major_tick_label_font: Font,
    minor_tick_config: Maybe(Ticks),
    title: string,
    title_font: Font,
    title_alignment: Alignment,
    title_rotation: f32,
    color: Color,
}

// first_tick_position is a value between 0 and 1.
// step_size is a value between 0 and 1. It is a faction of the range
Ticks :: struct {
    first_tick_position: f32,
    step_size: f32,
    text_rotation: f32,
    color: Color,
    length: f32,
    font: Font
}

InnerFont :: struct {
    size: f32,
    source: FontData
}

InternalFont :: enum {
    Inter_24pt_Medium,
    Inter_24pt_Light
}


Path :: string

FontData :: union {
    Path,
    InternalFont
}

Font :: struct {
    using inner_font: InnerFont,
    color: Color,
}

Legend :: struct {
    rect: [4]f32,
    labels: []struct { marker: Marker, label: string },
    font: Font,
}

Marker :: struct {
    color: Color,
    symbol: Symbol
}

Symbol :: enum {
    Circle,
    Box
}

Backend :: struct {
    render_texture: rl.RenderTexture,
    point_shader: rl.Shader,

    vertex_map : [dynamic]VertexObject,
    interactive: bool,
}

VertexObject :: struct {
    array    : u32,
    x_buffer : u32,
    y_buffer : u32,
    count    : i32,
}

get_internal_font :: proc(flag: InternalFont) -> (rawptr, int) {
    switch flag {
    case .Inter_24pt_Medium : return raw_data(INTER_24PT_MEDIUM), len(INTER_24PT_MEDIUM)
    case .Inter_24pt_Light : return raw_data(INTER_24PT_LIGHT), len(INTER_24PT_LIGHT)
    }
    return nil, 0
}

start_backend :: proc(interactive: bool, fonts: []InnerFont, log_tracing:= false) -> (backend: Backend, is_ok: bool) {

    temp_allocator := context.temp_allocator

    // If raylib as been initialized there is no work to be done. If not we
    // configure it.
    if !rl.IsWindowReady() {
        config_flags : rl.ConfigFlags
        if interactive {
            config_flags = {.WINDOW_RESIZABLE}
        } else {
            config_flags = {.WINDOW_HIDDEN}
        }

        if !log_tracing do rl.SetTraceLogLevel(.NONE)

        rl.SetConfigFlags(config_flags)
        rl.SetTargetFPS(FPS)
        rl.InitWindow(WIDTH, HEIGHT, "Simple Odin Data Analysis Graph")

        if !rl.IsWindowReady() do return backend, false

    }
    backend.interactive = interactive
    backend.render_texture = rl.LoadRenderTexture(WIDTH, HEIGHT)

    if FONT_MAP == nil {  // Today, we expect start_backend to only be called once. Tomorrow we may not.
        FONT_MAP = make(map[InnerFont]rl.Font)
        for inner_font in fonts {

            font : rl.Font
            switch source in inner_font.source {
            case Path:

                c_font_path := strings.clone_to_cstring(source, temp_allocator)
                font = rl.LoadFontEx(c_font_path, i32(inner_font.size), nil, 0)
                FONT_MAP[{inner_font.size, strings.clone(source)}] = font

            case InternalFont:

                internal_font_data, n_bytes := get_internal_font(source)
                font = rl.LoadFontFromMemory(".ttf", internal_font_data, i32(n_bytes), i32(inner_font.size), nil, 0)
                FONT_MAP[{inner_font.size, source}] = font

            }
        }
    }

    // TODO: we should not be storing the handles to the shaders in the backend.
    // Additionally, we load via the temp allocator, I'm not sure what the
    // shader loading will do if the text is de-allocated. I would assume that
    // these shaders are compiled once loading the strings from memory.
    vertex_source := strings.clone_to_cstring(POINT_VERTEX_SHADER, temp_allocator)
    fragment_source := strings.clone_to_cstring(POINT_FRAGMENT_SHADER, temp_allocator)
    backend.point_shader = rl.LoadShaderFromMemory(vertex_source, fragment_source)

    return backend, true
}

close_backend :: proc(backend: Backend) {
    for key, it in FONT_MAP {
        rl.UnloadFont(it)
        switch s in key.source {
        case Path: delete(s)
        case InternalFont: {}
        }
    }
    clear_map(&FONT_MAP)

    rl.UnloadRenderTexture(backend.render_texture)
    rl.CloseWindow()
}

// Must be called after rl.BeginDrawing is called.
begin_panel :: proc(panel: Panel, backend: Backend) {
    if backend.interactive do rl.BeginDrawing()

    rl.BeginTextureMode(backend.render_texture)

    rl.ClearBackground(panel.color)
    title_position := panel.title_position

    draw_text(panel.title, panel.title_position, 0, panel.title_alignment,
        panel.font)
}

end_panel :: proc(backend: Backend) {
    rl.EndTextureMode()
    texture := backend.render_texture.texture
    rl.DrawTextureRec(texture, {0, 0, f32(texture.width), -f32(texture.height)}, {0, 0}, rl.WHITE)
    if backend.interactive do rl.EndDrawing()
}

// Fonts must be loaded by start_backend at the exact size and path they are drawn with.
get_font :: proc(inner_font: InnerFont, loc := #caller_location) -> rl.Font {
    font, ok := FONT_MAP[inner_font]
    fmt.assertf(ok, "font %q at size %v was not loaded by start_backend",
        inner_font.source, inner_font.size, loc = loc)
    return font
}

draw_text :: proc(text: string, position: [2]f32, rotation: f32, alignment: Alignment, font: Font) {
    title_position := position

    rl_font := get_font(font.inner_font)
    c_title := strings.clone_to_cstring(text, context.temp_allocator)
    render_size := rl.MeasureTextEx(rl_font, c_title, font.size, 0)
    switch alignment {
    case .Left: { }
    case .Center: title_position.x += render_size.x/2
    case .Right: title_position.x  += render_size.x
    }

    rl.DrawTextPro(rl_font, c_title, title_position, {0, 0},
        math.to_degrees(rotation), font.size,  0, font.color)
}

make_scatter_point_buffer :: proc(x_values, y_values: []f32, backend: ^Backend) -> int {
    assert(len(x_values) == len(y_values))

    vertex_obj : VertexObject

    vertex_obj.array = rlgl.LoadVertexArray()
    rlgl.EnableVertexArray(vertex_obj.array)

    // LoadVertexBuffer leaves the new buffer bound, so each attribute is
    // described right after its buffer is created. Attribute 0 is x, attribute 1
    // is y.
    size := i32(len(x_values)) * size_of(f32)
    vertex_obj.x_buffer = rlgl.LoadVertexBuffer(raw_data(x_values), size, true)
    rlgl.SetVertexAttribute(0, 1, rlgl.FLOAT, false, 0, 0)
    rlgl.SetVertexAttributeDivisor(0, 1) // advance once per instance (point), not per vertex
    rlgl.EnableVertexAttribute(0)

    vertex_obj.y_buffer = rlgl.LoadVertexBuffer(raw_data(y_values), size, true)
    rlgl.SetVertexAttribute(1, 1, rlgl.FLOAT, false, 0, 0)
    rlgl.SetVertexAttributeDivisor(1, 1)
    rlgl.EnableVertexAttribute(1)

	  rlgl.DisableVertexArray()

    vertex_obj.count = i32(len(x_values))

    append(&backend.vertex_map, vertex_obj)

    return len(backend.vertex_map) - 1
}

begin_graphic :: proc(graphic: Graphic, dst_rect: Rectangle) {

    temp_allocator := context.temp_allocator
    CURRENT_GRAPHIC_DST_RECT = dst_rect

    // Measure Title
    {
        c_title := strings.clone_to_cstring(graphic.title, temp_allocator)
        font := get_font(graphic.font.inner_font)
        title_shape := rl.MeasureTextEx(font, c_title, graphic.font.size, 0)

        // TODO: inefficient
        if len(graphic.title) == 0 do title_shape = {0, 0}

        CURRENT_GRAPHIC_TITLE_RECT = {
            0,
            PADDING,
            title_shape.x,
            title_shape.y
        }
        switch graphic.title_alignment {
        case .Left: 
            CURRENT_GRAPHIC_TITLE_RECT.x = 2 * PADDING
        case .Center:
            CURRENT_GRAPHIC_TITLE_RECT.x = (CURRENT_GRAPHIC_DST_RECT.width - title_shape.x) / 2
        case .Right:
            CURRENT_GRAPHIC_TITLE_RECT.x = CURRENT_GRAPHIC_DST_RECT.width + PADDING - title_shape.x
        }
    }

    // Calculate initial Y-Axis Title and Y-Axis Rectangles
    {
        y_axis := graphic.y_axis
        c_y_axis := strings.clone_to_cstring(y_axis.title, temp_allocator)
        font := get_font(y_axis.title_font.inner_font)
        y_axis_title_shape := rl.MeasureTextEx(font, c_y_axis, y_axis.title_font.size, 0)

        // Bounding box of the rotated title. abs keeps the box positive for
        // negative rotations (e.g. -90 for bottom-to-top text).
        cos_r := abs(math.cos(y_axis.title_rotation))
        sin_r := abs(math.sin(y_axis.title_rotation))
        y_axis_title_width  := y_axis_title_shape.x * cos_r + y_axis_title_shape.y * sin_r
        y_axis_title_height := y_axis_title_shape.x * sin_r + y_axis_title_shape.y * cos_r

        // The y axis title runs along the left edge, between the graphic title
        // and the bottom of the graphic. Alignment is along the axis: Left is
        // the bottom (where bottom-to-top text starts), Right is the top.
        span_top    := calc_span_top()  // CURRENT_GRAPHIC_TITLE_RECT.y + CURRENT_GRAPHIC_TITLE_RECT.height + PADDING

        CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT = {
            2*PADDING,
            0,  // Deduced later in the source code.
            y_axis_title_width,
            y_axis_title_height,
        }

        // TODO: handle tick label rotations
        {
            max_width :f32= 0
            for it in y_axis.major_tick_labels {
                c_tick_label := strings.clone_to_cstring(it, temp_allocator)
                y_axis_title_shape := rl.MeasureTextEx(font, c_tick_label, y_axis.title_font.size, 0)
                max_width = max(max_width, y_axis_title_shape.x) 
            }

            cgyatr := CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT 
            CURRENT_GRAPHIC_Y_AXIS_RECT = {
                cgyatr.x + cgyatr.width + 2 * PADDING + TICK_WIDTH + max_width,
                span_top,
                AXIS_WIDTH,
                0 // Deduce later in the source code.
            }
        }
    }

    // Calculate initial X-Axis Title and X-Axis Rectangles
    {
        x_axis := graphic.x_axis
        c_x_axis := strings.clone_to_cstring(x_axis.title, temp_allocator)
        font := get_font(x_axis.title_font.inner_font)
        x_axis_title_shape := rl.MeasureTextEx(font, c_x_axis, x_axis.title_font.size, 0)

        // Bounding box of the rotated title. abs keeps the box positive for
        // negative rotations.
        cos_r := abs(math.cos(x_axis.title_rotation))
        sin_r := abs(math.sin(x_axis.title_rotation))
        x_axis_title_width  := x_axis_title_shape.x * cos_r + x_axis_title_shape.y * sin_r
        x_axis_title_height := x_axis_title_shape.x * sin_r + x_axis_title_shape.y * cos_r

        // The x axis title runs along the bottom edge, from the right of the y
        // axis to the right edge of the graphic.
        span_left  := CURRENT_GRAPHIC_Y_AXIS_RECT.x + CURRENT_GRAPHIC_Y_AXIS_RECT.width
        span_right := CURRENT_GRAPHIC_DST_RECT.width - PADDING

        x: f32
        switch x_axis.title_alignment {
        case .Left:   x = span_left
        case .Center: x = span_left + (span_right - span_left - x_axis_title_width) / 2
        case .Right:  x = span_right - x_axis_title_width
        }

        CURRENT_GRAPHIC_X_AXIS_TITLE_RECT = {
            x,
            CURRENT_GRAPHIC_DST_RECT.height - PADDING - x_axis_title_height,
            x_axis_title_width,
            x_axis_title_height,
        }
        {
            max_width :f32= 0
            for it in x_axis.major_tick_labels {
                c_tick_label := strings.clone_to_cstring(it, temp_allocator)
                x_axis_title_shape := rl.MeasureTextEx(font, c_tick_label, x_axis.title_font.size, 0)
                max_width = max(max_width, x_axis_title_shape.y) 
            }
            cgxatr := CURRENT_GRAPHIC_X_AXIS_TITLE_RECT
            CURRENT_GRAPHIC_X_AXIS_RECT = {
                span_left,
                cgxatr.y - AXIS_WIDTH - PADDING - TICK_WIDTH - max_width,
                CURRENT_GRAPHIC_DST_RECT.width - span_left - 5*PADDING,
                AXIS_WIDTH,
            }
        }
    }


    CURRENT_GRAPHIC_Y_AXIS_RECT.height = (CURRENT_GRAPHIC_X_AXIS_RECT.y + CURRENT_GRAPHIC_X_AXIS_RECT.height) -  CURRENT_GRAPHIC_Y_AXIS_RECT.y
    {
        span_top    := calc_span_top()
        span_bottom := CURRENT_GRAPHIC_DST_RECT.height - PADDING
        y_axis := graphic.y_axis

        y_axis_title_height := CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT.height

        y: f32
        switch y_axis.title_alignment {
        case .Left:   y = span_bottom - y_axis_title_height
        case .Center: y = span_top + (span_bottom - span_top - y_axis_title_height) / 2
        case .Right:  y = span_top
        }

        CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT.y = y
    }

    CURRENT_GRAPHIC_PLOT_RECT = {
        CURRENT_GRAPHIC_X_AXIS_RECT.x + CURRENT_GRAPHIC_DST_RECT.x,
        CURRENT_GRAPHIC_Y_AXIS_RECT.y + CURRENT_GRAPHIC_DST_RECT.y,
        CURRENT_GRAPHIC_X_AXIS_RECT.width,
        CURRENT_GRAPHIC_Y_AXIS_RECT.height,
    }

    rl.DrawRectangleRec(CURRENT_GRAPHIC_DST_RECT, graphic.background_color)
    // Tick marks can extend beyond the plot drawing space. To insure that
    // things look good we have to extend the width and height of the
    // background color rect.
    {
        plot_background_rect := CURRENT_GRAPHIC_PLOT_RECT

        plot_background_rect.width  += TICK_WIDTH / 2
        plot_background_rect.height += TICK_WIDTH / 2

        rl.DrawRectangleRec(plot_background_rect, graphic.plot_color)
    }
    rl.BeginScissorMode(
        i32(CURRENT_GRAPHIC_PLOT_RECT.x),
        i32(CURRENT_GRAPHIC_PLOT_RECT.y),
        i32(CURRENT_GRAPHIC_PLOT_RECT.width),
        i32(CURRENT_GRAPHIC_PLOT_RECT.height),
    )
}

end_graphic :: proc(graphic: Graphic) {
    rl.EndScissorMode()
    draw_axis(graphic.x_axis, .Horizontal)
    draw_axis(graphic.y_axis, .Vertical)
}

// Draws the axis bar, its ticks, tick labels and title into the rects laid out
// by begin_graphic.
draw_axis :: proc(axis: Axis, orientation: Orientation) {
    temp_allocator := context.temp_allocator
    dst := CURRENT_GRAPHIC_DST_RECT

    axis_rect, title_rect: Rectangle
    switch orientation {
    case .Horizontal:
        axis_rect  = CURRENT_GRAPHIC_X_AXIS_RECT
        title_rect = CURRENT_GRAPHIC_X_AXIS_TITLE_RECT
    case .Vertical:
        axis_rect  = CURRENT_GRAPHIC_Y_AXIS_RECT
        title_rect = CURRENT_GRAPHIC_Y_AXIS_TITLE_RECT
    }

    // The layout rects are relative to the graphic's destination rect.
    axis_rect.x  += dst.x
    axis_rect.y  += dst.y
    title_rect.x += dst.x
    title_rect.y += dst.y

    rl.DrawRectangleRec(axis_rect, axis.color)

    // Minor ticks go first so major ticks are drawn over them where they meet.
    if minor, ok := axis.minor_tick_config.?; ok {
        for i in 0..<tick_count(minor) {
            draw_tick(axis_rect, orientation, minor, tick_fraction(minor, i))
        }
    }

    // Major ticks and their labels
    {
        major := axis.major_tick_config
        labels := axis.major_tick_labels
        label_font := get_font(axis.major_tick_label_font.inner_font)
        n_ticks := len(labels) if len(labels) > 0 else tick_count(major)

        for i in 0..<n_ticks {
            anchor := draw_tick(axis_rect, orientation, major, tick_fraction(major, i))
            if i >= len(labels) do continue

            c_label := strings.clone_to_cstring(labels[i], temp_allocator)
            size := rl.MeasureTextEx(label_font, c_label, axis.major_tick_label_font.size, 0)

            // origin is the point of the label placed on the anchor, and the
            // point the label rotates around.
            origin: [2]f32
            switch orientation {
            case .Horizontal: origin = {size.x/2, -2*PADDING}  // top center, below the tick
            case .Vertical:   origin = {size.x, size.y/2}      // right middle, left of the tick
            }
            rl.DrawTextPro(label_font, c_label, anchor, origin,
                math.to_degrees(major.text_rotation), axis.major_tick_label_font.size,
                0, axis.major_tick_label_font.color)
        }
    }

    // Title, rotated about the center of its laid out bounding box
    {
        title_font := get_font(axis.title_font.inner_font)
        c_title := strings.clone_to_cstring(axis.title, temp_allocator)
        size := rl.MeasureTextEx(title_font, c_title, axis.title_font.size, 0)
        center := [2]f32{
            title_rect.x + title_rect.width/2,
            title_rect.y + title_rect.height/2,
        }
        rl.DrawTextPro(title_font, c_title, center, size/2,
            math.to_degrees(axis.title_rotation), axis.title_font.size, 0,
            axis.title_font.color)
    }
}

// Number of ticks from first_tick_position up to and including the end of the axis.
tick_count :: proc(ticks: Ticks) -> int {
    if ticks.step_size <= 0 do return 0
    // The small epsilon keeps a tick landing exactly on 1 from being lost to rounding.
    return int(math.floor((1 - ticks.first_tick_position)/ticks.step_size + 1e-4)) + 1
}

tick_fraction :: proc(ticks: Ticks, i: int) -> f32 {
    return ticks.first_tick_position + f32(i)*ticks.step_size
}

// Draws one tick at fraction (0 to 1) along the axis and returns where its label
// should be anchored. Horizontal ticks hang below the axis, vertical ticks stick
// out to its left with fraction 0 at the bottom.
draw_tick :: proc(axis_rect: Rectangle, orientation: Orientation, ticks: Ticks, fraction: f32) -> (label_anchor: [2]f32) {
    switch orientation {
    case .Horizontal:
        x := axis_rect.x + fraction*axis_rect.width
        y := axis_rect.y
        rl.DrawRectangleRec({x - TICK_WIDTH/2, y, TICK_WIDTH, ticks.length + axis_rect.height}, ticks.color)
        label_anchor = {x, y + ticks.length + PADDING}
    case .Vertical:
        x := axis_rect.x
        y := axis_rect.y + (1 - fraction)*axis_rect.height
        rl.DrawRectangleRec({x - ticks.length, y - TICK_WIDTH/2, ticks.length + axis_rect.width, TICK_WIDTH}, ticks.color)
        label_anchor = {x - ticks.length - PADDING, y}
    }
    return
}

draw_data_scatter :: proc(
    symbol: Symbol,
    vertex_obj: VertexObject,
    color: Color,
    backend: Backend,
) {

    if symbol != .Circle do panic("Symbol is not circle. Other symbols have not ben implemented.")
    shader := backend.point_shader

    rlgl.DrawRenderBatchActive()
    resolution_loc     := rl.GetShaderLocation(shader, "resolution")
    radius_loc         := rl.GetShaderLocation(shader, "radius")
    color_loc          := rl.GetShaderLocation(shader, "colour")
    scale_loc          := rl.GetShaderLocation(shader, "scale")
    translate_loc      := rl.GetShaderLocation(shader, "translate")

    resolution := [2]f32{f32(WIDTH), f32(HEIGHT)}
    radius     := POINT_RADIUS
    color      := [4]f32{
        f32(color.r),
        f32(color.g),
        f32(color.b),
        f32(color.a)
    } / 255

    scale: [2]f32 = {
        CURRENT_GRAPHIC_PLOT_RECT.width / f32(backend.render_texture.texture.width),
        CURRENT_GRAPHIC_PLOT_RECT.height / f32(backend.render_texture.texture.height),
    }
    translate: [2]f32 = {
        CURRENT_GRAPHIC_PLOT_RECT.x / f32(backend.render_texture.texture.width),
        CURRENT_GRAPHIC_PLOT_RECT.y / f32(backend.render_texture.texture.height),
    }

    rlgl.EnableShader(shader.id)
    rlgl.SetUniform(resolution_loc, &resolution, i32(rlgl.ShaderUniformDataType.VEC2), 1)
    rlgl.SetUniform(radius_loc,     &radius,     i32(rlgl.ShaderUniformDataType.FLOAT), 1)
    rlgl.SetUniform(color_loc,     &color,     i32(rlgl.ShaderUniformDataType.VEC4), 1)
    rlgl.SetUniform(scale_loc,     &scale,     i32(rlgl.ShaderUniformDataType.VEC2), 1)
    rlgl.SetUniform(translate_loc, &translate, i32(rlgl.ShaderUniformDataType.VEC2), 1)

    rlgl.EnableVertexArray(vertex_obj.array)
    rlgl.DrawVertexArrayInstanced(0, 6, vertex_obj.count)
    rlgl.DisableVertexArray()
    rlgl.DisableShader()
}

store_frame :: proc(backend: Backend) -> (rl.Image, bool) {
    image := rl.LoadImageFromTexture(backend.render_texture.texture)
    if image.data == nil {

        fmt.eprintln("Image was not able to load for backend texture.")
        return image, false
    }

    // Render textures are stored upside down relative to image space.
    rl.ImageFlipVertical(&image)
    return image, true
}

delete_frame :: proc(image: rl.Image) {
    rl.UnloadImage(image)
}

// TODO: output errors
save_frame :: proc(image: rl.Image, path: string) {
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    if rl.ExportImage(image, cpath) {
        fmt.printfln("Saved frame to %s", path)
    } else {
        fmt.eprintfln("Failed to save frame to %s", path)
    }
}

calc_span_top :: proc() -> f32 {
    return CURRENT_GRAPHIC_TITLE_RECT.y + CURRENT_GRAPHIC_TITLE_RECT.height + 2 *PADDING
}
