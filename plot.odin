// Made primarily with Claude ai.
package soda

import "core:bytes"
import "core:fmt"
import "core:os"
import "core:image"
import "core:image/bmp"
import "base:runtime"

// TODO
// Add the selection component 
// https://idl.cs.washington.edu/files/2017-VegaLite-InfoVis.pdf
Plot :: struct($T: typeid) where T == ^DataFrame || T == ^DataFrameSlice {
    dataframe: T,
    mapping:   Aesthetic,          // global aes; layers inherit unless they set their own
    layers:    [dynamic]Layer,
    scales:    [ScaleAes]Scale,
    facet:     Facet,
    coord:     Coord,
    theme:     Theme,
    labels:    Labels,
}

Aesthetic :: struct {
    x, y, color, fill, shape, size, alpha, linetype, group: ColumnName,
}

Layer :: struct {
    geom:     Geom,
    position: Position,
    mapping:  Maybe(Aesthetic),   // nil -> inherit plot.mapping
}

Geom :: union { 
    Point,
    Line,
}

// TODO colors, ...
Point     :: struct {
    size,
    alpha: f32,
    symbol_code: PointSymbolCode,
}

Line      :: struct { linewidth, alpha: f32 }
Histogram :: struct { bins: int, binwidth: Maybe(f32) }

// TODO explain what these layout options mean.
Position :: enum {
    Identity,
    Stack,
    Dodge,
    Fill,
    Jitter,
}

Scale :: struct {
    min, max:  Maybe(f64),
    palette:   Maybe(Palette),
}

ScaleAes :: enum { X, Y, Color, Fill, Shape, Size, Alpha }

Palette :: union {
    []Color,
    GradientPalette
}

Color    :: [4]u8

GradientPalette :: struct { 
    low,
    high: Color
}

Facet :: enum {
    None,
    Wrap,
    Grid,
}

Wrap :: struct { 
    category: string
}

Grid :: struct {
    cols: []string,
    rows: []string
}


Coord :: struct {
    kind:         CoordKind,
    x_min, x_max: Maybe(f64),
    y_min, y_max: Maybe(f64),
    ratio:        f32,
}

CoordKind :: enum {
    Cartesian = 0,
    Flip,
    Fixed
}


Theme :: struct {
    panel_background,
    grid_color,
    text_color: Color,
    font_size:  f32,
    legend_position:  LegendPosition,
}

LegendPosition :: enum {
    Right,
    Left,
    Top,
    Bottom,
    None
}

Labels :: struct {
    title,
    subtitle: string,
    x,
    y: Maybe(string)
}

OutputFormat :: enum {
    // TODO:
    // RGB,
    Png,
    Svg,
}

Shape :: struct { 
    width,
    height,
    channels: int 
}

Dpi :: int

Theme_Default_Background :: Color{255,255,255,255}
Theme_Default_Grid       :: Color{0,0,0,255}
Theme_Default_Text       :: Color{0,0,0,255}

Theme_Default :: Theme {
    panel_background = Theme_Default_Background,
    grid_color = Theme_Default_Grid,
    text_color = Theme_Default_Text,
    font_size = 11 
}


// TODO - I suspect this palette is doing nothing
// A small default categorical palette (ColorBrewer Set1-ish), used when no
// Scale{aesthetic = .Color} with a manual palette is attached to the plot.
Default_Palette := []Color {
    {0,   0,    0,  255},
    {228, 26,  28,  255},
    {55,  126, 184, 255},
    {77,  175, 74,  255},
    {152, 78,  163, 255},
    {255, 127, 0,   255},
    {255, 255, 51,  255},
}

// Hershey symbols
PointSymbolCode :: enum(int) {
    Square       = 0,
    Dot          = 1,
    Plus         = 2,
    Star         = 3,
    Circle       = 4,
    Cross        = 5,
    Triangle     = 7,
    FilledSquare = 16,
    FilledCircle = 17,
}

Graphic :: struct {
    using  image: image.Image,
    is_svg: bool  // This is a stand in flag for more output types that are not handled by odin's image lib.
}

delete_graphic :: proc(g: Graphic, loc:= #caller_location) {
    delete(g.pixels.buf, loc)
}

to_f64_slice :: proc(cs: ColumnSlice, allocator := context.temp_allocator) -> (out: []f64, ok: bool) {
    switch v in cs {
    case []int:
        buf := make([]f64, len(v), allocator)
        for it, i in v do buf[i] = f64(it)
        return buf, true
    case []f64:
        return v, true
    case []string:
        return nil, false
    case []bool:
        return nil, false
    }
    return nil, false
}


// ============================== Pixel transform ==========================
// Backend-agnostic: maps a resolved world-space window onto a raster of
// `width` x `height` pixels. Pixel y grows downward while world y grows
// upward, so the y term is inverted relative to x.

PixelTransform :: struct {
    x_min, x_max, y_min, y_max: f64,
    width, height:              int,
}

// TODO add allocator
init_plot :: proc(df: $T) -> Plot(T) 
where T == ^DataFrame || T == ^DataFrameSlice {
    return Plot(T) {
        dataframe = df,
        layers = make([dynamic]Layer, 0, 1),
    }
}

add_mapping :: proc(plot: ^Plot($T), mapping: Aesthetic) {
    plot.mapping = mapping
}

add_scatter :: proc(plot: ^Plot($T), position:= Position.Identity, size:f32=1, alpha:f32=1, symbol_code:=PointSymbolCode.Dot, mapping:Maybe(Aesthetic)=nil) {
    append(&plot.layers, Layer{Point{size, alpha, symbol_code}, position, mapping})
}

delete_plot :: proc(plot: Plot($T)) {
    delete(plot.layers)
}

// TODO
draw_interactive :: proc(
    p: ^Plot($T),
    shape := Shape{800, 600, 3},
    allocator := context.allocator
) {
}

draw :: proc(
    p: ^Plot($T),
    format: OutputFormat,
    backend: Backend,
    shape := Shape{800, 600, 3},
    allocator := context.allocator
) -> (rt: Graphic, ok: bool) {

    if p.theme.font_size <= 0 { p.theme.font_size = Theme_Default.font_size }
    if p.theme.panel_background == {} { p.theme.panel_background = Theme_Default.panel_background }
    if p.theme.text_color == {} { p.theme.text_color = Theme_Default.text_color }
    if p.theme.grid_color == {} { p.theme.grid_color = Theme_Default.grid_color }

    
    // TODO we only work with x and y at this time. Once we begin using other
    // mappings we will need to check those as well.
    _, x_ok := get_columnslice(p.dataframe^, p.mapping.x)
    _, y_ok := get_columnslice(p.dataframe^, p.mapping.y)
    if !x_ok || !y_ok {
        fmt.eprintln("plot: mapping.x / mapping.y must name existing columns")
        return 
    }

    if p.labels.x == nil { p.labels.x = p.mapping.x }
    if p.labels.y == nil { p.labels.y = p.mapping.y }

    for &layer in p.layers {
        if layer.mapping == nil {
            layer.mapping = p.mapping
        }
    }

    {
        // TODO what if the mapping isn't set? we then need to remove
        column := get_columnslice(p.dataframe^, p.mapping.x) or_return
        if p.coord.x_min == nil {
            m, _ := min_in(column)
            switch _m in m {
            case int: p.coord.x_min = f64(_m)
            case f64: p.coord.x_min = _m
            case string, bool: 
                // TODO
                fmt.eprintln("Unexpected")
                return
            }
        }
        if p.coord.x_max == nil {
            m, _ := max_in(column)
            switch _m in m {
            case int: p.coord.x_max = f64(_m)
            case f64: p.coord.x_max = _m
            case string, bool: 
                // TODO
                fmt.eprintln("Unexpected")
                return
            }
        }
    }
    {
        column := get_columnslice(p.dataframe^, p.mapping.y) or_return
        if p.coord.y_min == nil {
            m, _ := min_in(column)
            switch _m in m {
            case int: p.coord.y_min = f64(_m)
            case f64: p.coord.y_min = _m
            case string, bool: 
                // TODO
                fmt.eprintln("Unexpected")
                return
            }
        }
        if p.coord.y_max == nil {
            m, _ := max_in(column)
            switch _m in m {
            case int: p.coord.y_max = f64(_m)
            case f64: p.coord.y_max = _m
            case string, bool: 
                // TODO
                fmt.eprintln("Unexpected")
                return
            }
        }
    }

    // Set up the output target, one panel per facet cell.
    raw_buf: []byte
    temp_path: string
    if format == .Png {
        raw_buf = make([]byte, shape.width * shape.height * shape.channels, allocator)
    } else {

        // TODO the following should be done by the backend code we call.
        // Gathering a temp dir string fails if there is an allocation error.
        temp_dir, temp_dir_err := os.temp_dir(context.temp_allocator)
        if temp_dir_err != nil do temp_dir = "/tmp"

        ext := "svg" if format == .Svg else "pdf"
        temp_path = fmt.tprintf("%s/odin_plot_output.%s", temp_dir, ext)
    }

    // TODO this dpi value is a random display dpi found on the internet.
    dpi := 96
    state := backend.init(format, shape, dpi, p.facet, p.theme.panel_background, temp_path, raw_buf)

    // TODO implement logic here.
    assert(p.facet == .None)
    {

        // TODO scales produce a subset of data, and should not be used for
        // transformations
        transform :=  PixelTransform{
            x_min  = p.coord.x_min.(f64),
            x_max  = p.coord.x_max.(f64),
            y_min  = p.coord.y_min.(f64),
            y_max  = p.coord.y_max.(f64),
            width  = shape.width,
            height = shape.height,
        }

        backend.panel_begin(state, 0, transform.x_min, transform.x_max, transform.y_min, transform.y_max)

        theme   := p.theme
        labels  := p.labels

        backend.set_color(state, theme.panel_background)
        backend.fill_rect(state, transform.x_min, transform.x_max, transform.y_min, transform.y_max)

        backend.set_font_size(state, theme.font_size)
        backend.set_color(state, theme.grid_color)
        backend.draw_frame(state, false)

        backend.set_color(state, theme.text_color)
        backend.draw_label(state, labels.x.(string), labels.y.(string), labels.title)

        for layer, i in p.layers{
            // TODO: we are assuming x and y are good
            x, _ := get_columnslice(p.dataframe^, layer.mapping.?.x)
            y, _ := get_columnslice(p.dataframe^, layer.mapping.?.y)
            xs, xs_ok := to_f64_slice(x)
            ys, ys_ok := to_f64_slice(y)

            if xs_ok == false || ys_ok == false {
                // TODO
                fmt.eprintln("Data could not be turned in to a float")
                return
            }

            // TODO users need to able to set the colors
            color := Default_Palette[i]

            switch g in layer.geom {
            case Point:
                backend.set_color(state, color)
                // TODO: update interface to accept an enum instead of a int.
                backend.draw_scatter(state, xs, ys, int(g.symbol_code), g.size)
            case Line:
                backend.set_color(state, color)
                backend.draw_line(state, xs, ys, g.linewidth)
            }
        }
    }

    // TODO draw legend

    _ = backend.finish(state) or_return

    switch format {
    case .Svg: 
        rt.width = shape.width
        rt.height = shape.height

        s := transmute(runtime.Raw_Slice)raw_buf
        d := runtime.Raw_Dynamic_Array{
            data = s.data,
            len = s.len,
            allocator = runtime.nil_allocator(),
        }
        rt.pixels = bytes.Buffer{
            buf = transmute([dynamic]u8)d,
        }

        rt.is_svg = true
        ok = true

    case .Png:
        // TODO: I am assuming there are 3 channels
        rgb_buf := ([^][3]u8)(raw_data(raw_buf))
        image := image.pixels_to_image(rgb_buf[:len(raw_buf)/3], shape.width, shape.height) or_return

        rt.image = image
        rt.is_svg = false
        ok = true
    }
    return 
}

// TODO think of a better name.
SaveError :: union {
    os.Error,
    bmp.Error
}

save :: proc(path: string, g: ^Graphic) -> SaveError {
    if g.is_svg {
        return os.write_entire_file(path, bytes.buffer_to_bytes(&g.pixels))
    } else {
        return bmp.save_to_file(path, &g.image)
    }
    return nil
}


// ============================== Backend ===================================
// The rendering contract the customer provided plotting library must implement to
// plug into this package's plotting interface. 
//
// Every proc takes an explicit `state: rawptr`. `init` must returns it, every
// later call receives it back, `finish` consumes it. A backend that keeps
// its own global state can ignore the param and
// return nil from `init`.

Backend :: struct {
    // Initializes any state a plotting library might require.
    // The initial implementation for this API is based off of what PLPlot requires.
    // Returns the state to pass to every other proc.
    init: proc(format: OutputFormat, shape: Shape, dpi: Dpi, facet: Facet, 
               background: Color, temp_path: string, png_buf: []byte) -> rawptr,

    // Advances to panel `index` of the facet grid and binds a world
    // coordinate window (x_min/x_max/y_min/y_max) to that panel's
    // viewport. Every subsequent draw_* call is interpreted in this
    // coordinate system until the next panel_begin.
    panel_begin: proc(state: rawptr, index: int, x_min, x_max, y_min, y_max: f64),

    // Sets character/label height for subsequent draw_frame/draw_label
    // calls. Units: points.
    set_font_size: proc(state: rawptr, size: f32),

    // Sets the color used by the next draw_* call. One "current color"
    // register, not separate fill/stroke state.
    set_color: proc(state: rawptr, c: Color),

    // Fills an axis-aligned rect in world coordinates with the current
    // color. Used for the panel background.
    fill_rect: proc(state: rawptr, x_min, x_max, y_min, y_max: f64),

    // Draws the panel frame and tick marks/numbers in the current color.
    // `show_grid` is explicit rather than baked into a magic opts string.
    draw_frame: proc(state: rawptr, show_grid: bool),

    // Draws axis captions and the panel title in the current color.
    draw_label: proc(state: rawptr, xlabel, ylabel, title: string),

    // ---- geom draws, one per Geom variant plot.odin currently supports ----

    draw_scatter: proc(state: rawptr, xs, ys: []f64, symbol: int, size: f32),
    draw_line: proc(state: rawptr, xs, ys: []f64, width: f32),

    // Flushes/serializes the output and returns the encoded bytes (raw
    // RGB for Png via png_buf, file contents for Svg/Pdf). Must be
    // called exactly once, after all panels are drawn. Consumes `state`.
    finish: proc(state: rawptr) -> ([]byte, bool),
}

/*
export LD_LIBRARY_PATH="$PWD/../plplot_bindings/PLplot/install/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PLPLOT_LIB="$PWD/../plplot_bindings/PLplot/install/share/plplot5.15.0"
*/
