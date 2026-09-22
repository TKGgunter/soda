package operations

import "base:runtime"
import "core:testing"

eq_int__arr_int :: proc(left: int, right: []int, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(right, left, allocator) }
eq_int__arr_f64 :: proc(left: int, right: []f64, allocator: runtime.Allocator) -> Mask { return _eq__XX__arr_YY(left, right, allocator) }
eq_f64__arr_f64 :: proc(left: f64, right: []f64, allocator: runtime.Allocator) -> Mask { return _eq__XX__arr_XX(left, right, allocator) }
eq_f64__arr_int :: proc(left: f64, right: []int, allocator: runtime.Allocator) -> Mask { return _eq__XX__arr_YY(left, right, allocator) }
eq_arr_int__int :: proc(left: []int, right: int, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(left, right, allocator) }
eq_arr_int__f64 :: proc(left: []int, right: f64, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__YY(left, right, allocator) }
eq_arr_f64__f64 :: proc(left: []f64, right: f64, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(left, right, allocator) }
eq_arr_f64__int :: proc(left: []f64, right: int, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__YY(left, right, allocator) }
eq_arr_int__arr_int :: proc(left: []int, right: []int, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_XX(left, right, allocator) }
eq_arr_int__arr_f64 :: proc(left: []int, right: []f64, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_YY(left, right, allocator) }
eq_arr_f64__arr_f64 :: proc(left: []f64, right: []f64, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_XX(left, right, allocator) }
eq_arr_f64__arr_int :: proc(left: []f64, right: []int, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_YY(left, right, allocator) }
eq_str__arr_str :: proc(left: string, right: []string, allocator: runtime.Allocator) -> Mask { return _eq__XX__arr_XX(left, right, allocator) }
eq_arr_str__str :: proc(left: []string, right: string, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(left, right, allocator) }
eq_arr_str__arr_str :: proc(left: []string, right: []string, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_XX(left, right, allocator) }
eq_bool__arr_bool :: proc(left: bool, right: []bool, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(right, left, allocator) }
eq_arr_bool__bool :: proc(left: []bool, right: bool, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__XX(left, right, allocator) }
eq_arr_bool__arr_bool :: proc(left: []bool, right: []bool, allocator: runtime.Allocator) -> Mask { return _eq__arr_XX__arr_XX(left, right, allocator) }

@(private="file")
_eq__XX__arr_YY :: proc(left: $T, right: []$V, allocator:= context.temp_allocator) -> Mask {
    return _eq__arr_XX__YY(right, left, allocator)
}

@(private="file")
_eq__arr_XX__YY :: proc(left: []$T, right: $V, allocator:= context.temp_allocator) -> Mask 
where T != V {
    mask := make([]bool, len(left), allocator)

    switch precedence(T, V) {
    case f64: {
        for it, i in left {
            // WARNING: casting here 
            mask[i] = f64(it) == f64(right)  // I'm assuming that it's a no-op when casting a type to the type it already is.
        }
    }
    case: {
        panic("Not implemented")
    }
    }
    return mask
}

@(private="file")
_eq__arr_XX__arr_YY :: proc(left: []$T, right: []$V, allocator:= context.temp_allocator) -> Mask 
where T != V {
    mask := make([]bool, len(left), allocator)

    switch precedence(T, V) {
    case f64: {
        for it, i in left {
            // WARNING: casting here 
            mask[i] = f64(it) == f64(right[i])  // I'm assuming that it's a no-op when casting a type to the type it already is.
        }
    }
    case: {
        panic("Not implemented")
    }
    }
    return mask
}

@(private="file")
_eq__arr_XX__arr_XX :: proc(left: []$T, right: []T, allocator:= context.temp_allocator) -> Mask {
    mask := make([]bool, len(left), allocator)
    for it, i in left {
        mask[i] = it == right[i]
    }
    return mask
}

@(private="file")
_eq__arr_XX__XX :: proc(left: []$T, right: T, allocator:= context.temp_allocator) -> Mask {
    mask := make([]bool, len(left), allocator)
    for it, i in left {
        mask[i] = it == right
    }
    return mask
}

@(private="file")
_eq__XX__arr_XX :: proc(left: $T, right: []T, allocator:= context.temp_allocator) -> Mask {
    return _eq__arr_XX__XX(right, left, allocator)
}


//// Tests are below
@(private="file")
FAILURE_STRING :: "Expected: %v  Received: %v... index: %v"
@(test)
t_eq__arr_XX__arr_XX :: proc(t: ^testing.T) {
    { // Test integers
        a:[]int= {9,2,3,4}
        b:[]int= {9,2,5,4}

        expect:[]bool= {true, true, false, true}

        m:= _eq__arr_XX__arr_XX(a, b)
        
        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64
        a:[]f64= {1,2,3,4}
        b:[]f64= {1,2,5,4}

        expect:[]bool= {true, true, false, true}

        m:= _eq__arr_XX__arr_XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:[]string = {"a", "c"}
        b:[]string= {"a", "b"}

        expect:[]bool= {true, false}

        m:= _eq__arr_XX__arr_XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_eq__XX__arr_XX :: proc(t: ^testing.T) {
    { // Test integers
        a:int= 5
        b:[]int= {5, 3, 5, 7}

        expect:[]bool= {true, false, true, false}

        m:= _eq__XX__arr_XX(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:string= "b"
        b:[]string= {"b", "a", "c"}

        expect:[]bool= {true, false, false}

        m:= _eq__XX__arr_XX(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_eq__arr_XX__XX :: proc(t: ^testing.T) {
    { // Test integers
        a:[]int= {5, 3, 5, 7}
        b:int= 5

        expect:[]bool= {true, false, true, false}

        m:= _eq__arr_XX__XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test string
        a:[]string= {"b", "a", "c"}
        b:string= "b"

        expect:[]bool= {true, false, false}

        m:= _eq__arr_XX__XX(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_eq__XX__arr_YY :: proc(t: ^testing.T) {
    { // Test int left, f64 array
        a:int= 5
        b:[]f64= {5.0, 3.0, 5.0, 7.5}

        expect:[]bool= {true, false, true, false}

        m:= _eq__XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 left, int array
        a:f64= 5.0
        b:[]int= {1, 5, 6, 3}

        expect:[]bool= {false, true, false, false}

        m:= _eq__XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_eq__arr_XX__YY :: proc(t: ^testing.T) {
    { // Test int array, f64 scalar
        a:[]int= {1, 5, 6, 3}
        b:f64= 5.0

        expect:[]bool= {false, true, false, false}

        m:= _eq__arr_XX__YY(a, b)
        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 array, int scalar
        a:[]f64= {1.0, 5.0, 6.5, 3.0}
        b:int= 5

        expect:[]bool= {false, true, false, false}

        m:= _eq__arr_XX__YY(a, b)

        for i in 0..<len(a) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

@(test)
t_eq__arr_XX__arr_YY :: proc(t: ^testing.T) {
    { // Test int array, f64 array
        a:[]int= {1, 5, 6, 3}
        b:[]f64= {1.0, 5.5, 6.0, 3.0}

        expect:[]bool= {true, false, true, true}

        m:= _eq__arr_XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    { // Test f64 array, int array
        a:[]f64= {1.5, 5.0, 6.0, 3.5}
        b:[]int= {1, 5, 7, 3}

        expect:[]bool= {false, true, false, false}

        m:= _eq__arr_XX__arr_YY(a, b)

        for i in 0..<len(b) {
            testing.expectf(t, expect[i]==m[i], FAILURE_STRING, expect[i], m[i], i)
        }
    }

    free_all(context.temp_allocator)
}

