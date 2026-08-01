package soda 

import "core:fmt"
import "core:io"
import "core:slice"
import "core:strings"

// TODO in core:text/table there is code to do exactly what I'm doing here. Can we use that instead?

dataframe_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    m := cast(^DataFrame)arg.data
    return _dataframe_formater(m, fi, verb)
}


dataframeslice_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    m := cast(^DataFrameSlice)arg.data
    return _dataframe_formater(m, fi, verb)
}

column_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    m := cast(^Column)arg.data
    return _column_formatter(m, fi, verb)
}

columnslice_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {
    m := cast(^ColumnSlice)arg.data
    return _column_formatter(m, fi, verb)
}

@(private="file")
_dataframe_formater :: proc(m: $T, fi: ^fmt.Info, verb: rune) -> bool 
where T == ^DataFrame || T == ^DataFrameSlice
{
    switch verb {
    case 'v': {
        sb := strings.Builder{}
        strings.builder_init(&sb)
        defer strings.builder_destroy(&sb)

        // TODO
        // This is hacked in an doesn't look nice... next step make it look
        // nice by indicating that we've removed the columns inbetween
        column_names := make([dynamic]string, 0, min(5, len_dataframe(m)), context.temp_allocator)
        if len_dataframe(m) > 5 {
            i := 0
            for key in m.data {
                append(&column_names, key)
                if i == 4 {
                    break
                }
                i += 1
            }
        } else {
            for key in m.data {
                append(&column_names, key)
            }
        }
        slice.sort(column_names[:])
        n_cols := len(column_names)

        // Mirror polars/pandas: show every row for small frames, otherwise
        // the first and last few rows with a "..." row in between.
        MAX_ROWS  :: 10
        HEAD_TAIL :: 5
        row_indices := make([dynamic]int, 0, MAX_ROWS + 1, context.temp_allocator)
        if m.n_rows <= MAX_ROWS {
            for i in 0..<m.n_rows {
                append(&row_indices, i)
            }
        } else {
            for i in 0..<HEAD_TAIL {
                append(&row_indices, i)
            }
            append(&row_indices, -1)
            for i in m.n_rows - HEAD_TAIL..<m.n_rows {
                append(&row_indices, i)
            }
        }

        dtypes := make([]string, n_cols, context.temp_allocator)
        widths := make([]int, n_cols, context.temp_allocator)
        for name, ci in column_names {
            dtypes[ci] = _df_fmt_dtype(m.data[name])
            widths[ci] = max(len(name), len(dtypes[ci]), len("---"))
        }

        grid := make([][]string, len(row_indices), context.temp_allocator)
        for row, ri in row_indices {
            cells := make([]string, n_cols, context.temp_allocator)
            for name, ci in column_names {
                cell := row == -1 ? "..." : _df_fmt_cell(m.data[name], row)
                cells[ci] = cell
                widths[ci] = max(widths[ci], len(cell))
            }
            grid[ri] = cells
        }

        placeholders := make([]string, n_cols, context.temp_allocator)
        for _, i in placeholders {
            placeholders[i] = "---"
        }

        strings.write_string(&sb, fmt.tprintf("shape: (%d, %d)\n", m.n_rows, n_cols))
        _df_fmt_border(&sb, widths, "┌", "┬", "┐", "─")
        _df_fmt_row(&sb, column_names[:], widths)
        _df_fmt_row(&sb, placeholders, widths)
        _df_fmt_row(&sb, dtypes, widths)
        _df_fmt_border(&sb, widths, "╞", "╪", "╡", "═")
        for cells in grid {
            _df_fmt_row(&sb, cells, widths)
        }
        _df_fmt_border(&sb, widths, "└", "┴", "┘", "─")

        n, _ := io.write_string(fi.writer, strings.to_string(sb))
        fi.n += n
    }
    case: {
        return false
    }
    }
    return true
}

@(private="file")
_column_formatter :: proc(m: $T, fi: ^fmt.Info, verb: rune) -> bool
where T == ^Column || T == ^ColumnSlice
{
    switch verb {
    case 'v': {
        sb := strings.Builder{}
        strings.builder_init(&sb)
        defer strings.builder_destroy(&sb)

        n_rows := len_column(m^)
        dtype := _df_fmt_dtype(m^)
        width := max(len(dtype), len("---"))

        // Mirror the DataFrame formatter: show every value for small
        // columns, otherwise the first and last few with a "..." in between.
        MAX_ROWS  :: 10
        HEAD_TAIL :: 5
        row_indices := make([dynamic]int, 0, MAX_ROWS + 1, context.temp_allocator)
        if n_rows <= MAX_ROWS {
            for i in 0..<n_rows {
                append(&row_indices, i)
            }
        } else {
            for i in 0..<HEAD_TAIL {
                append(&row_indices, i)
            }
            append(&row_indices, -1)
            for i in n_rows - HEAD_TAIL..<n_rows {
                append(&row_indices, i)
            }
        }

        cells := make([]string, len(row_indices), context.temp_allocator)
        for row, ri in row_indices {
            cell := row == -1 ? "..." : _df_fmt_cell(m^, row)
            cells[ri] = cell
            width = max(width, len(cell))
        }

        widths := []int{width}

        strings.write_string(&sb, fmt.tprintf("shape: (%d,)\n", n_rows))
        _df_fmt_border(&sb, widths, "┌", "┬", "┐", "─")
        _df_fmt_row(&sb, []string{dtype}, widths)
        _df_fmt_row(&sb, []string{"---"}, widths)
        _df_fmt_border(&sb, widths, "╞", "╪", "╡", "═")
        for cell in cells {
            _df_fmt_row(&sb, []string{cell}, widths)
        }
        _df_fmt_border(&sb, widths, "└", "┴", "┘", "─")

        n, _ := io.write_string(fi.writer, strings.to_string(sb))
        fi.n += n
    }
    case: {
        return false
    }
    }
    return true
}

@(private="file")
_df_fmt_dtype :: proc {_df_fmt_dtype_column, _df_fmt_dtype_column_slice}

@(private="file")
_df_fmt_dtype_column :: proc(c: Column) -> string {
    switch _ in c {
    case [dynamic]int:    return "int"
    case [dynamic]f64:    return "f64"
    case [dynamic]string: return "str"
    case [dynamic]bool:   return "bool"
    }
    return "?"
}

@(private="file")
_df_fmt_dtype_column_slice :: proc(c: ColumnSlice) -> string {
    switch _ in c {
    case []int:    return "int"
    case []f64:    return "f64"
    case []string: return "str"
    case []bool:   return "bool"
    }
    return "?"
}

@(private="file")
_df_fmt_cell :: proc{_df_fmt_cell_column, _df_fmt_cell_column_slice}

@(private="file")
_df_fmt_cell_column :: proc(c: Column, row: int) -> string {
    switch v in c {
    case [dynamic]int:    return fmt.tprintf("%d", v[row])
    case [dynamic]f64:    return fmt.tprintf("%e", v[row])
    case [dynamic]string: return v[row]
    case [dynamic]bool:   return fmt.tprintf("%v", v[row])
    }
    return ""
}

@(private="file")
_df_fmt_cell_column_slice :: proc(c: ColumnSlice, row: int) -> string {
    switch v in c {
    case []int:    return fmt.tprintf("%d", v[row])
    case []f64:    return fmt.tprintf("%4.4e", v[row])
    case []string: return v[row]
    case []bool:   return fmt.tprintf("%v", v[row])
    }
    return ""
}


@(private="file")
_df_fmt_pad :: proc(sb: ^strings.Builder, s: string, width: int) {
    strings.write_string(sb, s)
    for _ in 0..<width - len(s) {
        strings.write_byte(sb, ' ')
    }
}

// Draws a border line, e.g. "┌─────┬───────┐".
@(private="file")
_df_fmt_border :: proc(sb: ^strings.Builder, widths: []int, left, mid, right, fill: string) {
    strings.write_string(sb, left)
    for w, i in widths {
        for _ in 0..<w + 2 {
            strings.write_string(sb, fill)
        }
        if i < len(widths) - 1 {
            strings.write_string(sb, mid)
        }
    }
    strings.write_string(sb, right)
    strings.write_byte(sb, '\n')
}

// Draws a content line, e.g. "│ a   ┆ b     │".
@(private="file")
_df_fmt_row :: proc(sb: ^strings.Builder, cells: []string, widths: []int) {
    strings.write_string(sb, "│ ")
    for cell, i in cells {
        _df_fmt_pad(sb, cell, widths[i])
        if i < len(cells) - 1 {
            strings.write_string(sb, " ┆ ")
        }
    }
    strings.write_string(sb, " │\n")
}
