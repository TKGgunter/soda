// Made primarily with Claude ai.
package soda 

import "base:runtime"
import "core:encoding/csv"
import "core:strconv"
import "core:strings"
import "core:text/match"
import "core:os"

Cell :: union {
    int,
    f64,
    string,
    bool,
}

Column_Type :: enum {
    Int,
    Float,
    String,
    Boolean,
}

Parse_Error :: union {
    csv.Error,
    Empty_CSV_Error,
    Type_Mismatch_Error,
    os.Error,
}

Empty_CSV_Error :: struct {}

// Type_Mismatch_Error is returned when a cell's value doesn't match the type
// determined for its column, from a type-hint row or from sampling data rows.
Type_Mismatch_Error :: struct {
    row:      int,
    column:   int,
    expected: Column_Type,
}

// Reads CSV data from a file into a DataFrame.
read_csv :: proc(file: ^os.File, allocator := context.allocator) -> (df: DataFrame, err: Parse_Error) {
    buf, file_err := os.read_entire_file(file, allocator)
    defer delete(buf)

    if file_err != nil {
        return df, file_err
    }

    return parse_csv(string(buf), allocator)
}

// reads CSV data into a DataFrame. Column types come from an optional
// type-hint row (row 1) or are otherwise detected from a small sample of
// data rows; a cell that doesn't match its column's type fails the parse.
parse_csv :: proc(data: string, allocator := context.allocator) -> (df: DataFrame, err: Parse_Error) {
    context.allocator = allocator

    it: Table_Iterator
    err = iterator_init(&it, data, allocator)
    defer iterator_destroy(&it)
    if err != nil {
        return
    }

    n_cols := len(it.headers)
    columns := make([]Column, n_cols, allocator)
    for col_type, i in it.column_types {
        switch col_type {
        case .Int:    columns[i] = make([dynamic]int, 0, it.n_rows, allocator)
        case .Float:  columns[i] = make([dynamic]f64, 0, it.n_rows, allocator)
        case .String: columns[i] = make([dynamic]string, 0, it.n_rows, allocator)
        case .Boolean: columns[i] = make([dynamic]bool, 0, it.n_rows, allocator)
        }
    }

    n_rows := 0
    for {
        row, row_err, more := iterator_next(&it)
        if !more {
            if row_err != nil {
                err = row_err
            }
            break
        }

        for cell, j in row {
            switch &c in columns[j] {
            case [dynamic]int:    append(&c, cell.(int))
            case [dynamic]f64:    append(&c, cell.(f64))
            case [dynamic]string: append(&c, cell.(string))
            case [dynamic]bool: append(&c, cell.(bool))
            }
        }
        delete(row, it._allocator)
        n_rows += 1
    }

    if err != nil {
        for c in columns {
            switch v in c {
            case [dynamic]int: delete(v)
            case [dynamic]f64: delete(v)
            case [dynamic]string:
                for s in v {
                    delete(s, allocator)
                }
                delete(v)
            case [dynamic]bool: delete(v)
            }
        }
        delete(columns)
        return
    }

    data := make(map[string]Column, allocator)
    for header, i in it.headers {
        data[strings.clone(header, allocator)] = columns[i]
    }
    delete(columns)

    df = DataFrame{n_rows = n_rows, data = data}
    return
}

@(private)
_is_type_hint_row :: proc(row: []string) -> bool {
    for field in row {
        if field == "" {
            continue
        }
        lower := strings.to_lower(field, context.temp_allocator)
        switch lower {
        case "int", "integer", "i":
        case "float", "f64", "f":
        case "string", "str", "s":
        case "boolean", "bool", "b":
        case:
            return false
        }
    }
    return true
}

@(private)
_parse_type_hint_row :: proc(row: []string, n_cols: int, allocator := context.allocator) -> []Column_Type {
    types := make([]Column_Type, n_cols, allocator)
    for &t in types {
        t = .String
    }
    for field, i in row {
        if i >= n_cols {
            break
        }
        lower := strings.to_lower(field, context.temp_allocator)
        switch lower {
        case "int", "integer", "i":
            types[i] = .Int
        case "float", "f64", "f":
            types[i] = .Float
        case "string", "str", "s":
            types[i] = .String
        case "boolean", "bool", "b":
            types[i] = .Boolean
        case:
            types[i] = .String
        }
    }
    return types
}

@(private)
_detect_column_types :: proc(rows: [][]string, n_cols: int, allocator := context.allocator) -> []Column_Type {
    types := make([]Column_Type, n_cols, allocator)

    for col in 0 ..< n_cols {
        all_int := true
        all_float := true

        for row in rows {
            if col >= len(row) {
                continue
            }
            field := strings.trim_space(row[col])
            if field == "" {
                continue
            }

            if all_int {
                _, int_ok := strconv.parse_int(field)
                if !int_ok {
                    all_int = false
                }
            }
            if all_float {
                _, float_ok := strconv.parse_f64(field)
                if !float_ok {
                    all_float = false
                }
            }
        }

        switch {
        case all_int:
            types[col] = .Int
        case all_float:
            types[col] = .Float
        case:
            types[col] = .String
        }
    }

    return types
}

// convert_cell parses a raw field against the type decided for its column.
// ok is false when the field doesn't match that type (including a blank
// field in an Int/Float column), which callers surface as a Type_Mismatch_Error.
@(private)
_convert_cell :: proc(s: string, col_type: Column_Type, allocator := context.allocator) -> (cell: Cell, ok: bool) {
    field := strings.trim_space(s)
    switch col_type {
    case .Int:
        v, parse_ok := strconv.parse_int(field)
        if !parse_ok {
            return nil, false
        }
        return v, true
    case .Float:
        v, parse_ok := strconv.parse_f64(field)
        if !parse_ok {
            return nil, false
        }
        return v, true
    case .String:
        return strings.clone(field, allocator), true
    case .Boolean:
        v, parse_ok := strconv.parse_bool(field)
        if !parse_ok {
            return nil, false
        }
        return v, true
    }
    return nil, false
}

// ---------------------------------------------------------------------------
// Iterator API
// ---------------------------------------------------------------------------

// Table_Iterator streams one typed row at a time without loading the full CSV
// into memory. Column types come from an optional type-hint row (row 1); if
// none is present, they're detected from a small sample (up to 2 data rows)
// peeked ahead during iterator_init.
Table_Iterator :: struct {
    reader:       csv.Reader,
    headers:      []string,
    column_types: []Column_Type,
    n_rows:       int,
    _src:         []byte,           // owned copy of the source string
    _allocator:   runtime.Allocator,
    _pending:     [][]Cell,         // data rows peeked during type detection, queued for replay
    _pending_pos: int,
    _row_index:   int,
    _last_err:    Parse_Error,
}

// iterator_init prepares the iterator. It eagerly reads the header row and the
// optional type-hint row, then leaves the reader positioned at the first data
// row. The iterator clones data internally so the caller's string may be freed
// immediately after this call.
iterator_init :: proc(it: ^Table_Iterator, data: string, allocator := context.allocator) -> (err: Parse_Error) {
    context.allocator = allocator
    it._allocator = allocator

    src := make([]byte, len(data))
    copy(src, transmute([]byte)data)
    it._src = src

    csv.reader_init_with_string(&it.reader, string(it._src))
    it.reader.trim_leading_space = true

    // Count the number of newline characters and estimate the number of rows.
    matcher := match.matcher_init(string(it._src), "\n")
    n_rows := 0
    for {
        _, _, ok := match.matcher_match_iter(&matcher)
        if ok == false {
            break
        }
        n_rows = n_rows + 1
    }
    it.n_rows = n_rows

    // Read header row
    header_strs, csv_err := csv.read(&it.reader, allocator)
    if csv_err != nil {
        if csv.is_io_error(csv_err, .EOF) {
            err = Empty_CSV_Error{}
        } else {
            err = csv_err
        }
        return
    }
    if len(header_strs) == 0 {
        err = Empty_CSV_Error{}
        return
    }
    it.headers = header_strs

    n_cols := len(it.headers)

    // Read the second row to check for type hints
    second_strs, second_err := csv.read(&it.reader, context.temp_allocator)
    if csv.is_io_error(second_err, .EOF) || len(second_strs) == 0 {
        // Only headers, no data
        it.column_types = _all_string_types(n_cols, allocator)
        return
    }
    if second_err != nil {
        err = second_err
        return
    }

    if _is_type_hint_row(second_strs) {
        it.column_types = _parse_type_hint_row(second_strs, n_cols, allocator)
        return
    }

    // Not a type-hint row — peek up to one more row so column types are
    // decided from a small sample instead of per-cell. Both sampled rows are
    // queued as pending so they still get emitted, in order, by iterator_next.
    third_strs, third_err := csv.read(&it.reader, context.temp_allocator)
    has_third := third_err == nil && len(third_strs) > 0
    if third_err != nil && !csv.is_io_error(third_err, .EOF) {
        err = third_err
        return
    }

    sample_rows := [][]string{second_strs}
    if has_third {
        sample_rows = [][]string{second_strs, third_strs}
    }
    it.column_types = _detect_column_types(sample_rows, n_cols, allocator)

    pending := make([][]Cell, len(sample_rows), allocator)
    for sample_row, i in sample_rows {
        row := make([]Cell, n_cols, allocator)
        for field, j in sample_row {
            if j >= n_cols {
                continue
            }
            cell, ok := _convert_cell(field, it.column_types[j], allocator)
            if !ok {
                mismatch := Type_Mismatch_Error{it._row_index + i, j, it.column_types[j]}
                err = mismatch
                row_destroy(row, allocator)
                for k := 0; k < i; k += 1 {
                    row_destroy(pending[k], allocator)
                }
                delete(pending, allocator)
                return
            }
            row[j] = cell
        }
        pending[i] = row
    }
    it._pending = pending

    return
}

// iterator_next returns the next typed row. Use it in a loop:
//
//   for {
//       row, err, more := csv_parser.iterator_next(&it)
//       if !more { break }
//       defer csv_parser.row_destroy(row)
//       ...
//   }
//
// Returns more=false at EOF or on error. Check iterator_last_error after the
// loop to distinguish EOF from a real error.
iterator_next :: proc(it: ^Table_Iterator) -> (row: []Cell, err: Parse_Error, more: bool) {
    if it._pending_pos < len(it._pending) {
        row = it._pending[it._pending_pos]
        it._pending_pos += 1
        it._row_index += 1
        more = true
        if it._pending_pos == len(it._pending) {
            delete(it._pending, it._allocator)
            it._pending = nil
            it._pending_pos = 0
        }
        return
    }

    raw_row, csv_err := csv.read(&it.reader, context.temp_allocator)
    if csv.is_io_error(csv_err, .EOF) || len(raw_row) == 0 {
        return
    }
    if csv_err != nil {
        it._last_err = csv_err
        err = csv_err
        return
    }

    n_cols := len(it.headers)
    new_row := make([]Cell, n_cols, it._allocator)
    for field, j in raw_row {
        if j >= n_cols {
            continue
        }
        cell, ok := _convert_cell(field, it.column_types[j], it._allocator)
        if !ok {
            mismatch := Type_Mismatch_Error{it._row_index, j, it.column_types[j]}
            it._last_err = mismatch
            err = mismatch
            row_destroy(new_row, it._allocator)
            return
        }
        new_row[j] = cell
    }

    row = new_row
    it._row_index += 1
    more = true
    return
}

// iterator_last_error returns any non-EOF error that stopped the iterator.
iterator_last_error :: proc(it: Table_Iterator) -> Parse_Error {
    return it._last_err
}

// iterator_destroy frees all memory owned by the iterator. It does NOT free
// rows returned by iterator_next — use row_destroy for those.
iterator_destroy :: proc(it: ^Table_Iterator) {
    context.allocator = it._allocator

    for h in it.headers {
        delete(h)
    }
    delete(it.headers)
    delete(it.column_types)

    for i := it._pending_pos; i < len(it._pending); i += 1 {
        row_destroy(it._pending[i], it._allocator)
    }
    delete(it._pending, it._allocator)
    it._pending = nil
    it._pending_pos = 0

    delete(it._src)
    csv.reader_destroy(&it.reader)

    it^ = {}
}

// row_destroy frees a row returned by iterator_next.
row_destroy :: proc(row: []Cell, allocator := context.allocator) {
    for cell in row {
        if s, ok := cell.(string); ok {
            delete(s, allocator)
        }
    }
    delete(row, allocator)
}

@(private)
_all_string_types :: proc(n: int, allocator := context.allocator) -> []Column_Type {
    types := make([]Column_Type, n, allocator)
    for &t in types {
        t = .String
    }
    return types
}
