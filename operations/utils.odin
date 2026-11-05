package operations

import "base:runtime"
import "core:log"

Mask :: []bool

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
        log.fatalf("precedence: unexpected typeid pair. Left: %v Right: %v", s.l, s.r)
    }
    }
    runtime.panic("Type combination is un-accounted for.")
}
