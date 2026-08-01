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

init :: proc() {
    if ERROR_OBJ == nil {
        err := cq.carquet_error_t{}
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

// NOTE: we are assuming there is no nulls in the data
read_parquet :: proc(filename: string, allocator:= context.allocator) -> (DataFrame, Error){
    reader, reader_err := reader_open(filename, nil)
    if reader_err != nil {
        return {}, reader_err
    }
    defer cq.carquet_reader_close(reader._reader)

    err, _ := ERROR_OBJ.?

    n_columns := cq.carquet_reader_num_columns(reader._reader)
    n_rows := cq.carquet_reader_num_rows(reader._reader)
    schema := cq.carquet_reader_schema(reader._reader)


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
            n := cq.carquet_column_read_batch(col, raw_data(buf), i64(n_rows), nil, nil)
            // FUTURE: we assert here because we expect that all values will be
            // read at once and I am unclear if that is how carquet will be have. 
            assert(n == i64(n_rows))
            data[column_name] = buf
        }
        case .INT64: {
            buf := make([dynamic]int, n_rows, n_rows, allocator)
            n := cq.carquet_column_read_batch(col, raw_data(buf), i64(n_rows), nil, nil)
            // FUTURE: we assert here because we expect that all values will be
            // read at once and I am unclear if that is how carquet will be have. 
            assert(n == i64(n_rows))
            data[column_name] = buf
        }
        case .BYTE_ARRAY: {
            buf := make([dynamic]string, n_rows, n_rows, allocator)
            n := cq.carquet_column_read_batch(col, raw_data(buf), i64(n_rows), nil, nil)

            for i in 0..<n {
                buf[i]  = strings.clone(buf[i], allocator)
            }
        }
        case: {
            fmt.eprintln("Currently doesn't handle physical type: ", cq_physical_type)
            continue
        }
        }
    }


    return DataFrame{ int(n_rows), data }, nil
}
