package operations

import "base:runtime"
import "core:fmt"


// TODO: This is a redefinition from the dataframe package. Update so we don't
// do this in the future.
Mask :: []bool

// TODO: not sure I like hard coding the precedence. if there are ever a large
// amount of types we may need to revisit.
precedence :: proc(l: typeid, r: typeid) -> typeid {
    S :: struct {
        l: typeid,
        r: typeid,
    }

    s := S{l, r}
    switch s {
    case S{int, f64}: return f64
    case S{f64, int}: return f64
    case S{f64, f64}: return f64
    case S{int, int}: return int
    case: {
        fmt.println(s)
    }
    }
    runtime.panic("Type combination un accounted for")
}
