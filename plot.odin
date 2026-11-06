package soda

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:math"
import "core:reflect"
import "core:slice"
import "core:strings"

import "graphic"
import rl "vendor:raylib"

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
    shape:      Shape,

    // Set by build_plot. Procedures that change the plot's definition clear it
    // so draw knows to rebuild.
    built:      bool,

    // Set by _construct_graphic during build_plot; draw passes them to
    // graphic.begin_graphic. The Plot owns the axis tick labels.
    graphic_element: graphic.Graphic,
    graphic_rect:    graphic.Rectangle,
    // Allocator the tick labels were made with, so they are freed with it.
    graphic_allocator: runtime.Allocator,

    backend: graphic.PlotBackend,
    panel: graphic.Panel  // TODO: I'm not sure this needs to be here.
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

Color :: rl.Color

GradientPalette :: struct { 
    low,
    high: Color
}

// Change to a struct see: https://r-graph-gallery.com/223-faceting-with-ggplot2.html
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
    x_min, x_max: Maybe(f64),
    y_min, y_max: Maybe(f64),
    ratio:        f32,
}

Theme :: struct {
    panel_background,
    plot_background,
    grid_color,
    text_color: Color,
    panel_title_font_size,
    plot_title_font_size,
    axis_label_font_size,
    axis_tick_font_size:  f32,
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
    height: int
}

DefaultTheme :: Theme {
    panel_background = rl.BEIGE,
    plot_background  = rl.WHITE,
    grid_color       = rl.GRAY,
    text_color       = rl.BLACK,
    // TODO: transition to Font struct
    panel_title_font_size = 36,
    plot_title_font_size  = 24,
    axis_label_font_size  = 18,
    axis_tick_font_size   = 18,

    // TODO: temp
    legend_position = .None,
}

N_TICKS :: 5

// TODO - I suspect this palette is doing nothing
// A small default categorical palette (ColorBrewer Set1-ish), used when no
// Scale{aesthetic = .Color} with a manual palette is attached to the plot.
DefaultPalette := []Color {
    rl.BLUE,
    rl.RED,
    rl.GREEN,
    rl.PINK
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
    using  image: rl.Image,
    is_svg: bool  // This is a stand in flag for more output types that are not handled by odin's image lib.
}

delete_graphic :: proc(g: Graphic, loc:= #caller_location) {
    rl.UnloadImage(g.image)
}

@(private="file")
_to_f64_slice :: proc(cs: ColumnSlice, allocator := context.temp_allocator) -> (out: []f64, ok: bool) {
    switch v in cs {
    case []int:
        buf := make([]f64, len(v), allocator)
        for it, i in v do buf[i] = f64(it)
        return buf, true
    case []f64:
        return v, true
    case []string:

        buf := make([]f64, len(v), allocator)

        cloned_data, err := slice.clone(v)
        slice.sort(cloned_data)
        unique_strings := slice.unique(cloned_data)

        for it, i in v {
            for jt, j in unique_strings {
                if it == jt do buf[i] = f64(j) / f64(len(unique_strings) - 1)
            }
        }
        return buf, true
    case []bool:
        return nil, false
    }
    return nil, false
}

// Evenly spaced tick labels from lo to hi inclusive, matching Ticks with
// first_tick_position = 0 and step_size = 1/(n-1).
@(private="file")
_axis_tick_labels_from_numerals :: proc(lo, hi: f64, n: int, allocator := context.allocator) -> []string {
    labels := make([]string, n, allocator)
    for i in 0..<n {
        v := lo + (hi - lo) * f64(i) / f64(n - 1)
        labels[i] = fmt.aprintf("%.3g", v, allocator = allocator)
    }
    return labels
}

@(private="file")
_axis_tick_labels_from_strings :: proc(data: []string, allocator := context.allocator) -> []string {
    data_clone := slice.clone(data, context.temp_allocator)
    slice.sort(data_clone)
    unique_data := slice.unique(data_clone)

    // Labels own their strings so they can be freed the same way as numeral
    // labels, independent of the dataframe.
    labels := make([]string, len(unique_data), allocator)
    for it, i in unique_data do labels[i] = strings.clone(it, allocator)
    return labels
}

// Frees labels made by _axis_tick_labels_from_numerals or
// _axis_tick_labels_from_strings.
@(private="file")
_delete_axis_tick_labels :: proc(labels: []string, allocator := context.allocator) {
    for it in labels do delete(it, allocator)
    delete(labels, allocator)
}

// TODO maybe remove _tick_step
@(private="file")
_init_axis_config :: proc(n: int, lo, hi: f64, tick_offset: Maybe(f64), tick_font: graphic.Font, data: ColumnSlice, allocator := context.allocator) -> graphic.Axis {

    labels : []string
    tick_step : f64

    first_tick_position : f64 = tick_offset.? or_else lo
    switch v in data {
    case []int, []f64: {
        labels = _axis_tick_labels_from_numerals(lo, hi, n, allocator)
        tick_step = (hi - lo) / f64(n - 1)
    }
    case []string: {
        labels = _axis_tick_labels_from_strings(v, allocator)
        first_tick_position = 0.0
        tick_step = 1.0 / f64(len(labels) - 1)
    }
    case []bool : {
        log.warn("plot: axis labels for boolean data are not yet supported.")
    }
    }

    graphic_axis := graphic.Axis {
        major_tick_config = graphic.Ticks {
            first_tick_position = f32(first_tick_position),
            step_size           = f32(tick_step),
            text_rotation       = 0,
            color               = tick_font.color,
            length              = 8,
            font                = tick_font,
        },
        major_tick_labels     = labels,
        major_tick_label_font = tick_font,
        minor_tick_config     = nil,
    }

    return graphic_axis
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
init_plot :: proc(df: $T, interactive:bool=false) -> Plot(T) 
where T == ^DataFrame || T == ^DataFrameSlice {
    plot := Plot(T) {
        dataframe = df,
        layers = make([dynamic]Layer, 0, 1),
    }

    assert(graphic.start_backend(interactive), "Failed to start rl.")
    backend, is_ok := graphic.start_plot_backend(interactive)
    assert(is_ok, "Failed to initialize plot.")

    plot.backend = backend

    return plot
}

build_plot :: proc(
    p: ^Plot($T),
    format: OutputFormat,
    shape := Shape{800, 600},
    allocator := context.allocator
) -> (ok: bool) {

    p.built = false
    _build_plot_theme_defaults(p)
    p.shape = shape
    
    // Layers need to be mapped to data. If mappings are not defined in either
    // mapping or layer the plot cannot be made. This checks at one if not both
    // are present.
    if p.mapping.x == "" || p.mapping.y == "" {
        for &layer in p.layers {
            if layer.mapping == nil do return
        }
    }

    if !_validate_mapping(p.dataframe, p.mapping) do return


    // Set labels to column names if labels have not been set.
    if p.labels.x == nil { p.labels.x = p.mapping.x }
    if p.labels.y == nil { p.labels.y = p.mapping.y }

    for &layer in p.layers {
        if layer.mapping == nil {
            layer.mapping = p.mapping
        }
    }

    // Set the min and max coordinates if they have not been defined.
    if p.coord.x_min == nil || p.coord.x_max == nil {

        column := get_columnslice(p.dataframe^, p.mapping.x) or_return
        x_min, x_max := _calc_range(column)

        for layer in p.layers {
            aes := layer.mapping.(Aesthetic)
            layer_column := get_columnslice(p.dataframe^, aes.x) or_return
            layer_x_min, layer_x_max := _calc_range(layer_column)

            x_min = min(x_min, layer_x_min)
            x_max = max(x_max, layer_x_max)
        }

        if p.coord.x_min == nil do p.coord.x_min = x_min - 0.2*math.sqrt(x_max - x_min)
        if p.coord.x_max == nil do p.coord.x_max = x_max + 0.2*math.sqrt(x_max - x_min)
    }

    if p.coord.y_min == nil || p.coord.y_max == nil {

        column := get_columnslice(p.dataframe^, p.mapping.y) or_return
        y_min, y_max := _calc_range(column)

        for layer in p.layers {
            aes := layer.mapping.(Aesthetic)
            layer_column := get_columnslice(p.dataframe^, aes.y) or_return
            layer_y_min, layer_y_max := _calc_range(layer_column)

            y_min = min(y_min, layer_y_min)
            y_max = max(y_max, layer_y_max)
        }

        if p.coord.y_min == nil do p.coord.y_min = y_min - 0.2*math.sqrt(y_max - y_min)
        if p.coord.y_max == nil do p.coord.y_max = y_max + 0.2*math.sqrt(y_max - y_min)
    }

    assert(p.facet == .None, "Error: facet was not .None. Other variants have not been implemented.")

    {  // Fill out panel
        p.panel.title = p.labels.title
        p.panel.title_alignment = .Left
        // TODO: change how we hard code things
        p.panel.title_position  = {
            10, 
            10
        }
        p.panel.font = graphic.Font {
            color = rl.BLACK,
            inner_font = graphic.DEFAULT_FONT_PANEL_TITLE
        }
        p.panel.color = p.theme.panel_background
    }

    _construct_graphic(p, allocator)

    p.built = true
    return true
}

// TODO: I'm am sure we are loosing memory, we will fix later.
// - add param for a dataframe just in case the user wants to use a different dataframe.
reset_plot :: proc(plot: ^Plot($T)) {
    clear_layers(plot)

    plot.scales = [ScaleAes]Scale{}
    plot.facet = .None
    plot.coord = Coord {}
    plot.theme = Theme {}
    plot.labels = Labels {}
    plot.built = false
}

add_mapping :: proc(plot: ^Plot($T), mapping: Aesthetic) {
    plot.mapping = mapping
    plot.built = false
}

add_scatter :: proc(plot: ^Plot($T), position:= Position.Identity, size:f32=1, alpha:f32=1, symbol_code:=PointSymbolCode.Dot, mapping:Maybe(Aesthetic)=nil) {
    append(&plot.layers, Layer{Point{size, alpha, symbol_code}, position, mapping})
    plot.built = false
}

clear_layers :: proc(plot: ^Plot($T)) {
    clear(&plot.layers)
    plot.built = false
}

delete_plot :: proc(plot: Plot($T)) {
    delete(plot.layers)
    if plot.graphic_allocator.procedure != nil {
        _delete_graphic_labels(plot.graphic_element, plot.graphic_allocator)
    }
}

// TODO
draw_interactive :: proc(
    p: ^Plot($T),
    shape := Shape{800, 600},
    allocator := context.allocator
) {
}

@(private="file")
_build_plot_theme_defaults :: proc(p: ^Plot($T)) {
    if p.theme.panel_title_font_size <= 0 {
        p.theme.panel_title_font_size = DefaultTheme.panel_title_font_size
    }
    if p.theme.plot_title_font_size <= 0 {
        p.theme.plot_title_font_size = DefaultTheme.plot_title_font_size
    }
    if p.theme.panel_background == {} {
        p.theme.panel_background = DefaultTheme.panel_background
    }
    if p.theme.plot_background == {} {
        p.theme.plot_background = DefaultTheme.plot_background
    }
    if p.theme.text_color == {} { p.theme.text_color = DefaultTheme.text_color }
    if p.theme.grid_color == {} { p.theme.grid_color = DefaultTheme.grid_color }
}

draw :: proc(
    p: ^Plot($T),
    format: OutputFormat,
    allocator := context.allocator
) -> (rt: Graphic, ok: bool) {  // TODO: return a descriptive error.

    // A plot that has not been built (or was changed since) is built here,
    // reusing the shape from an earlier build if there was one, so callers can
    // go straight to draw.
    if !p.built {
        shape := p.shape if p.shape != {} else Shape{800, 600}
        if !build_plot(p, format, shape, allocator) {
            log.error("plot: draw could not build the plot; check the mapping and layers.")
            return
        }
    }

    {
        graphic.begin_panel(p.panel, p.backend)

        graphic.begin_graphic(p.graphic_element, p.graphic_rect)

        bounds := _data_bounds(p)

        for layer, i in p.layers {
            x, _ := get_columnslice(p.dataframe^, layer.mapping.?.x)
            y, _ := get_columnslice(p.dataframe^, layer.mapping.?.y)
            xs, xs_ok := _to_f64_slice(x)
            ys, ys_ok := _to_f64_slice(y)

            if xs_ok == false || ys_ok == false {
                // TODO
                log.error("plot: layer data could not be converted to floats.")
                return
            }

            // GL vertex buffers are f32, so the values are only narrowed here.
            x_values := make([]f32, len(xs), context.temp_allocator)
            for it, j in xs do x_values[j] = f32(it)
            y_values := make([]f32, len(ys), context.temp_allocator)
            for it, j in ys do y_values[j] = f32(it)

            switch g in layer.geom {
            // TODO: we don't use any the aspects of the Point struct
            case Point:
                // TODO: we should calculate this every time
                scatter_index := graphic.make_scatter_point_buffer(x_values, y_values, &p.backend)
                graphic.draw_data_scatter(
                    .Circle,
                    p.backend.vertex_map[scatter_index],
                    bounds,
                    DefaultPalette[i],
                    p.backend,
                )
            case Line:
                panic("Error: Line has not been implemented.")
            }
        }

        graphic.end_graphic(p.graphic_element)
    }
    // TODO: draw legend

    graphic.end_panel(p.backend)

    #partial switch format {
    case .Png: 
        rt.image, ok = graphic.store_frame(p.backend)
    }
    return 
}

// TODO think of a better name.
SaveError :: union {
    os.Error,
}

save_graphic :: proc(path: string, g: ^Graphic) -> SaveError {
    if g.is_svg {
        panic("svg not implemented.")
    } else {
        graphic.save_frame(g.image, path)
    }
    return nil
}

_validate_mapping :: proc(df: ^DataFrame, mapping: Aesthetic) -> (is_ok: bool) {

    is_ok = true
    for field in reflect.struct_fields_zipped(Aesthetic) {
        value := reflect.struct_field_value(mapping, field) // returns `any`
        column_name  := value.(string)

        if column_name == "" do continue

        _, column_exist := get_columnslice(df^, column_name)
        if !column_exist {
            log.errorf("plot: mapping.%v = %q does not exist.",
                field.name, column_name)
            is_ok = false
        }
    }

    return
}

_calc_range :: proc(column: ColumnSlice) -> (v_min, v_max: f64) {
    v_min = math.F32_MAX
    v_max = math.F32_MIN

    min_value, max_value, _ := range(column)

    switch _m in min_value {
    case int: {
        v_min = min(f64(_m), v_min)
        v_max = max(f64(max_value.(int)), v_max)
    }
    case f64: {
        v_min = min(_m, v_min)
        v_max = max(max_value.(f64), v_max)
    }
    case string, bool: {
        v_min = 0
        v_max = 1
    }
    }
    return 
}

// Data is uploaded in data units; the point shader maps it into the plot area
// using these bounds.
@(private="file")
_data_bounds :: proc(p: ^Plot($T)) -> graphic.DataBounds {
    return graphic.DataBounds {
        min = {f32(p.coord.x_min.(f64)), f32(p.coord.y_min.(f64))},
        max = {f32(p.coord.x_max.(f64)), f32(p.coord.y_max.(f64))},
    }
}

@(private="file")
_delete_graphic_labels :: proc(g: graphic.Graphic, allocator := context.allocator) {
    _delete_axis_tick_labels(g.x_axis.major_tick_labels, allocator)
    _delete_axis_tick_labels(g.y_axis.major_tick_labels, allocator)
}

// Fills p.graphic_element and p.graphic_rect from the plot's coord, labels,
// theme and backend. Called by build_plot after coord and labels are resolved.
// Labels from a previous construction are freed first.
@(private="file")
_construct_graphic :: proc(p: ^Plot($T), allocator := context.allocator) {
    if p.graphic_allocator.procedure != nil {
        _delete_graphic_labels(p.graphic_element, p.graphic_allocator)
    }
    p.graphic_allocator = allocator

    graphic_element : graphic.Graphic

    tick_font  := graphic.Font{
        inner_font = graphic.DEFAULT_FONT_AXIS_TICK_LABEL,
        color = p.theme.text_color
    }
    title_font := graphic.Font{
        inner_font = graphic.DEFAULT_FONT_GRAPHIC_TITLE,
        color = p.theme.text_color
    }

    // TODO: when the column is a string, then N_TICKS is the number of unique strings
    // TODO: we need a algo to determine the first tick position value.
    // IDEA: take the range to determine the order of magnitude. Use
    // that to determine the closest and least value to the minimum.
    // this will help determine the first_tick_position.

    x_slice, _ := get_columnslice(p.dataframe^, p.layers[0].mapping.?.x)
    graphic_element.x_axis = _init_axis_config(
        N_TICKS,
        p.coord.x_min.(f64),
        p.coord.x_max.(f64),
        nil,
        tick_font,
        x_slice,
        allocator,
    )
    graphic_element.x_axis.minor_tick_config = nil
    graphic_element.x_axis.title             = p.labels.x.(string)
    graphic_element.x_axis.title_font        = title_font
    graphic_element.x_axis.title_alignment   = .Center
    graphic_element.x_axis.title_rotation    = 0
    graphic_element.x_axis.color             = tick_font.color

    y_slice, _ := get_columnslice(p.dataframe^, p.layers[0].mapping.?.y)
    graphic_element.y_axis = _init_axis_config(
        N_TICKS,
        p.coord.y_min.(f64),
        p.coord.y_max.(f64),
        nil,
        tick_font,
        y_slice,
        allocator,
    )
    graphic_element.y_axis.title           = p.labels.y.(string)
    graphic_element.y_axis.title_font      = title_font
    graphic_element.y_axis.title_alignment = .Center
    graphic_element.y_axis.title_rotation  = -math.PI / 2
    graphic_element.y_axis.color           = tick_font.color

    graphic_element.x_axis_grid = true
    graphic_element.y_axis_grid = true

    // TODO: will need to update when adding the ability to render many
    // plots on the same panel.
    graphic_element.title = ""
    graphic_element.font  = graphic.Font {
        graphic.DEFAULT_FONT_PANEL_TITLE,
        rl.BLACK
    }
    graphic_element.title_alignment  = .Left
    graphic_element.background_color = rl.WHITE
    graphic_element.plot_color       = {75, 75, 75, 255}

    // Ticks are drawn on the CPU by end_graphic, so their positions are
    // normalized to 0-1 across the plot area here.
    {
        bounds := _data_bounds(p)
        range  := bounds.max - bounds.min
        x_ticks := &graphic_element.x_axis.major_tick_config
        x_ticks.first_tick_position = (x_ticks.first_tick_position - bounds.min.x) / range.x
        x_ticks.step_size /= range.x

        y_ticks := &graphic_element.y_axis.major_tick_config
        y_ticks.first_tick_position = (y_ticks.first_tick_position - bounds.min.y) / range.y
        y_ticks.step_size /= range.y
    }

    p.graphic_element = graphic_element
    p.graphic_rect = graphic.Rectangle {
        p.panel.title_position.x,
        40,
        f32(p.backend.render_texture.texture.width) - 2 * p.panel.title_position.x,
        f32(p.backend.render_texture.texture.height) - 60
    }
}
