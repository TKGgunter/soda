package soda

import "core:fmt"
import "core:math"
import "core:slice"
import "core:testing"


min_in :: proc{min_in_column, min_in_columnslice}

min_in_column :: proc(c: Column) -> (min: Data, ok: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return min_in_columnslice(cs)
}

min_in_columnslice :: proc(column: ColumnSlice) -> (min: Data, ok: bool) {
    switch c in column {
    case []int: min, ok = slice.min(c[:])
    case []f64: min, ok = slice.min(c[:])
    case []string: min, ok = slice.min(c[:])
    case []bool:
        fmt.eprintln("booleans are not ordered types. Request to find minimum failed.")
        return
    }
    return
}


max_in :: proc {max_in_column, max_in_columnslice}

max_in_column :: proc(c: Column) -> (max: Data, ok: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return max_in_columnslice(cs)
}

max_in_columnslice :: proc(column: ColumnSlice) -> (max: Data, ok: bool) {
    switch c in column {
    case []int: max, ok = slice.max(c[:])
    case []f64: max, ok = slice.max(c[:])
    case []string: max, ok = slice.max(c[:])
    case []bool : {
        fmt.eprintln("booleans are not ordered types. Request to find maximum failed.")
        return
    }
    }
    return
}

range :: proc {range_column, range_columnslice}

range_column :: proc(c: Column) -> (min, max: Data, ok: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return range_columnslice(cs)
}

range_columnslice :: proc(column: ColumnSlice) -> (min, max: Data, ok: bool) {
    switch c in column {
    case []int: min, max, ok = slice.min_max(c[:])
    case []f64: min, max, ok = slice.min_max(c[:])
    case []string : min, max, ok = slice.min_max(c[:])
    case []bool:
        fmt.eprintln("booleans are not ordered types. Request to find minimum failed.")
    }
    return
}

sum :: proc {sum_column, sum_columnslice}

sum_column :: proc(c: Column) -> (rt: f64, success: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return sum_columnslice(cs)
}

sum_columnslice :: proc(c: ColumnSlice) -> (f64, bool) {
    // Calculations will fail if run with an snan so I feel comfortable returning it
    // to a user.
    rt := math.SNAN_F64
    success := false

    switch d in c {
    case []int: {
        rt = 0
        for it in d {
            rt += f64(it)
        }
        success = true
    }
    case []f64: {
        rt = 0
        for it in d {
            rt += it
        }
        success = true
    }
    case []string: {}
    case []bool: {}
    }
    return rt, success
}

mean :: proc { mean_columnslice, mean_column }

mean_column :: proc(c: Column) -> (rt: Data, success: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return mean_columnslice(cs)
}

mean_columnslice :: proc(c: ColumnSlice) -> (rt: Data, success: bool) {
    rt, success = sum(c)
    if success == false {
        return rt, success
    }

    return rt.(f64) / f64(len_column(c)), success
}


std :: proc{std_column, std_columnslice}

std_column :: proc(c: Column) -> (rt: Data, success: bool) {
    l := len_column(c)
    cs := get_slice(c, 0, l) or_return
    return std_columnslice(cs)
}

std_columnslice :: proc(c: ColumnSlice) -> (rt: Data, success: bool) {
    mean_value_wrapped := mean(c) or_return
    mean_value := mean_value_wrapped.(f64)
    value := 0.0

    n := f64(len_column(c))
    switch v in c {
    case []int: {
        for it in v {
            value += math.pow(f64(it) - mean_value, 2)
        }
    }
    case []f64: {
        for it in v {
            value += math.pow(it - mean_value, 2)
        }
    }
    case []string: {
        fmt.eprintln("Improper calculation request. Attempted to calculate the standard deviation of a string.")
        return
    }
    case []bool: {
        fmt.eprintln("Improper calculation request. Attempted to calculate the standard deviation of a boolean.")
        return
    }
    }
    return math.sqrt(value/n), true
}

calc_to_column :: proc {calc_from_columns_to_column, calc_from_dataframe_to_column}

calc_from_columns_to_column :: proc(
    f: proc([]Data, []Data) -> $T,
    cols: []ColumnSlice,
    constants: []Data,
    allocator:=context.allocator
) -> (Column, bool) {

    column_length := len_column(cols[0])
    for i in 1..<len(cols) {
        if column_length != len_column(cols[i]) {
            fmt.eprintln("Input columns have unequal length.")
            return Column{}, false
        }
    }
    buf := make([dynamic]T, column_length, column_length)

    data_buf := make([]Data, len(cols), context.allocator)
    defer delete(data_buf)

    for i in 0..<column_length {
        for j in 0..<len(cols) do data_buf[j], _ = get(cols[j], i)

        buf[i] = f(data_buf, constants)
    }
    return buf, true
}

calc_from_dataframe_to_column :: proc(
    df: $T, 
    f: proc([]Data, []Data) -> $V,
    cols: []string,
    constants: []Data,
    allocator:=context.allocator
) -> (Column, bool)
where T == DataFrame || T == DataFrameSlice {
    columns := make([]ColumnSlice, len(cols), context.allocator)
    defer delete(columns)

    for it, i in cols {
        if c, ok := get_columnslice(df, it); ok {
            columns[i] = c
        } else {
            fmt.eprintln("Could not retreive column: ", it)
            return Column{}, false
        }
    }

    return calc_from_columns_to_column(f, columns, constants, allocator)
}

calc_to_scalar :: proc(df: $T, f: proc(ColumnSlice) -> (Data, bool), column_name: string) -> (rt: Data, ok: bool) where T == DataFrame || T == DataFrameSlice {
    column := get_columnslice(df, column_name) or_return
    rt, ok = f(column)
    return rt, ok
}

calc_rolling :: proc { calc_rolling_dataframe_to_column, calc_rolling_columnslice_to_column }

calc_rolling_dataframe_to_column :: proc(
    df: DataFrame,
    f: proc(ColumnSlice) -> (Data, bool),
    column_name: string,
    window_size: int,
    allocator:= context.allocator
) -> (rt: Column, ok: bool) {

    column := get_columnslice(df, column_name) or_return
    return calc_rolling_columnslice_to_column(column, f, window_size, allocator)
}

// TODO
// - should we add constants to the rolling calculation. 
// currently I believe it should be consistent with the other calc methods.
// - should we include strides
// - should we allow for the use of subslices that are less than the provided window

// Calculates a new column of data using well defined subslices of an existing
// column.
//
// A rolling calculation slices an existing column into subslices, defined by
// the `window_size` parameter. These subslices are used to calculate the
// values of a new column.
// Example:
// Given an array [1,2,3,4,5] to calculate the rolling sum with a window_size
// of 2 we expect the following.
// [Nan,3,7,9, Nan].
// Here the initial and final elements in the array are Nan as they fall
// outside of the window  size bounds.
calc_rolling_columnslice_to_column :: proc(
    column: ColumnSlice,
    f: proc(ColumnSlice) -> (Data, bool),
    window_size: int,
    allocator:= context.allocator
) -> (rt: Column, ok: bool) {

    n_rows := len_column(column)

    // TODO handle other types
    rv := make([dynamic]f64, n_rows, allocator)

    // The first elements of an array, which are smaller than the window size,
    // can not be calculated. These elements are set of SNAN.
    for i in 0..<window_size - 1 {
        rv[i] = math.SNAN_F64
    }

    for i:=0; i < n_rows - window_size + 1; i+=1 {
        ws := window_size + i - 1  // This is the inclusive index. We have to
                                   // correct this for get_slice which is an
                                   // exclusive index.
        sub_column := get_slice(column, i, ws + 1) or_return
        d := f(sub_column) or_return
        rv[ws] = d.(f64)
    }
    rt = rv
    ok = true
    return 
}

@(test)
t_calc_rolling_default :: proc(t: ^testing.T) {
    input_c := []f64{1,2,3,4,5}

    // TODO: Wrapping the provided sum function like this to pass it into our
    // rolling calculation function is not so nice. I'd like to provide
    // functionality with less friction.
    sum := proc(c: ColumnSlice) -> (Data, bool) {
        v, ok := sum_columnslice(c)
        return v, ok
    }

    output_c, ok := calc_rolling_columnslice_to_column(input_c, sum, 2)
    defer delete_column(output_c)
    expected := []f64{math.SNAN_F64, 3, 5, 7, 9}

    testing.expect_value(t, ok, true)

    for i in 0..<len(input_c) {
        // SNAN compare to false. Instead we compare bits.
        output := transmute(u64)output_c.([dynamic]f64)[i]
        expect := transmute(u64)expected[i]
        testing.expect_value(t, output, expect)
    }
}

@(test)
t_calc_to_scalar :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"a", "b"},
        []int{1,2,3},
        []f64{2,3,4},
    )
    defer delete_dataframe(df)

    {
        mean_a, ok := calc_to_scalar(df, mean, "a")

        testing.expect_value(t, ok, true)
        testing.expect_value(t, mean_a.(f64), 2)
    }

    {
        mean_b, ok := calc_to_scalar(df, mean, "b")

        testing.expect_value(t, ok, true)
        testing.expect_value(t, mean_b.(f64), 3)
    }
}

@(test)
t_calc_to_column :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"a", "b"},
        []int{1,2,3},
        []f64{2,3,4},
    )
    defer delete_dataframe(df)
    

    f :: proc(input: []Data, constants: []Data) -> f64 {
        return f64(input[0].(int)) + input[1].(f64) - constants[0].(f64)
    }
    column, ok := calc_from_dataframe_to_column(df, f, {"a", "b"}, {1.0})
    expected_column := []f64{2, 4, 6}

    // TODO Unwrapping to delete in this way is not nice.
    // we already have a delete_column function which is for dataframes
    // it's unclear what the naming should be.
    defer delete_column(column)

    testing.expect_value(t, ok, true)

    for it, i in column.([dynamic]f64) {
        testing.expect_value(t, it, expected_column[i])
    }
}
