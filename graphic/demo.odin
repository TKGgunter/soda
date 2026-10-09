package graphic

import "core:math"
import rl "vendor:raylib"


main :: proc() {
    interactive := true
    fonts := []InnerFont{
        {16, "Inter_24pt-Light.ttf"},
        {16, "Inter_24pt-Medium.ttf"},
        {32, "Inter_24pt-Medium.ttf"},
    }

    backend, is_ok := start_backend(interactive, fonts)
    defer close_backend(backend)

    panel := Panel {
        rl.BEIGE,
        "Testing Panel",
        .Left,
        {0, 0},
        Font {
            InnerFont {32,
            "Inter_24pt-Medium.ttf"},
            rl.BLACK,
        }
    }

    graphic := Graphic {
        Axis {
            Ticks {
                0, //first_tick_position: f32,
                0.5, //step_size: f32,
                0, //text_rotation: f32,
                rl.BLACK, //color: Color,
                2, // length: f32,
                Font {
                    InnerFont { 16,
                    "Inter_24pt-Light.ttf" },
                    rl.BLACK,
                }
            },
            {"1", "2", "3"},
            Font {
                InnerFont { 16,
                "Inter_24pt-Light.ttf"},
                rl.BLACK,
            },
            nil, // minor_tick_config: Maybe(Ticks),
            "x axis", //title: string,
            Font {
                InnerFont {
                    16,
                    "Inter_24pt-Medium.ttf"
                },
                rl.BLACK,
            },
            .Center, //title_alignment: Alignment,
            0, //math.PI / 2, //title_rotation: f32,
            rl.BLACK // color: Color
        },
        Axis {
            Ticks {
                0, //first_tick_position: f32,
                0.5, //step_size: f32,
                0, //text_rotation: f32,
                rl.BLACK, //color: Color,
                2, // length: f32,
                Font {
                    InnerFont { 16,
                    "Inter_24pt-Light.ttf"},
                    rl.BLACK,
                }
            },
            {"1", "2", "3"},
            Font {
                InnerFont {16,
                "Inter_24pt-Light.ttf"},
                rl.BLACK,
            },
            nil, // minor_tick_config: Maybe(Ticks),
            "y axis", //title: string,
            Font {
                InnerFont {
                16,
                "Inter_24pt-Medium.ttf"},
                rl.BLACK,
            },
            .Center, //title_alignment: Alignment,
            -math.PI / 2, //title_rotation: f32,
            rl.BLACK // color: Color
        },
        true, //x_axis_grid: bool,
        true, //y_axis_grid: bool,

        "Graph 1", //title: string,
        {0, 0}, //title_position: [2]f32,
        Font {
            InnerFont {
                16,
                "Inter_24pt-Medium.ttf"},
            rl.BLACK,
        },
        .Left,

        // background color
        rl.WHITE,
        rl.WHITE,
    }

    width := f32(backend.render_texture.texture.width)
    height := f32(backend.render_texture.texture.height)
    dst_rect := Rectangle {
        50,
        50,
        f32(backend.render_texture.texture.width) - 100,
        f32(backend.render_texture.texture.height) - 100,
    }

    // We need to make sure we scale the data set to between 0-1.
    x_values := []f32{0, 0.1 , 0.20, 0.30, 0.50, 0.7, 0.9}
    y_values := []f32{0, 0.11, 0.22, 0.28, 0.50, 0.7, 0.9}
    scatter_index := make_scatter_point_buffer(x_values, y_values, &backend)

    for !rl.WindowShouldClose() {
        begin_panel(panel, backend)

        // axis is off.
        begin_graphic(graphic, dst_rect)

            draw_data_scatter(
                .Circle,
                backend.vertex_map[scatter_index],
                rl.BLUE,
                backend
            )

        end_graphic(graphic)

        end_panel(backend)
    }
}
