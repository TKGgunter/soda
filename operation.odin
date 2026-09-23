package soda

import "base:runtime"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:testing"
import ops "operations"

// TODO
// - [ ] we need tests!
// - [ ] there are todos to complete

Mask :: ops.Mask
ColumnName :: string

Operation :: struct {
    left_side: Operand,
    operator: Operator,
    right_side: Operand,
}

Operand :: union {
    ColumnName,
    Data,
    int,     // Data is used to check against contents of an array. A such int,
             // f64, and strings are supplied there. However, because of the
             // overlap between how the compiler parses f64 and int this is no
             // nice why for users to input simple data and the compiler parses
             // appropriately. This is a work around. The point is not
             // correctness but ease of use for the consumer of the library.
    ^Operation,
}

Operator :: enum {
    Less,
    LessEq,
    Eq,
    Greater,
    GreaterEq,
    NotEq,
    Or,
    And,
}

@(private="file")
InternalOperand :: union {
    ColumnSlice,
    int,
    f64,
    string,
    bool,
    Mask,
}

get_operand :: proc(df: ^$T, o: Operand) -> (rt: InternalOperand, ok: bool) 
where T == DataFrame || T == DataFrameSlice
{
    switch v in o {
    case string: {
        rt, ok = get_columnslice(df^, v)
        if !ok {
            fmt.eprintln("Unable to find column.")
        }
    }
    case int: {
        rt = v
        ok = true
    }
    case Data: {
        switch d in v {
        case int: {
            rt = d
            ok = true
        }
        case f64: {
            rt = d
            ok = true
        }
        case string: {
            rt = d
            ok = true
        }
        case bool: {
            rt = d
            ok = true
        }
        }
    }
    case ^Operation: {
        rt = create_mask(df, v^)
        ok = true
    }
    }
    return rt, ok
}

query :: proc(df: ^DataFrame, query_str: string) -> DataFrameSlice {
    return DataFrameSlice{}
}


filter :: proc(df: ^$T, operation: Operation, allocator:= context.allocator) -> (rt: DataFrame, success: bool) 
where T == DataFrame || T == DataFrameSlice
{
    mask := create_mask(df, operation, context.temp_allocator)
    if mask == nil {
        return rt, success
    }
    return apply_mask(df, mask)
}

apply_mask :: proc{apply_mask_to_dataframe, apply_mask_to_dataframeslice}

apply_mask_to_dataframeslice :: proc(df: ^DataFrameSlice, mask: Mask, allocator:= context.allocator) -> (rt: DataFrameSlice, success: bool) {
    n_rows := 0 
    for it in mask {
        if it == true {
            n_rows += 1
        }
    }

    data := make(map[string]ColumnSlice, allocator)

    for key, column in df.data {
        switch v in column {
        case []int: {
            buf := make([]int, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[j] = it
                    j += 1
                }
            }
            data[key] = buf
        }
        case []f64: {
            buf := make([]f64, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[i] = it
                    j += 1
                }
            }
            data[key] = buf
        }
        case []string: {
            buf := make([]string, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[i] = it
                    j += 1
                }
            }
            data[key] = buf
        }
        case []bool: {
            buf := make([]bool, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[i] = it
                    j += 1
                }
            }
            data[key] = buf
        }
        }
    }
    rt = DataFrameSlice{n_rows, data}
    success = true
    return rt, success
}

// TODO this should return a DataFrame not a DataFrameSlice. A slice indicates that it doess not own its own memory. That is not the case here.
apply_mask_to_dataframe :: proc(df: ^DataFrame, mask: Mask, allocator:= context.allocator) -> (rt: DataFrame, success: bool) {
    n_rows := 0 
    for it in mask {
        if it == true {
            n_rows += 1
        }
    }

    data := make(map[string]Column, allocator)

    for key, column in df.data {
        switch v in column {
        case [dynamic]int: {
            buf := make([dynamic]int, n_rows, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[j] = it
                    j += 1
                }
            }
            cloned_key := strings.clone(key)
            data[cloned_key] = buf
        }
        case [dynamic]f64: {
            buf := make([dynamic]f64, n_rows, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[j] = it
                    j += 1
                }
            }
            cloned_key := strings.clone(key)
            data[cloned_key] = buf
        }
        case [dynamic]string: {
            buf := make([dynamic]string, n_rows, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[j] = it
                    j += 1
                }
            }
            cloned_key := strings.clone(key)
            data[cloned_key] = buf
        }
        case [dynamic]bool: {
            buf := make([dynamic]bool, n_rows, n_rows)
            j := 0
            for it, i in v {
                if mask[i] {
                    buf[j] = it
                    j += 1
                }
            }
            cloned_key := strings.clone(key)
            data[cloned_key] = buf
        }
        }
    }
    rt = DataFrame{n_rows, data}
    success = true
    return rt, success
}

create_mask :: proc(df: ^$T, operation: Operation, allocator:= context.allocator) -> (rt: Mask) 
where T == DataFrame || T == DataFrameSlice
{
    rt = nil

    left_operand, ok_left := get_operand(df, operation.left_side)
    if !ok_left {
        return rt
    }
    right_operand, ok_right := get_operand(df, operation.right_side)
    if !ok_right {
        return rt
    }

    switch operation.operator {
    case .Eq: {
        rt = exec(
            left_operand,
            right_operand,
            ops.eq_int__arr_int,
            ops.eq_int__arr_f64,
            ops.eq_f64__arr_f64,
            ops.eq_f64__arr_int,
            ops.eq_arr_int__int,
            ops.eq_arr_int__f64,
            ops.eq_arr_f64__f64,
            ops.eq_arr_f64__int,
            ops.eq_arr_int__arr_int,
            ops.eq_arr_int__arr_f64,
            ops.eq_arr_f64__arr_f64,
            ops.eq_arr_f64__arr_int,
            ops.eq_str__arr_str,
            ops.eq_arr_str__str,
            ops.eq_arr_str__arr_str,
            ops.eq_bool__arr_bool,
            ops.eq_arr_bool__bool,
            ops.eq_arr_bool__arr_bool,
        )
    }
    case .NotEq: {
        rt = exec(
            left_operand,
            right_operand,
            ops.eq_int__arr_int,
            ops.eq_int__arr_f64,
            ops.eq_f64__arr_f64,
            ops.eq_f64__arr_int,
            ops.eq_arr_int__int,
            ops.eq_arr_int__f64,
            ops.eq_arr_f64__f64,
            ops.eq_arr_f64__int,
            ops.eq_arr_int__arr_int,
            ops.eq_arr_int__arr_f64,
            ops.eq_arr_f64__arr_f64,
            ops.eq_arr_f64__arr_int,
            ops.eq_str__arr_str,
            ops.eq_arr_str__str,
            ops.eq_arr_str__arr_str,
            ops.eq_bool__arr_bool,
            ops.eq_arr_bool__bool,
            ops.eq_arr_bool__arr_bool,
        )
        for &it in rt {
            it = !it
        }
    }
    case .Less: {
        rt = exec(
            left_operand,
            right_operand,
            ops.lt_int__arr_int,
            ops.lt_int__arr_f64,
            ops.lt_f64__arr_f64,
            ops.lt_f64__arr_int,
            ops.lt_arr_int__int,
            ops.lt_arr_int__f64,
            ops.lt_arr_f64__f64,
            ops.lt_arr_f64__int,
            ops.lt_arr_int__arr_int,
            ops.lt_arr_int__arr_f64,
            ops.lt_arr_f64__arr_f64,
            ops.lt_arr_f64__arr_int,
            ops.lt_str__arr_str,
            ops.lt_arr_str__str,
            ops.lt_arr_str__arr_str,
            ops.lt_bool__arr_bool,
            ops.lt_arr_bool__bool,
            ops.lt_arr_bool__arr_bool,
        )
    }
    case .LessEq: {
        rt = exec(
            left_operand,
            right_operand,
            ops.lte_int__arr_int,
            ops.lte_int__arr_f64,
            ops.lte_f64__arr_f64,
            ops.lte_f64__arr_int,
            ops.lte_arr_int__int,
            ops.lte_arr_int__f64,
            ops.lte_arr_f64__f64,
            ops.lte_arr_f64__int,
            ops.lte_arr_int__arr_int,
            ops.lte_arr_int__arr_f64,
            ops.lte_arr_f64__arr_f64,
            ops.lte_arr_f64__arr_int,
            ops.lte_str__arr_str,
            ops.lte_arr_str__str,
            ops.lte_arr_str__arr_str,
            ops.lte_bool__arr_bool,
            ops.lte_arr_bool__bool,
            ops.lte_arr_bool__arr_bool,
        )
    }
    case .Greater: {
        rt = exec(
            left_operand,
            right_operand,
            ops.gt_int__arr_int,
            ops.gt_int__arr_f64,
            ops.gt_f64__arr_f64,
            ops.gt_f64__arr_int,
            ops.gt_arr_int__int,
            ops.gt_arr_int__f64,
            ops.gt_arr_f64__f64,
            ops.gt_arr_f64__int,
            ops.gt_arr_int__arr_int,
            ops.gt_arr_int__arr_f64,
            ops.gt_arr_f64__arr_f64,
            ops.gt_arr_f64__arr_int,
            ops.gt_str__arr_str,
            ops.gt_arr_str__str,
            ops.gt_arr_str__arr_str,
            ops.gt_bool__arr_bool,
            ops.gt_arr_bool__bool,
            ops.gt_arr_bool__arr_bool,
        )
    }
    case .GreaterEq: {
        rt = exec(
            left_operand,
            right_operand,
            ops.gte_int__arr_int,
            ops.gte_int__arr_f64,
            ops.gte_f64__arr_f64,
            ops.gte_f64__arr_int,
            ops.gte_arr_int__int,
            ops.gte_arr_int__f64,
            ops.gte_arr_f64__f64,
            ops.gte_arr_f64__int,
            ops.gte_arr_int__arr_int,
            ops.gte_arr_int__arr_f64,
            ops.gte_arr_f64__arr_f64,
            ops.gte_arr_f64__arr_int,
            ops.gte_str__arr_str,
            ops.gte_arr_str__str,
            ops.gte_arr_str__arr_str,
            ops.gte_bool__arr_bool,
            ops.gte_arr_bool__bool,
            ops.gte_arr_bool__arr_bool,
        )
    }
    case .And: {
        // TODO I'm concerned about life times and what allocator are being used.
        lm := left_operand.(Mask)
        rm := right_operand.(Mask)
        for i in 0..<len(lm) {
            lm[i] = lm[i] & rm[i]
        }
        rt = lm
    }
    case .Or: {
        lm := left_operand.(Mask)
        rm := right_operand.(Mask)
        for i in 0..<len(lm) {
            lm[i] = lm[i] || rm[i]
        }
        rt = lm
    }
    }
    return rt
}


exec :: proc(
    left: InternalOperand,
    right: InternalOperand,
    cmd__int__arr_int:       proc(int, []int, runtime.Allocator) -> Mask,
    cmd__int__arr_f64:       proc(int, []f64, runtime.Allocator) -> Mask,
    cmd__f64__arr_f64:       proc(f64, []f64, runtime.Allocator) -> Mask,
    cmd__f64__arr_int:       proc(f64, []int, runtime.Allocator) -> Mask,
    cmd__arr_int__int:       proc([]int, int, runtime.Allocator) -> Mask,
    cmd__arr_int__f64:       proc([]int, f64, runtime.Allocator) -> Mask,
    cmd__arr_f64__f64:       proc([]f64, f64, runtime.Allocator) -> Mask,
    cmd__arr_f64__int:       proc([]f64, int, runtime.Allocator) -> Mask,
    cmd__arr_int__arr_int:   proc([]int, []int, runtime.Allocator) -> Mask,
    cmd__arr_int__arr_f64:   proc([]int, []f64, runtime.Allocator) -> Mask,
    cmd__arr_f64__arr_f6:    proc([]f64, []f64, runtime.Allocator) -> Mask,
    cmd__arr_f64__arr_int:   proc([]f64, []int, runtime.Allocator) -> Mask,
    cmd__str__arr_str:       proc(string, []string, runtime.Allocator) -> Mask,
    cmd__arr_str__str:       proc([]string, string, runtime.Allocator) -> Mask,
    cmd__arr_str__arr_str:   proc([]string, []string, runtime.Allocator) -> Mask,
    cmd__bool__arr_bool:     proc(bool, []bool, runtime.Allocator) -> Mask,
    cmd__arr_bool__bool:     proc([]bool, bool, runtime.Allocator) -> Mask,
    cmd__arr_bool__arr_bool: proc([]bool, []bool, runtime.Allocator) -> Mask,

    allocator := context.temp_allocator
) -> (mask: Mask) {
    info :: reflect.union_variant_type_info
    left_id := info(left).id
    right_id := info(right).id


    LR :: struct {
        l: typeid,
        r: typeid,
    }

    lr := LR{left_id, right_id}

    // TODO: the error string is in a haphazard place. This should probably be
    // constructed in a function and returned.
    error_string := fmt.tprintf("Attempting to compare an %v to a %v. This is not valid. Numeric types cannot be compared against non-numerics.", lr.l, lr.r)

    // I would like to rely on the compiler to check for coverage. If I ever
    // learn this I would like to come back and improve.
    switch lr {
    case LR{int, int}, LR{int, f64}, LR{f64, int}, LR{f64, f64}, LR{string, string}, LR{bool, bool}: {
        // Strange ask... there is nothing to do.
        fmt.eprintln("Attempting to create a mask using two scalar values. Request is not valid.")
    }
    case LR{int, ColumnSlice}: {
        switch right_column in right.(ColumnSlice) {
        case []int: mask = cmd__int__arr_int(left.(int), right_column, allocator)
        case []f64: mask = cmd__int__arr_f64(left.(int), right_column, allocator)
        case []string: fmt.eprintln(error_string)
        case []bool: fmt.eprintln(error_string)
        }
    }
    case LR{f64, ColumnSlice}: {
        switch right_column in right.(ColumnSlice) {
        case []int: mask = cmd__f64__arr_int(left.(f64), right_column, allocator)
        case []f64: mask = cmd__f64__arr_f64(left.(f64), right_column, allocator)
        case []string: fmt.eprintln(error_string)
        case []bool: fmt.eprintln(error_string)
        }
    }
    case LR{ColumnSlice, int}: {
        switch left_column in left.(ColumnSlice) {
        case []int: mask = cmd__arr_int__int(left_column, right.(int), allocator)
        case []f64: mask = cmd__arr_f64__int(left_column, right.(int), allocator)
        case []string: {
            fmt.eprintln(error_string)
        }
        case []bool: {
            fmt.eprintln(error_string)
        }
        }
    }
    case LR{ColumnSlice, f64}: {
        switch left_column in left.(ColumnSlice) {
        case []int: mask = cmd__arr_int__f64(left_column, right.(f64), allocator)
        case []f64: mask = cmd__arr_f64__f64(left_column, right.(f64), allocator)
        case []string: {
            fmt.eprintln(error_string)
        }
        case []bool: {
            fmt.eprintln(error_string)
        }
        }
    }
    case LR{string, ColumnSlice}: {
        switch right_column in right.(ColumnSlice) {
        case []int, []f64, []bool: {
            fmt.eprintln("Attempting to compare a string to a numeric or boolean. This is not valid. Numeric types cannot be compared against strings.")
        }
        case []string: mask = cmd__str__arr_str(left.(string), right_column, allocator)
        }
    }
    case LR{ColumnSlice, string}: {
        // TODO
        switch left_column in left.(ColumnSlice) {
        case []int, []f64, []bool: {
            fmt.eprintln("Attempting to compare a string to a numeric or boolean. This is not valid. Numeric types cannot be compared against strings.")
        }
        case []string: {
            mask = cmd__arr_str__str(left_column, right.(string), allocator)
        }
        }
    }
    case LR{ColumnSlice, ColumnSlice}: {
        switch l in left.(ColumnSlice) {
        case []int: {
            switch r in right.(ColumnSlice) {
            case []int: mask = cmd__arr_int__arr_int(l, r, allocator)
            case []f64: mask = cmd__arr_int__arr_f64(l, r, allocator)
            case []string: fmt.eprintln(error_string)
            case []bool: fmt.eprintln(error_string)
            }
        }
        case []f64: {
            switch r in right.(ColumnSlice) {
            case []int: mask = cmd__arr_f64__arr_int(l, r, allocator)
            case []f64: mask = cmd__arr_f64__arr_f6(l, r, allocator)
            case []string: fmt.eprintln(error_string)
            case []bool: fmt.eprintln(error_string)
            }
        }
        case []string: {
            switch r in right.(ColumnSlice) {
            case []string: cmd__arr_str__arr_str(l, r, allocator)
            case []int, []f64, []bool: {
                fmt.eprintln("Attempting to compare a string to a numeric or boolean. This is not valid. Numeric types cannot be compared against strings.")
            }
            }
        }
        case []bool: {
            switch r in right.(ColumnSlice) {
            case []bool: cmd__arr_bool__arr_bool(l, r, allocator)
            case []int, []f64, []string: {
                fmt.eprintln("Attempting to compare a numeric or string to a boolean. This is not valid. Booleans can only be compared against booleans.")
            }
            }
        }
        }
    }
    case: {
        fmt.eprintln("Unknown and not implemented operands.")
    }
    }
    return mask
}

@(test)
and_operator :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"One", "Two", "Three"},
        []int{1, 2, 3},
        []int{3, 2, 1},
        []int{5, 5, 1},
    )
    defer delete_dataframe(df)

    op1 := Operation{"One", .Eq, "Two"}
    op2 := Operation{"One", .Less, "Three"}
    op3 := Operation{&op1, .And, &op2}

    dfs, ok := filter(&df, op3)
    defer delete_dataframe(dfs)


    /* Expects the filtered dataframe to be the following
    ┌─────┬───────┬─────┐
    │ One ┆ Three ┆ Two │
    │ --- ┆ ---   ┆ --- │
    │ int ┆ int   ┆ int │
    ╞═════╪═══════╪═════╡
    │ 2   ┆ 5     ┆ 2   │
    */
    testing.expect(t, ok)

    c_one, _ := get_columnslice(dfs, "One")
    testing.expect_value(t, c_one.([]int)[0], 2)

    c_two, _   := get_columnslice(dfs, "Two")
    testing.expect_value(t, c_two.([]int)[0], 2)

    c_three, _ := get_columnslice(dfs, "Three")
    testing.expect_value(t, c_three.([]int)[0], 5)
}

@(test)
or_operator :: proc(t: ^testing.T) {
    df := make_dataframe_from_literal(
        {"One", "Two", "Three"},
        []int{1, 2, 3},
        []int{3, 2, 1},
        []int{5, 5, 1},
    )
    defer delete_dataframe(df)

    op1 := Operation{"One", .Eq, "Two"}
    op2 := Operation{"One", .Less, "Three"}
    op3 := Operation{&op1, .Or, &op2}

    dfs, ok := filter(&df, op3)
    defer delete_dataframe(dfs)


    /* Expects the filtered dataframe to be the following
    ┌─────┬───────┬─────┐
    │ One ┆ Three ┆ Two │
    │ --- ┆ ---   ┆ --- │
    │ int ┆ int   ┆ int │
    ╞═════╪═══════╪═════╡
    │ 1   ┆ 5     ┆ 3   │
    │ 2   ┆ 5     ┆ 2   │
    */
    testing.expect(t, ok)

    c_one, _ := get_columnslice(dfs, "One")
    testing.expect_value(t, c_one.([]int)[0], 1)
    testing.expect_value(t, c_one.([]int)[1], 2)

    c_two, _   := get_columnslice(dfs, "Two")
    testing.expect_value(t, c_two.([]int)[0], 3)
    testing.expect_value(t, c_two.([]int)[1], 2)

    c_three, _ := get_columnslice(dfs, "Three")
    testing.expect_value(t, c_three.([]int)[0], 5)
    testing.expect_value(t, c_three.([]int)[1], 5)
}
