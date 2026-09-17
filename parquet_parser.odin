package soda

import cq "carquet_bindings"
import "core:strings"
import "core:fmt"

// Only use in single threaded mode.
@(private="file")
ERROR_OBJ :Maybe(cq.carquet_error)= nil

Reader :: struct {
    _reader: ^cq.carquet_reader,
}

Error :: Maybe(cq.carquet_error)

@(init)
init_carquet_reader :: proc "contextless" () {
    if ERROR_OBJ == nil {
        err := cq.carquet_error{}
        cq.carquet_error_init(&err)
        ERROR_OBJ = err
    }
}

reader_open :: proc(filename: string, options: ^cq.carquet_reader_options_t) -> (Reader, Error) {
    // We assume that the object has been initialized.
    err, _ := ERROR_OBJ.?

    cfilename := strings.clone_to_cstring(filename, context.temp_allocator)
    reader := cq.carquet_reader_open(cfilename, options, &err)
    if reader == nil { 
        fmt.eprintln("read error: %v\n", err.message)
        returned_err := cq.carquet_error{}
	      cq.carquet_error_copy(&returned_err, &err)
        return  Reader{reader}, returned_err
    }
    return Reader{reader}, nil
}

@private
read_metadata :: proc(reader: ^cq.carquet_reader_t) -> map[string]string {

    n_entries := cq.carquet_reader_num_metadata(reader)
    metadata := make(map[string]string)

    key :cstring= nil
    value :cstring= nil
    for index in 0..<n_entries {
        status := cq.carquet_reader_get_metadata(reader, index, &key, &value)
        
        #partial switch status {
        case .OK:
            metadata[strings.clone_from_cstring(key)] = strings.clone_from_cstring(value)
        case .ERROR_INVALID_METADATA:
            fmt.eprintln("Error invalid metadata.")
        case:
            fmt.eprintln("Unexpected error.")
        }

    }
    return metadata
}

// NOTE: we are assuming there is no nulls in the data
read_parquet :: proc(filename: string, allocator:= context.allocator) -> (dataframe: DataFrame, metadata: map[string]string, error: Error){
    reader := reader_open(filename, nil) or_return
    defer cq.carquet_reader_close(reader._reader)

    err, _ := ERROR_OBJ.?

    n_columns := cq.carquet_reader_num_columns(reader._reader)
    n_rows := cq.carquet_reader_num_rows(reader._reader)
    schema := cq.carquet_reader_schema(reader._reader)

    metadata = read_metadata(reader._reader)

    data := make(map[string]Column)
    for column_index in 0..<n_columns {
        col := cq.carquet_reader_get_column(reader._reader, 0, column_index, &err)
        defer cq.carquet_column_reader_free(col)

        if col == nil {
            fmt.eprintln(err)
            break
        }

        c_column_name := cq.carquet_schema_column_name(schema, column_index)
        column_name := strings.clone_from_cstring(c_column_name, allocator)

        cq_physical_type := cq.carquet_schema_column_type(schema, column_index)
        #partial switch cq_physical_type {
        case .DOUBLE: {
            buf := make([dynamic]f64, n_rows, n_rows, allocator)

            if read_batch(col, buf) {
                fmt.eprintln("Parquet reader failed to read column ", column_name)
                return dataframe, metadata, error
            }

            data[column_name] = buf
        }
        case .INT64: {
            buf := make([dynamic]int, n_rows, n_rows, allocator)

            if read_batch(col, buf) {
                fmt.eprintln("Parquet reader failed to read column ", column_name)
                return dataframe, metadata, error
            }

            data[column_name] = buf
        }
        case .BYTE_ARRAY: {
            buf := make([dynamic]string, n_rows, n_rows, allocator)

            if read_batch(col, buf) {
                fmt.eprintln("Parquet reader failed to read column ", column_name)
                return dataframe, metadata, error
            }

            for i in 0..< n_rows {
                buf[i]  = strings.clone(buf[i], allocator)
            }
        }
        case: {
            fmt.eprintln("Currently doesn't handle physical type: ", cq_physical_type)
            continue
        }
        }
    }

    return DataFrame{ int(n_rows), data }, metadata, nil
}

@private
read_batch :: proc(col: ^cq.carquet_column_reader_t, buf: [dynamic]$E) -> (is_error: bool) {
    offset :i64= 0
    is_more_data := true
    n_rows := i64(len(buf))
    for is_more_data {
        n := cq.carquet_column_read_batch(col, raw_data(buf[offset:]), n_rows - offset, nil, nil)
        // TODO: Look into using the following function to retrieve the error
        // cq.carquet_column_read_batch_ex
        offset += n

        switch {
        case n == 0: is_more_data = false
        case n < 0: {
            // TODO return a useful error.
            return true
        }
        }
    }
    return false
}
