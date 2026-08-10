package soda

import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:slice"

// TODO:
// [x] Update function signature to conform with how odin passes objects. 
//      In odin, large objects -- object larger than pointer size -- are passed
//      by reference. When a function performs a non-mutating operation the
//      function signature should not be a pointer but a value.
//
// [x] Move calculation to a math.odin file.
//
// [-] Complete petal analysis and create a set of tests as an example.
//
// [-] Review function which allocate memory and return the allocations to the
//      caller. In these cases the function should take an allocator.
//
// [-] add booleans
// 
// [ ] restructure source code and create an example dir.
//
// [ ] complete plotting?
//
// [ ] set nulls
//
// [ ] add asserts to insure dataframe columns have consistant lengths and that
// the lengths are accurate to the n_row
//
// [ ] look at https://arrow.apache.org/docs/format/Intro.html#support-for-null-values
//
// [ ] clean up semantics. When to return a literal versus a pointer. How to
//      name things. Today the conventions are abit all over the place.

Row :: distinct map[string]DataPtr

RowLiteral :: distinct map[string]Data

DataPtr :: union {
    ^int,
    ^f64,
    ^string,
    ^bool,
}

Data :: union {
    int,
    f64,
    string,
    bool,
}

Column :: union {
    [dynamic]int,
    [dynamic]f64,
    [dynamic]string,
    [dynamic]bool,
    // TODO Time/DateTime
}

ColumnSlice :: union {
    []int,
    []f64,
    []string,
    []bool,
}

DataFrame :: struct {
    n_rows: int,
    data: map[string]Column,
    // _allocator: should we create this or use the allocator stored in data param?
}

DataFrameSlice :: struct {
    n_rows: int,
    data: map[string]ColumnSlice,
}

len_dataframe :: proc(df: $T) -> int 
where T == DataFrame || T == DataFrameSlice || T == ^DataFrame || T == ^DataFrameSlice
{
    return len(df.data)
}

make_dataframe_from_literal :: proc(column_names: []string, columns: ..ColumnSlice, allocator:= context.allocator) -> DataFrame {
    
    n_columns := len(column_names)
    if n_columns != len(columns) {
        runtime.panic("number of columns are not the same.")
    }
    n_rows := 0
    for &c, i in columns {

        if i == 0 {
            n_rows = len_column(c)
            
        } else {
            if n_rows != len_column(c) {
                runtime.panic("column lengths are not the same")
            }
        }
    }

    m := make(map[string]Column, allocator)
    for _name, i in column_names {
        name := strings.clone(_name, allocator)

        switch v in columns[i] {
        case []int: {
            buf := make([dynamic]int, n_rows, n_rows, allocator)
            copy(buf[:], v[:])
            m[name] = Column(buf)
        }
        case []f64: {
            buf := make([dynamic]f64, n_rows, n_rows, allocator)
            copy(buf[:], v[:])
            m[name] = Column(buf)
        }
        case []string: {
            buf := make([dynamic]string, 0, n_rows, allocator)
            for j in 0..<n_rows {
                append(&buf, strings.clone(v[j], allocator))
            }
            m[name] = Column(buf)
        }
        case []bool: {
            buf := make([dynamic]bool, n_rows, n_rows, allocator)
            copy(buf[:], v[:])
            m[name] = Column(buf)
        }
        }
    }

    return DataFrame { n_rows=n_rows, data=m}
}


get :: proc(column: ColumnSlice, index: int) -> (rt: Data, ok: bool) {
    if index >= len_column(column) || index < 0 {
        fmt.eprintln("Attempting to retrieve a column element from an index outside of column range: ", index)
        return
    }

    switch c in column {
    case []int: rt = c[index]
    case []f64: rt = c[index]
    case []string: rt = c[index]
    case []bool: rt = c[index]
    }
    ok = true
    return
}

get_ptr :: proc(column: ^$T, index: int) -> (rt: DataPtr, ok: bool)
where T == Column || T == ColumnSlice  #optional_ok {
    if index >= len_column(column^) || index < 0 {
        fmt.eprintln("Attempting to retrieve a column element from an index outside of column range: ", index)
        return
    }

    switch c in column {
    case [dynamic]int    when T == Column else []int     : rt  = &c[index]
    case [dynamic]f64    when T == Column else []f64     : rt  = &c[index]
    case [dynamic]string when T == Column else []string  : rt  = &c[index]
    case [dynamic]bool   when T == Column else []bool    : rt  = &c[index]
    }
    ok = true
    return
}

get_columnames :: proc(dataframe: $T) -> (rt: []ColumnName, err: runtime.Allocator_Error)
where T == DataFrame || T == DataFrameSlice {
    rt, err = slice.map_keys(dataframe.data)
    return rt, err
}

get_columnslice :: proc {get_columnslice_from_dataframe, get_columnslice_from_dataframeslice}

get_columnslice_from_dataframeslice :: proc(df: DataFrameSlice, column_name: string) -> (ColumnSlice, bool) {
    return df.data[column_name]
}

get_columnslice_from_dataframe :: proc(df: DataFrame, column_name: string) -> (cl: ColumnSlice, success: bool) {
    cl = ColumnSlice{}
    success= false
    switch v in df.data[column_name] or_return {
    case [dynamic]int: cl = ColumnSlice(v[:])
    case [dynamic]f64: cl = ColumnSlice(v[:])
    case [dynamic]string: cl = ColumnSlice(v[:])
    case [dynamic]bool: cl = ColumnSlice(v[:])
    }
    return cl, true
}

get_slice :: proc {get_slice_dataframe_to_dataframeslice, get_slice_columnslice_to_columnslice, get_slice_column_to_columnslice}

get_slice_column_to_columnslice :: proc(column: Column, index_min, index_max: int) -> (rt: ColumnSlice, ok: bool) {
    l := len_column(column)
    if index_max > l || index_min < 0{
        return 
    }
    switch c in column {
    case [dynamic]int: {
        return c[index_min: index_max], true
    }
    case [dynamic]f64: {
        return c[index_min: index_max], true
    }
    case [dynamic]string: {
        return c[index_min: index_max], true
    }
    case [dynamic]bool: {
        return c[index_min: index_max], true
    }
    }
    return
}

get_slice_columnslice_to_columnslice :: proc(column: ColumnSlice, index_min, index_max: int) -> (rt: ColumnSlice, ok: bool) {
    l := len_column(column)
    if index_max > l || index_min < 0{
        return 
    }
    switch c in column {
    case []int: {
        return c[index_min: index_max], true
    }
    case []f64: {
        return c[index_min: index_max], true
    }
    case []string: {
        return c[index_min: index_max], true
    }
    case []bool: {
        return c[index_min: index_max], true
    }
    }
    return
}


// Creates a dataframe slice. If no column names are provided the slice will
// contain all columns in the original dataframe.
//
// FUTURE: Currently testing the use of Maybe for row index inputs. Its unclear how
// useful they are.
get_slice_dataframe_to_dataframeslice :: proc(
    df: DataFrame, 
    _min_row: Maybe(int), 
    _max_row: Maybe(int), 
    column_names: ..string, 
    allocator:= context.temp_allocator
) -> (dfs: DataFrameSlice, success: bool) {

    max_row := df.n_rows - 1
    min_row := 0
    if _min, _ok := _min_row.?; _ok {
        min_row = _min
    }
    if _max, _ok := _max_row.?; _ok {
        max_row = _max
    }
    n_rows := max_row - min_row
    if n_rows <= 0 || min_row < 0 || max_row >= df.n_rows {
        // TODO: write a better help statement
        fmt.eprintln("bad row inputs ", min_row, max_row)
        return 
    }
    
    // FUTURE: Can we do this without allocating?
    cn := make([dynamic]string, 0, len(df.data), context.temp_allocator)
    defer delete(cn)

    if len(column_names) == 0 {
        for k in df.data {
            append(&cn, k)
        }
    } else {
        // This is the piece we shouldn't have to allocate again
        for c in column_names {
            append(&cn, c)
        }
    }

    data := make(map[string]ColumnSlice, allocator)
    for column_name in cn {
        _v, e :=  df.data[column_name]
        if e == false {
            delete(data)
            return dfs, success
        }

        switch v in _v {
        case [dynamic]int : data[column_name] = v[min_row:max_row]
        case [dynamic]f64 : data[column_name] = v[min_row:max_row]
        case [dynamic]string : data[column_name] = v[min_row:max_row]
        case [dynamic]bool : data[column_name] = v[min_row:max_row]
        }
    }

    dfs.n_rows = n_rows
    dfs.data = data

    return dfs, success
}

get_row :: proc(df: $T, index: int, allocator:= context.temp_allocator) -> (Row, bool) 
where T == DataFrame || T == DataFrameSlice {
    if index >= df.n_rows {
        // log level error
        fmt.eprintln("Index out of range.")
        return nil, false
    }

    row := make(Row, allocator) 
    for key, value in df.data {
        switch &v in value {
        case [dynamic]int    when T == DataFrame else []int:    row[key] = &v[index]
        case [dynamic]f64    when T == DataFrame else []f64:    row[key] = &v[index]
        case [dynamic]string when T == DataFrame else []string: row[key] = &v[index]
        case [dynamic]bool   when T == DataFrame else []bool:   row[key] = &v[index]
        }
    }
    return row, true
}


append_row :: proc(df: ^DataFrame, row: RowLiteral) -> (success: bool) {
    success = false
    // Test the row names and type before appending to insure we don't dirty
    // our dataframe.
    if len(df.data) != len(row) {
        // TODO, make nice and helpful
        fmt.eprintln("dataframe and row have un-equal number of columns.")
        return success
    }

    // Initial section type checks the row against the column. This is done
    // before appending the dataframe so that we do not dirty the state.
    for k, v in df.data {
        _r, r_ok := row[k] 
        if r_ok == false {
            fmt.eprintln("Row does not contain column: ", k)
            return success
        }
        switch r in _r {
        case int: {
            if _, ok := v.([dynamic]int); ok == false {
                return success
            }
        }
        case f64: {
            if _, ok := v.([dynamic]f64); ok == false {
                return success
            }
        }
        case string: {
            if _, ok := v.([dynamic]string); ok == false {
                return success
            }
        }
        case bool: {
            if _, ok := v.([dynamic]bool); ok == false {
                return success
            }
        }
        }
    }

    for k, v in row {
        _c := df.data[k]
        switch &c in _c {
        case [dynamic]int: append(&c, v.(int))
        case [dynamic]f64: append(&c, v.(f64))
        case [dynamic]string: append(&c, strings.clone(v.(string), df.data.allocator))
        case [dynamic]bool: append(&c, v.(bool))
        }
    }
    df.n_rows += 1

    success = true
    return success
}


append_column :: proc(df: ^DataFrame, column_name: string, column: Column) -> bool {
    // TODO:
    // Why couldn't I use the parameter variable?
    c := column
    if df.n_rows != len_column(c) {
        return false
    }

    if _, ok := df.data[column_name]; ok {
        return false
    } else {
        cn := strings.clone(column_name, df.data.allocator)
        df.data[cn] = c
    }
    return true
}

// NOTE: this function eats df2, the caller should no longer use it
// TODO: what is odin's convention here
// assumes that the allocators of the two dataframes are the same.
append_columnwise :: proc(df1: ^DataFrame, df2: ^DataFrame) -> bool {
    if df1.n_rows != df2.n_rows {
        return false
    }

    if df1.data.allocator != df2.data.allocator {
        // TODO we can write a fix for this.
        fmt.eprintln("Dataframe 1 and 2 use different allocators, append task aborted.")
        return false
    }

    for key, value in df2.data {
        if _, ok := df1.data[key]; ok {
            fmt.eprintln("Skipping column %v source dataframe already contains an entry", key)
            continue
        } else {
            df1.data[key] = value
            delete_column_from_dataframe(df2, key)
        }
    }

    return true
}

// TODO
append_rowwise :: proc() -> bool {
    return false
}

// TODO should not print but return the slice, maybe
// TODO implement for columnslice and dataframeslice
head :: proc{head_column, head_dataframe}

head_dataframe :: proc(df: DataFrame) {
    if df_slice, ok := get_slice(df, 0, 5); ok {
        fmt.println(df_slice)
    } else {
        fmt.println(df)
    }
}

head_column :: proc(column: Column) {
    column_len := len_column(column)
    switch c in column {
    case [dynamic]int: {
        fmt.println(ColumnSlice(c[0:min(column_len, 5)]))
    }
    case [dynamic]f64: {
        fmt.println(ColumnSlice(c[0:min(column_len, 5)]))
    }
    case [dynamic]string: {
        fmt.println(ColumnSlice(c[0:min(column_len, 5)]))
    }
    case [dynamic]bool: {
        fmt.println(ColumnSlice(c[0:min(column_len, 5)]))
    }
    }
}

// TODO should not print but return the slice, maybe
tail :: proc{tail_dataframe}

// Prints the last, nominally 5 rows, of a DataFrame.
tail_dataframe :: proc(df: DataFrame) {
    max_index := df.n_rows - 1
    if df_slice, ok := get_slice(df, max_index - 5, max_index); ok {
        fmt.println(df_slice)
    } else {
        fmt.println(df)
    }
}

unique :: proc { unique_column, unique_columnslice }

unique_column :: proc(column: Column, allocator:= context.allocator) -> ColumnSlice {
    // TODO do we need to resize the buffer, since we will not be using all of it?
    // TODO we need a column to columnslice function we can use to compress some of this redundant code.
    rt := ColumnSlice({})
    switch c in column {
    case [dynamic]int : {
        unique_column := make([]int, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case [dynamic]f64 : {
        unique_column := make([]f64, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case [dynamic]string : {
        unique_column := make([]string, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case [dynamic]bool : {
        unique_column := make([]bool, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    }
    return rt
}

unique_columnslice :: proc(column: ColumnSlice, allocator:= context.allocator) -> ColumnSlice {
    // TODO do we need to resize the buffer, since we will not be using all of it?
    rt := ColumnSlice({})
    switch c in column {
    case []int : {
        unique_column := make([]int, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case []f64 : {
        unique_column := make([]f64, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case []string : {
        unique_column := make([]string, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    case []bool : {
        unique_column := make([]bool, len(c), allocator)
        copy(unique_column, c[:])
        rt = slice.unique(unique_column)
    }
    }
    return rt
}

len_column :: proc(c: $T) -> int 
where T == Column || T == ColumnSlice {
    n_rows := 0
    switch v in c {
    case [dynamic]int    when T == Column else []int:    n_rows = len(v)
    case [dynamic]f64    when T == Column else []f64:    n_rows = len(v)
    case [dynamic]string when T == Column else []string: n_rows = len(v)
    case [dynamic]bool   when T == Column else []bool:   n_rows = len(v)
    }
    return n_rows
}

delete_dataframe :: proc(df: DataFrame, loc := #caller_location) -> runtime.Allocator_Error {
    // FUTURE: there must be some better way to bundle the data together such
    // that we can free things in a single call.
    //
    // Maybe the idea is that the user passes in there own allocator and from
    // their free.
    for k, c in df.data {
        delete(k, loc=loc)
        switch v in c {
        case [dynamic]int: delete(v, loc)
        case [dynamic]f64: delete(v, loc)
        case [dynamic]string: {
            for it in v {
                delete(it, loc=loc)
            }
        }
        case [dynamic]bool: delete(v, loc)
        }
    }
    return delete(df.data, loc)
}

delete_dataframeslice :: proc(df: ^DataFrameSlice, loc := #caller_location) -> runtime.Allocator_Error {
    // FUTURE: there must be some better way to bundle the data together such
    // that we can free things in a single call.
    //
    // Maybe the idea is that the user passes in there own allocator and from
    // their free.

    // for k, c in df.data {
    //     delete(k)
    // }
    return delete(df.data)
}

delete_column :: proc(column: Column, loc := #caller_location) -> runtime.Allocator_Error {
    switch c in column {
    case [dynamic]int    : delete(c, loc) or_return
    case [dynamic]f64    : delete(c, loc) or_return
    // we also need to delete the strings within the array
    case [dynamic]string : delete(c, loc) or_return
    case [dynamic]bool   : delete(c, loc) or_return
    }
    return nil
}

delete_column_from_dataframe :: proc(df: ^DataFrame, column_name: string) -> (deleted_name: string, deleted_value: Column) {
    deleted_name, deleted_value = delete_key(&df.data, column_name)
    return deleted_name, deleted_value
}

@(init)
init_formatter :: proc "contextless" () {
    context = runtime.default_context()
    fmt.set_user_formatters(new(map[typeid]fmt.User_Formatter))
    fmt.register_user_formatter(DataFrame, dataframe_formatter)
    fmt.register_user_formatter(DataFrameSlice, dataframeslice_formatter)
    fmt.register_user_formatter(Column, column_formatter)
    fmt.register_user_formatter(ColumnSlice, columnslice_formatter)
}

