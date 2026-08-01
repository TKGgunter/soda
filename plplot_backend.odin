package soda

import "core:fmt"
import "core:os"
import "base:runtime"
import pl "../plplot_bindings"

// ============================== PLplot backend =============================
// The Backend implementation (see backend.odin) built on plplot_bindings.
// plot.odin never imports plplot_bindings directly -- everything PLplot-
// specific lives here.

PLplot_State :: struct {
    format:    OutputFormat,
    png_buf:   []byte,
    temp_path: string,
}

// PLplot device keyword per OutputFormat. Png uses the "mem" driver (raw
// RGB straight into a buffer we own, no file I/O -- encoding those raw
// bytes into an actual .png happens outside this package). Svg uses
// PLplot's native "svg" driver (no cairo needed) and round-trips through a
// temp file, same as Pdf would -- but this build of libplplot.so has no
// cairo and thus no pdf-capable driver at all ("plsdev help" lists only
// xwin/ps/psc/xfig/null/mem/svg), so Pdf has no working device name yet.
plplot_device_name :: proc(format: OutputFormat) -> cstring {
    switch format {
    case .Png: return "mem"
    case .Svg: return "svg"
    }
    return "mem"
}

// Opens a PLplot stream sized for one subpage per facet cell (device,
// subpage grid, page size). Per-panel viewport/window setup happens in
// plplot_panel_begin instead, right alongside that panel's actual drawing
// -- PLplot tracks "current subpage" as global stream state, so setting
// every panel's window up front (before anything is drawn into it) would
// leave the stream positioned on only the last one.
//
// Exactly one of temp_path/png_buf is used, depending on format: the mem
// driver (Png) writes into png_buf directly, while the cairo file drivers
// (Svg/Pdf) write to temp_path via plsfnam.
plplot_init :: proc(format: OutputFormat, size: Shape, dpi: int, facet: Facet, background: Color, temp_path: string, png_buf: []byte) -> rawptr {
    pl.set_device(plplot_device_name(format))
    if format == .Png {
        pl.set_memory_buffer(pl.PLINT(size.width), pl.PLINT(size.height), raw_data(png_buf))
    } else {
        pl.set_output_file_name(fmt.ctprintf("%s", temp_path))
    }

    // Page background (the canvas area outside the panel, e.g. margins) is
    // a separate driver-level color from the panel fill drawn by
    // plplot_fill_rect, and must be set before plinit() -- drivers read it
    // at init time. Left unset, it defaults to black.
    pl.set_background_color_alpha(
        pl.PLINT(background[0]),
        pl.PLINT(background[1]),
        pl.PLINT(background[2]),
        pl.PLFLT(background[3]) / 255.0
    )
    // TODO this is a hack to get a white background when rendering to a memory.
    runtime.memset(raw_data(png_buf), transmute(i32)(u32(0xFF_FF_00_FF)), len(png_buf))

    nrow, ncol := 1, 1  // TODO: facet_grid_dims(facet)
    pl.set_subpage_layout(i32(ncol), i32(nrow))
    pl.set_page_params(0, 0, i32(size.width), i32(size.height), 0, 0)
    pl.init_plot()

    // TODO: interesting, we are new-ing here.
    state := new(PLplot_State)
    state.format    = format
    state.png_buf   = png_buf
    state.temp_path = temp_path
    return state
}

// plinit() leaves cursub at 0 (plP_subpInit resets it) -- subpage bounds
// aren't computed until the first pladv, so this must run for panel 0 too.
// Skipping it left plvsta() computing margins against a zero-sized
// subpage, collapsing xmin == xmax and aborting plvpor with "Invalid
// limits". PLplot only supports advancing to the *next* subpage, not
// random access, so `index` is unused here.
plplot_panel_begin :: proc(state: rawptr, index: int, x_min, x_max, y_min, y_max: f64) {
    pl.advance_page(0)
    pl.set_viewport_standard()
    pl.set_world_window(x_min, x_max, y_min, y_max)
}

// theme.font_size is a point size, but plschr's second argument is a
// *scale factor* on PLplot's own auto-computed default char height (chrht
// = scale * chrdef) -- passing a point size straight through as scale
// made text (and plvsta's margins) far too large, collapsing the viewport
// and aborting plvpor with "Invalid limits". Pass an absolute height in mm
// via `def` instead.
plplot_set_font_size :: proc(state: rawptr, size: f32) {
    // TODO what are these constants?
    mm := pl.PLFLT(size) * 25.4 / 72.0
    pl.set_char_height(mm, 1)
}

// Sets PLplot's current color (map 0, index 0) to c, including alpha, so
// subsequent draw calls (plfill, plbox, plline, plpoin, ...) use it.
plplot_set_color :: proc(state: rawptr, c: Color) {
    pl.set_palette0_color_alpha(
        0,
        pl.PLINT(c[0]),
        pl.PLINT(c[1]),
        pl.PLINT(c[2]),
        pl.PLFLT(c[3]) / 255.0
    )
    pl.set_color0(0)
}

plplot_fill_rect :: proc(state: rawptr, x_min, x_max, y_min, y_max: f64) {
    pl.set_fill_style(1)
    // TODO
    // pl.set_fill_style(0)
    bx := [4]f64{x_min, x_max, x_max, x_min}
    by := [4]f64{y_min, y_min, y_max, y_max}
    pl.fill_polygon(4, raw_data(bx[:]), raw_data(by[:]))
}

// No 'g' (grid) flag unless show_grid: just the frame, ticks, and numeric
// labels by default -- internal gridlines aren't part of the default look
// (see Theme_Default_Grid in plot.odin).
plplot_draw_frame :: proc(state: rawptr, show_grid: bool) {
    xopt: cstring = "bcnstg" if show_grid else "bcnst"
    yopt: cstring = "bcnstgv" if show_grid else "bcnstv"
    pl.draw_box(xopt, 0, 0, yopt, 0, 0)
}

plplot_draw_label :: proc(state: rawptr, xlabel, ylabel, title: string) {
    pl.draw_axis_labels(fmt.ctprintf("%s", xlabel), fmt.ctprintf("%s", ylabel), fmt.ctprintf("%s", title))
}

plplot_draw_scatter :: proc(state: rawptr, xs, ys: []f64, symbol: int, size: f32) {
    if size > 0 do pl.set_symbol_height(0, pl.PLFLT(size))
    
    pl.draw_points(
        pl.PLINT(len(xs)),
        raw_data(xs),
        raw_data(ys),
        pl.PLINT(symbol)
    )
}

plplot_draw_line :: proc(state: rawptr, xs, ys: []f64, width: f32) {
    if width > 0 do pl.set_pen_width(pl.PLFLT(width))
    pl.draw_line(pl.PLINT(len(xs)), raw_data(xs), raw_data(ys))
}

plplot_draw_histogram :: proc(state: rawptr, centers, counts: []f64) {
    pl.draw_bins(
        pl.PLINT(len(counts)),
        raw_data(centers),
        raw_data(counts),
        pl.PL_BIN_CENTRED
    )
}

// TODO 
// plplot does not assist the user in determining a good place to plop the
// legend. Additionally, we need to keep track of what plots, are generated the
// color and symbols used for data points.
/*
plplot_draw_legend :: proc(state: rawptr) {
    pl.draw_legend(
      p_legend_width: PLFLT_NC_SCALAR,
      p_legend_height: PLFLT_NC_SCALAR,
      opt: PLINT,
      position: PLINT,
      x: PLFLT,
      y: PLFLT,
      plot_width: PLFLT,
      bg_color: PLINT,
      bb_color: PLINT,
      bb_style: PLINT,
      nrow: PLINT,
      ncolumn: PLINT,
      nlegend: PLINT,
      opt_array: PLINT_VECTOR,
      text_offset: PLFLT,
      text_scale: PLFLT,
      text_spacing: PLFLT,
      text_justification: PLFLT,
      text_colors: PLINT_VECTOR,
      text: PLCHAR_MATRIX,
      box_colors: PLINT_VECTOR,
      box_patterns: PLINT_VECTOR,
      box_scales: PLFLT_VECTOR,
      box_line_widths: PLFLT_VECTOR,
      line_colors: PLINT_VECTOR,
      line_styles: PLINT_VECTOR,
      line_widths: PLFLT_VECTOR,
      symbol_colors: PLINT_VECTOR,
      symbol_scales: PLFLT_VECTOR,
      symbol_numbers: PLINT_VECTOR,
      symbols: PLCHAR_MATRIX)
}
*/

// Flushes/serializes the output and returns the encoded bytes. plend()
// runs here, not deferred: it's what flushes png_buf (mem driver) / the
// cairo file at temp_path, so reading either before this point would race
// an unflushed stream.
//
// Uses context.allocator for the Svg/Pdf read-back rather than threading
// draw()'s `allocator` param through Backend -- the contract doesn't carry
// one. Only matters if a caller passes draw() a non-default allocator.
plplot_finish :: proc(state: rawptr) -> ([]byte, bool) {
    s := (^PLplot_State)(state)
    defer free(s)
    pl.end_session()

    if s.format == .Png {
        return s.png_buf, true
    }

    bytes, err := os.read_entire_file(s.temp_path, context.allocator)
    os.remove(s.temp_path)
    return bytes, err == nil
}

plplot_backend := Backend{
    init           = plplot_init,
    panel_begin    = plplot_panel_begin,
    set_font_size  = plplot_set_font_size,
    set_color      = plplot_set_color,
    fill_rect      = plplot_fill_rect,
    draw_frame     = plplot_draw_frame,
    draw_label     = plplot_draw_label,
    draw_scatter   = plplot_draw_scatter,
    draw_line      = plplot_draw_line,
    finish         = plplot_finish,
}
