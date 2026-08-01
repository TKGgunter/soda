package operations

import "base:runtime"
import "core:testing"

lt_int__arr_int :: proc(left: int, right: []int, allocator: runtime.Allocator) -> Mask { return _lt__XX__arr_XX(left, right, allocator) }
lt_int__arr_f64 :: proc(left: int, right: []f64, allocator: runtime.Allocator) -> Mask { return _lt__XX__arr_YY(left, right, allocator) }
lt_f64__arr_f64 :: proc(left: f64, right: []f64, allocator: runtime.Allocator) -> Mask { return _lt__XX__arr_XX(left, right, allocator) }
lt_f64__arr_int :: proc(left: f64, right: []int, allocator: runtime.Allocator) -> Mask { return _lt__XX__arr_YY(left, right, allocator) }
lt_arr_int__int :: proc(left: []int, right: int, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__XX(left, right, allocator) }
lt_arr_int__f64 :: proc(left: []int, right: f64, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__YY(left, right, allocator) }
lt_arr_f64__f64 :: proc(left: []f64, right: f64, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__XX(left, right, allocator) }
lt_arr_f64__int :: proc(left: []f64, right: int, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__YY(left, right, allocator) }
lt_arr_int__arr_int :: proc(left: []int, right: []int, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__arr_XX(left, right, allocator) }
lt_arr_int__arr_f64 :: proc(left: []int, right: []f64, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__arr_YY(left, right, allocator) }
lt_arr_f64__arr_f64 :: proc(left: []f64, right: []f64, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__arr_XX(left, right, allocator) }
lt_arr_f64__arr_int :: proc(left: []f64, right: []int, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__arr_YY(left, right, allocator) }
lt_str__arr_str :: proc(left: string, right: []string, allocator: runtime.Allocator) -> Mask { return _lt__XX__arr_XX(left, right, allocator) }
lt_arr_str__str :: proc(left: []string, right: string, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__XX(left, right, allocator) }
lt_arr_str__arr_str :: proc(left: []string, right: []string, allocator: runtime.Allocator) -> Mask { return _lt__arr_XX__arr_XX(left, right, allocator) }

@(private="file")
_lt__arr_XX__arr_YY :: proc(left: []$T, right: []$V, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(right), allocator)
    switch precedence(T, V) {
    case int: {
        for it, i in right {
            m[i] = int(left[i]) < int(it)
        }
    }
    case f64: {
        for it, i in right {
            m[i] = f64(left[i]) < f64(it)
        }
    }
    case: {
        panic("Case not implemented")
    }
    }
    return m
}

@(private="file")
_lt__arr_XX__arr_XX :: proc(left: []$T, right: []T, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(right), allocator)
    for it, i in right {
        m[i] = left[i] < it
    }
    return m
}

@(private="file")
_lt__XX__arr_XX :: proc(left: $T, right: []T, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(right), allocator)
    for it, i in right {
        m[i] = left < it
    }
    return m
}

@(private="file")
_lt__arr_XX__XX :: proc(left: []$T, right: T, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(left), allocator)
    for it, i in left {
        m[i] = it < right
    }
    return m
}


@(private="file")
_lt__XX__arr_YY :: proc(left: $T, right: []$V, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(right), allocator)
    switch precedence(T, V) {
    case int: {
        for it, i in right {
            m[i] = int(left) < int(it)
        }
    }
    case f64: {
        for it, i in right {
            m[i] = f64(left) < f64(it)
        }
    }
    case: {
        panic("Case not implemented")
    }
    }
    return m
}

@(private="file")
_lt__arr_XX__YY :: proc(left: []$T, right: $V, allocator:= context.temp_allocator) -> Mask {
    m := make([]bool, len(left), allocator)
    switch precedence(T, V) {
    case int: {
        for it, i in left {
            m[i] = int(it) < int(right)
        }
    }
    case f64: {
        for it, i in left {
            m[i] = f64(it) < f64(right)
        }
    }
    case: {
        panic("Case not implemented")
    }
    }
    return m
}


//// Tests are below
@(private="file")
FAILURE_STRING :: "Expected: %v  Received: %v... index: %v"
@(test)
t_lt__arr_XX__arr_XX :: proc(t: ^testing.T) {
    { // Test integers
        a:[]int= {9,2,3,4}
        b:[]int= {19,12,1,14}

        expect:[]bool= {true, true, false, true}

        m:= _lt__arr_XX__arr_XX(a, b)
        
        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64
        a:[]f64= {9,2,3,4}
        b:[]f64= {19,12,1,14}

        expect:[]bool= {true, true, false, true}

        m:= _lt__arr_XX__arr_XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:[]string = {"a", "c"}
        b:[]string= {"b", "a"}

        expect:[]bool= {true, false}

        m:= _lt__arr_XX__arr_XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_lt__XX__arr_XX :: proc(t: ^testing.T) {
    { // Test integers
        a:int= 5
        b:[]int= {1, 10, 5, 3}

        expect:[]bool= {false, true, false, false}

        m:= _lt__XX__arr_XX(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:string= "b"
        b:[]string= {"a", "c", "b"}

        expect:[]bool= {false, true, false}

        m:= _lt__XX__arr_XX(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_lt__arr_XX__XX :: proc(t: ^testing.T) {
    { // Test integers
        a:[]int= {1, 10, 5, 3}
        b:int= 5

        expect:[]bool= {true, false, false, true}

        m:= _lt__arr_XX__XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:[]string= {"a", "c", "b"}
        b:string= "b"

        expect:[]bool= {true, false, false}

        m:= _lt__arr_XX__XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_lt__XX__arr_YY :: proc(t: ^testing.T) {
    { // Test int left, f64 array
        a:int= 5
        b:[]f64= {1.5, 10.5, 5.0, 3.5}

        expect:[]bool= {false, true, false, false}

        m:= _lt__XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 left, int array
        a:f64= 5.5
        b:[]int= {1, 10, 5, 3}

        expect:[]bool= {false, true, false, false}

        m:= _lt__XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_lt__arr_XX__YY :: proc(t: ^testing.T) {
    { // Test int array, f64 scalar
        a:[]int= {1, 10, 5, 3}
        b:f64= 5.0

        expect:[]bool= {true, false, false, true}

        m:= _lt__arr_XX__YY(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 array, int scalar
        a:[]f64= {1.5, 10.5, 5.0, 3.5}
        b:int= 5

        expect:[]bool= {true, false, false, true}

        m:= _lt__arr_XX__YY(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_lt__arr_XX__arr_YY :: proc(t: ^testing.T) {
    { // Test int array, f64 array
        a:[]int= {1, 10, 5, 3}
        b:[]f64= {1.5, 9.5, 5.0, 3.5}

        expect:[]bool= {true, false, false, true}

        m:= _lt__arr_XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 array, int array
        a:[]f64= {1.5, 10.5, 5.0, 3.5}
        b:[]int= {1, 9, 5, 3}

        expect:[]bool= {false, false, false, false}

        m:= _lt__arr_XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}
