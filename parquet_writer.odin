package soda

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

import cq "carquet_bindings"

Compression :: enum {
	Fast,
	ZStd,
	Uncompressed,
}

// Builds an Error from a bare carquet status, for failures that carquet
// reports through a return code rather than through a carquet_error.
@(private="file")
_status_error :: proc(status: cq.carquet_status_t) -> Error {
    err := cq.carquet_error{}
    cq.carquet_error_init(&err)
    err.code = status

    message := string(cq.carquet_status_string(status))
    for i in 0..<min(len(message), len(err.message) - 1) {
        err.message[i] = i8(message[i])
    }
    return err
}

write_parquet :: proc(
    df: DataFrame,
    filename: string,
    compression:= Compression.Fast,
    metadata: map[string]string = nil,
) -> (error: Error) {
    if len_dataframe(df) == 0 {
        fmt.eprintln("Dataframe contains no rows.")
        return _status_error(.ERROR_INVALID_ARGUMENT)
    }

    // Column names are pulled to an array to give the file a fixed column
    // order. The schema and the column data are both written in this order.
    column_names, _ := get_column_names(df)
    defer delete(column_names)

    err := cq.carquet_error{}
    cq.carquet_error_init(&err)

    schema := cq.carquet_schema_create(&err)
    if schema == nil {
        return err
    }
    defer cq.carquet_schema_free(schema)

    string_type := cq.carquet_logical_type{id = .STRING}

    // Build the schema
    for key in column_names {
        value, _ := get_columnslice(df, key)
        cname := strings.clone_to_cstring(key, context.temp_allocator)

        status: cq.carquet_status_t
        switch v in value {
        case []int:    status = cq.carquet_schema_add_column(schema, cname, .INT64, nil, .REQUIRED, 0, 0)
        case []f64:    status = cq.carquet_schema_add_column(schema, cname, .DOUBLE, nil, .REQUIRED, 0, 0)
        case []bool:   status = cq.carquet_schema_add_column(schema, cname, .BOOLEAN, nil, .REQUIRED, 0, 0)
        case []string: status = cq.carquet_schema_add_column(schema, cname, .BYTE_ARRAY, &string_type, .REQUIRED, 0, 0)
        }
        if status != .OK {
            return _status_error(status)
        }
    }

    options := cq.carquet_writer_options_t{}
    cq.carquet_writer_options_init(&options)
    switch compression {
    case .Fast : options.compression = .SNAPPY
    case .ZStd : options.compression = .ZSTD
    case .Uncompressed : options.compression = .UNCOMPRESSED
    }


    cfilename := strings.clone_to_cstring(filename, context.temp_allocator)
    writer := cq.carquet_writer_create(cfilename, schema, &options, &err)
    if writer == nil {
        return err
    }

    // Once the writer exists it has to be closed or aborted. Aborting leaves
    // the file without a valid footer, which is what we want on failure.
    closed := false
    defer if !closed {
        cq.carquet_writer_abort(writer)
    }

    // Write data
    for key, column_index in column_names {
        // carquet rejects a null values pointer, which is what an empty
        // column hands it. A file with a schema and no rows is still valid.
        if df.n_rows == 0 {
            break
        }

        value, _ := get_columnslice(df, key)

        status: cq.carquet_status_t
        n_rows := i64(df.n_rows)

        // Odin's int is the same width as INT64 on the 64 bit targets that
        // read_parquet supports, and bool is a single byte, which is what
        // carquet expects for BOOLEAN, so those columns are passed as is.
        switch v in value {
        case []int:  status = cq.carquet_writer_write_batch(writer, i32(column_index), raw_data(v), n_rows, nil, nil)
        case []f64:  status = cq.carquet_writer_write_batch(writer, i32(column_index), raw_data(v), n_rows, nil, nil)
        case []bool: status = cq.carquet_writer_write_batch(writer, i32(column_index), raw_data(v), n_rows, nil, nil)
        case []string: {
            // carquet wants (pointer, i32 length) pairs, which is not the
            // layout of an Odin string.
            byte_arrays := make([]cq.carquet_byte_array_t, len(v), context.temp_allocator)
            for s, i in v {
                if len(s) > int(max(i32)) {
                    return _status_error(.ERROR_INVALID_ARGUMENT)
                }
                byte_arrays[i] = cq.carquet_byte_array_t{ data = raw_data(s), length = i32(len(s)) }
            }
            status = cq.carquet_writer_write_batch(writer, i32(column_index), raw_data(byte_arrays), n_rows, nil, nil)
        }
        }
        if status != .OK {
            return _status_error(status)
        }
    }

    for key, value in metadata {
        ckey := strings.clone_to_cstring(key, context.temp_allocator)
        cvalue := strings.clone_to_cstring(value, context.temp_allocator)
        if status := cq.carquet_writer_add_metadata(writer, ckey, cvalue); status != .OK {
            return _status_error(status)
        }
    }

    closed = true
    if status := cq.carquet_writer_close(writer); status != .OK {
        return _status_error(status)
    }
    return nil
}

// Writes `want` to a parquet file in a temporary directory, loads it back with
// read_parquet, and checks the loaded dataframe and metadata hold the same
// contents.
@(private="file")
_expect_parquet_round_trip :: proc(
    t: ^testing.T,
    want: DataFrame,
    compression:= Compression.Fast,
    want_metadata: map[string]string = nil,
    loc := #caller_location,
) {
    tmp_dir, dir_err := os.make_directory_temp("", "soda_parquet_test_*", context.allocator)
    if !testing.expectf(t, dir_err == nil, "could not create temp dir: %v", dir_err, loc=loc) {
        return
    }
    defer {
        _ = os.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    path, path_err := os.join_path({tmp_dir, "round_trip.parquet"}, context.allocator)
    if !testing.expectf(t, path_err == nil, "could not build path: %v", path_err, loc=loc) {
        return
    }
    defer delete(path)

    if write_err, failed := write_parquet(want, path, compression, want_metadata).?; !testing.expectf(t, !failed, "write_parquet failed: %v", write_err.code, loc=loc) {
        return
    }

    got, got_metadata, read_err := read_parquet(path)
    defer {
        for k, v in got_metadata {
            delete(k)
            delete(v)
        }
        delete(got_metadata)
    }
    if read_error, failed := read_err.?; !testing.expectf(t, !failed, "read_parquet failed: %v", read_error.code, loc=loc) {
        return
    }
    defer delete_dataframe(got)

    _expect_dataframes_equal(t, want, got, loc)

    for key, want_value in want_metadata {
        got_value, ok := got_metadata[key]
        if !testing.expectf(t, ok, "metadata key %q is missing from the loaded file", key, loc=loc) {
            continue
        }
        testing.expectf(t, got_value == want_value, "metadata %q: expected %q, loaded %q", key, want_value, got_value, loc=loc)
    }
}

// More rows than columns on purpose: a writer that confuses the two (see
// len_dataframe, which counts columns) only shows up when they differ.
@(test)
t_write_parquet_round_trip :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"id", "score", "name", "active"},
        []int{1, 2, 3, 4, 5, 6},
        []f64{0.5, 1.25, -3.75, 100, 0, 7.125},
        []string{"alice", "bob", "carol", "dave", "erin", "frank"},
        []bool{true, false, false, true, true, false},
    )
    defer delete_dataframe(df)

    _expect_parquet_round_trip(t, df)
}

// Each codec has its own compress and decompress path, so each is round
// tripped separately.
@(test)
t_write_parquet_compression_round_trip :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"id", "score", "name", "active"},
        []int{1, 2, 3, 4, 5, 6},
        []f64{0.5, 1.25, -3.75, 100, 0, 7.125},
        []string{"alice", "bob", "carol", "dave", "erin", "frank"},
        []bool{true, false, false, true, true, false},
    )
    defer delete_dataframe(df)

    for codec in ([]Compression{.Uncompressed, .Fast, .ZStd}) {
        _expect_parquet_round_trip(t, df, codec)
    }
}

// Values that are easy to lose on the way through: empty and non ASCII
// strings, the extremes of int and f64, negative zero, and repeated values.
@(test)
t_write_parquet_edge_values_round_trip :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"id", "score", "name"},
        []int{min(int), -1, 0, 1, max(int)},
        []f64{-1.7976931348623157e308, -0.0, 0, 5e-324, 1.7976931348623157e308},
        []string{"", "a", "héllo wörld", "日本語", "a,b\n\"c\""},
    )
    defer delete_dataframe(df)

    _expect_parquet_round_trip(t, df)
}

// Enough rows to span more than one page of data.
@(test)
t_write_parquet_many_rows_round_trip :: proc(t: ^testing.T) {
    N :: 100_000
    ids := make([]int, N)
    scores := make([]f64, N)
    names := make([]string, N)
    actives := make([]bool, N)
    defer {
        for name in names {
            delete(name)
        }
        delete(ids)
        delete(scores)
        delete(names)
        delete(actives)
    }

    for i in 0..<N {
        ids[i] = i
        scores[i] = f64(i) * 0.25
        names[i] = fmt.aprintf("row_%v", i)
        actives[i] = i % 3 == 0
    }

    df := make_dataframe_from_literal({"id", "score", "name", "active"}, ids, scores, names, actives)
    defer delete_dataframe(df)

    _expect_parquet_round_trip(t, df)
}

@(test)
t_write_parquet_metadata_round_trip :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal({"id"}, []int{1, 2, 3})
    defer delete_dataframe(df)

    metadata := make(map[string]string)
    defer delete(metadata)
    metadata["source"] = "soda test"
    metadata["empty_value"] = ""

    _expect_parquet_round_trip(t, df, want_metadata=metadata)
}

@(test)
t_write_parquet_bad_path :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal({"id"}, []int{1, 2, 3})
    defer delete_dataframe(df)

    tmp_dir, dir_err := os.make_directory_temp("", "soda_parquet_test_*", context.allocator)
    if !testing.expectf(t, dir_err == nil, "could not create temp dir: %v", dir_err) {
        return
    }
    defer {
        _ = os.remove_all(tmp_dir)
        delete(tmp_dir)
    }

    // The directory does not exist, so the file cannot be created.
    path, path_err := os.join_path({tmp_dir, "missing", "out.parquet"}, context.allocator)
    if !testing.expectf(t, path_err == nil, "could not build path: %v", path_err) {
        return
    }
    defer delete(path)

    err, failed := write_parquet(df, path).?
    testing.expect(t, failed, "write_parquet to a missing directory should fail")
    testing.expect_value(t, err.code, cq.carquet_status_t.ERROR_FILE_OPEN)
}
