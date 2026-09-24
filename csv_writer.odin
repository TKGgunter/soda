package soda

import "core:os"
import "core:strings"
import "core:testing"

// Creates a CSV of the data with "," as the separator.
write_csv :: proc(df: DataFrame, filename: string, include_type_header:= true) -> (err: os.Error) {
    file := os.open(filename, {.Write, .Create, .Trunc}) or_return
    defer os.close(file)

    // As of Sept 19, 2026 dataframes are backed by unordered dictionaries. To
    // ensure CSVs are constructed with a consistent column order column names
    // are pulled to an array.
    column_names, _ := get_column_names(df)
    defer delete(column_names)

    // Write header
    {
        column_names_builder := strings.builder_make()
        column_types_builder := strings.builder_make()

        defer {
            strings.builder_destroy(&column_names_builder)
            strings.builder_destroy(&column_types_builder)
        }

        for key, cn_index in column_names {
            value, _ := get_columnslice(df, key)

            strings.write_string(&column_names_builder, key)

            switch v in value {
            case []int:  strings.write_string(&column_types_builder, "int")
            case []f64:  strings.write_string(&column_types_builder, "f64")
            case []string: strings.write_string(&column_types_builder, "string")
            case []bool: strings.write_string(&column_types_builder, "bool")
            }

            if cn_index < len(column_names) - 1 {
                strings.write_string(&column_names_builder, ",")
                strings.write_string(&column_types_builder, ",")
            } else {
                strings.write_string(&column_names_builder, "\n")
                strings.write_string(&column_types_builder, "\n")
            }
        }
        column_names_header := strings.to_string(column_names_builder)
        os.write_string(file, column_names_header) or_return

        if include_type_header {
            column_types := strings.to_string(column_types_builder)
            os.write_string(file, column_types) or_return
        }
    }

    // Write data
    {
        data_string_builder := strings.builder_make()
        defer strings.builder_destroy(&data_string_builder)
            
        for i in 0..<df.n_rows {
            for key, key_index in column_names {
                data, _ := get_data(df, key, i)
                switch value in data {
                case int: strings.write_int(&data_string_builder, value)
                case f64: strings.write_f64(&data_string_builder, value, 'g')
                case bool: {
                    if value {
                        strings.write_string(&data_string_builder, "TRUE")
                    } else {
                        strings.write_string(&data_string_builder, "FALSE")
                    }
                }
                case string: strings.write_string(&data_string_builder, value)
                }

                if key_index < len(column_names) - 1 {
                    strings.write_string(&data_string_builder, ",")
                } else {
                    // We don't want to write a newline at the end of the file
                    if i < df.n_rows - 1 {
                        strings.write_string(&data_string_builder, "\n")
                    }
                }
            }

            row_string := strings.to_string(data_string_builder)
            os.write_string(file, row_string) or_return
            strings.builder_reset(&data_string_builder)
        }
    }
    return
}

@(private)
_expect_column_equal :: proc(t: ^testing.T, name: string, want: [dynamic]$T, got_col: Column, loc := #caller_location) {
    got, ok := got_col.([dynamic]T)
    if !testing.expectf(t, ok, "column %q: loaded with a different type than it was written", name, loc=loc) {
        return
    }
    if !testing.expectf(t, len(got) == len(want), "column %q: expected %v rows, loaded %v", name, len(want), len(got), loc=loc) {
        return
    }
    for i in 0..<len(want) {
        testing.expectf(t, got[i] == want[i], "column %q row %v: expected %q, loaded %q", name, i, want[i], got[i], loc=loc)
    }
}

@(private)
_expect_dataframes_equal :: proc(t: ^testing.T, want, got: DataFrame, loc := #caller_location) {
    testing.expect_value(t, got.n_rows, want.n_rows, loc=loc)
    testing.expect_value(t, len(got.data), len(want.data), loc=loc)

    for name, want_col in want.data {
        got_col, ok := got.data[name]
        if !testing.expectf(t, ok, "column %q is missing from the loaded dataframe", name, loc=loc) {
            continue
        }
        switch w in want_col {
        case [dynamic]int:    _expect_column_equal(t, name, w, got_col, loc)
        case [dynamic]f64:    _expect_column_equal(t, name, w, got_col, loc)
        case [dynamic]string: _expect_column_equal(t, name, w, got_col, loc)
        case [dynamic]bool:   _expect_column_equal(t, name, w, got_col, loc)
        }
    }
}

// Writes `want` to a CSV file in a temporary directory, loads it back with
// read_csv, and checks the loaded dataframe holds the same contents.
@(private="file")
_expect_csv_round_trip :: proc(t: ^testing.T, want: DataFrame, loc := #caller_location) {
    tmp_dir, dir_err := os.make_directory_temp("", "soda_csv_test_*", context.allocator)
    if !testing.expectf(t, dir_err == nil, "could not create temp dir: %v", dir_err, loc=loc) {
        return
    }
    defer {
        _ = os.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    path, path_err := os.join_path({tmp_dir, "round_trip.csv"}, context.allocator)
    if !testing.expectf(t, path_err == nil, "could not build path: %v", path_err, loc=loc) {
        return
    }
    defer delete(path)

    write_err := write_csv(want, path)
    if !testing.expectf(t, write_err == nil, "write_csv failed: %v", write_err, loc=loc) {
        return
    }

    file, open_err := os.open(path)
    if !testing.expectf(t, open_err == nil, "could not reopen %q: %v", path, open_err, loc=loc) {
        return
    }
    defer os.close(file)

    got, parse_err := read_csv(file)
    if !testing.expectf(t, parse_err == nil, "read_csv failed: %v", parse_err, loc=loc) {
        return
    }
    defer delete_dataframe(got)

    _expect_dataframes_equal(t, want, got, loc)
}

// More rows than columns on purpose: a writer that confuses the two (see
// len_dataframe, which counts columns) only shows up when they differ.
@(test)
t_write_csv_round_trip :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        // {"id", "score", "active"},
        {"id", "score", "name", "active"},
        []int{1, 2, 3, 4, 5, 6},
        []f64{0.5, 1.25, -3.75, 100, 0, 7.125},
        []string{"alice", "bob", "carol", "dave", "erin", "frank"},
        []bool{true, false, false, true, true, false},
    )
    defer delete_dataframe(df)

    _expect_csv_round_trip(t, df)
}
