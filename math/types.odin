package tr_math

import "core:math"

Vec2 :: struct {
    x: f64,
    y: f64,
}

Vec3 :: struct {
    x: f64,
    y: f64,
    z: f64,
}

Vec4 :: struct {
    x: f64,
    y: f64,
    z: f64,
    w: f64,
}

Mat4 :: struct {
    m: [4][4]f64,
}

Mat3 :: struct {
    m: [3][3]f64,
}

Mat2 :: struct {
    m: [2][2]f64,
}

vec2 :: proc(x, y: f64) -> Vec2 {
    return Vec2{x, y}
}

vec3 :: proc(x, y, z: f64) -> Vec3 {
    return Vec3{x, y, z}
}

vec4 :: proc(x, y, z, w: f64) -> Vec4 {
    return Vec4{x, y, z, w}
}

vec4_xyz :: proc(v: Vec4) -> Vec3 {
    return Vec3{v.x, v.y, v.z}
}

vec4_xy :: proc(v: Vec4) -> Vec2 {
    return Vec2{v.x, v.y}
}

add2 :: proc(a, b: Vec2) -> Vec2 {
    return Vec2{a.x + b.x, a.y + b.y}
}

sub2 :: proc(a, b: Vec2) -> Vec2 {
    return Vec2{a.x - b.x, a.y - b.y}
}

scale2 :: proc(v: Vec2, s: f64) -> Vec2 {
    return Vec2{v.x * s, v.y * s}
}

div2 :: proc(v: Vec2, s: f64) -> Vec2 {
    return Vec2{v.x / s, v.y / s}
}

dot2 :: proc(a, b: Vec2) -> f64 {
    ret := 0.0
    ret += a.y * b.y
    ret += a.x * b.x
    return ret
}

norm2 :: proc(v: Vec2) -> f64 {
    return math.sqrt(dot2(v, v))
}

normalize2 :: proc(v: Vec2) -> Vec2 {
    n := norm2(v)
    if n == 0 {
        return v
    }
    return div2(v, n)
}

add3 :: proc(a, b: Vec3) -> Vec3 {
    return Vec3{a.x + b.x, a.y + b.y, a.z + b.z}
}

sub3 :: proc(a, b: Vec3) -> Vec3 {
    return Vec3{a.x - b.x, a.y - b.y, a.z - b.z}
}

scale3 :: proc(v: Vec3, s: f64) -> Vec3 {
    return Vec3{v.x * s, v.y * s, v.z * s}
}

div3 :: proc(v: Vec3, s: f64) -> Vec3 {
    return Vec3{v.x / s, v.y / s, v.z / s}
}

dot3 :: proc(a, b: Vec3) -> f64 {
    ret := 0.0
    ret += a.z * b.z
    ret += a.y * b.y
    ret += a.x * b.x
    return ret
}

cross3 :: proc(a, b: Vec3) -> Vec3 {
    return Vec3{
        a.y*b.z - a.z*b.y,
        a.z*b.x - a.x*b.z,
        a.x*b.y - a.y*b.x,
    }
}

norm3 :: proc(v: Vec3) -> f64 {
    return math.sqrt(dot3(v, v))
}

normalize3 :: proc(v: Vec3) -> Vec3 {
    n := norm3(v)
    if n == 0 {
        return v
    }
    return Vec3{v.x / n, v.y / n, v.z / n}
}

add4 :: proc(a, b: Vec4) -> Vec4 {
    return Vec4{a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w}
}

sub4 :: proc(a, b: Vec4) -> Vec4 {
    return Vec4{a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w}
}

scale4 :: proc(v: Vec4, s: f64) -> Vec4 {
    return Vec4{v.x * s, v.y * s, v.z * s, v.w * s}
}

div4 :: proc(v: Vec4, s: f64) -> Vec4 {
    return Vec4{v.x / s, v.y / s, v.z / s, v.w / s}
}

dot4 :: proc(a, b: Vec4) -> f64 {
    ret := 0.0
    ret += a.w * b.w
    ret += a.z * b.z
    ret += a.y * b.y
    ret += a.x * b.x
    return ret
}

norm4 :: proc(v: Vec4) -> f64 {
    return math.sqrt(dot4(v, v))
}

normalize4 :: proc(v: Vec4) -> Vec4 {
    n := norm4(v)
    if n == 0 {
        return v
    }
    return div4(v, n)
}

mat2_identity :: proc() -> Mat2 {
    out := Mat2{}
    out.m[0][0] = 1
    out.m[1][1] = 1
    return out
}

mat3_identity :: proc() -> Mat3 {
    out := Mat3{}
    out.m[0][0] = 1
    out.m[1][1] = 1
    out.m[2][2] = 1
    return out
}

mat4_identity :: proc() -> Mat4 {
    out := Mat4{}
    out.m[0][0] = 1
    out.m[1][1] = 1
    out.m[2][2] = 1
    out.m[3][3] = 1
    return out
}

transpose2 :: proc(m: Mat2) -> Mat2 {
    out := Mat2{}
    for r in 0..<2 {
        for c in 0..<2 {
            out.m[r][c] = m.m[c][r]
        }
    }
    return out
}

transpose3 :: proc(m: Mat3) -> Mat3 {
    out := Mat3{}
    for r in 0..<3 {
        for c in 0..<3 {
            out.m[r][c] = m.m[c][r]
        }
    }
    return out
}

transpose4 :: proc(m: Mat4) -> Mat4 {
    out := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            out.m[r][c] = m.m[c][r]
        }
    }
    return out
}

mul_mat2_vec2 :: proc(m: Mat2, v: Vec2) -> Vec2 {
    out := Vec2{}
    for r := 1; r >= 0; r -= 1 {
        acc := 0.0
        for c := 1; c >= 0; c -= 1 {
            if c == 0 {
                acc += m.m[r][c] * v.x
            } else {
                acc += m.m[r][c] * v.y
            }
        }
        if r == 0 {
            out.x = acc
        } else {
            out.y = acc
        }
    }
    return out
}

mul_mat3_vec3 :: proc(m: Mat3, v: Vec3) -> Vec3 {
    out := Vec3{}
    for r := 2; r >= 0; r -= 1 {
        acc := 0.0
        for c := 2; c >= 0; c -= 1 {
            switch c {
            case 0: acc += m.m[r][c] * v.x
            case 1: acc += m.m[r][c] * v.y
            case 2: acc += m.m[r][c] * v.z
            }
        }
        switch r {
        case 0: out.x = acc
        case 1: out.y = acc
        case 2: out.z = acc
        }
    }
    return out
}

mul_mat4_vec4 :: proc(m: Mat4, v: Vec4) -> Vec4 {
    out := Vec4{}
    for r := 3; r >= 0; r -= 1 {
        acc := 0.0
        for c := 3; c >= 0; c -= 1 {
            switch c {
            case 0: acc += m.m[r][c] * v.x
            case 1: acc += m.m[r][c] * v.y
            case 2: acc += m.m[r][c] * v.z
            case 3: acc += m.m[r][c] * v.w
            }
        }
        switch r {
        case 0: out.x = acc
        case 1: out.y = acc
        case 2: out.z = acc
        case 3: out.w = acc
        }
    }
    return out
}

mul_mat2 :: proc(a, b: Mat2) -> Mat2 {
    out := Mat2{}
    for r := 1; r >= 0; r -= 1 {
        for c := 1; c >= 0; c -= 1 {
            for k := 1; k >= 0; k -= 1 {
                out.m[r][c] += a.m[r][k] * b.m[k][c]
            }
        }
    }
    return out
}

mul_mat3 :: proc(a, b: Mat3) -> Mat3 {
    out := Mat3{}
    for r := 2; r >= 0; r -= 1 {
        for c := 2; c >= 0; c -= 1 {
            for k := 2; k >= 0; k -= 1 {
                out.m[r][c] += a.m[r][k] * b.m[k][c]
            }
        }
    }
    return out
}

mul_mat4 :: proc(a, b: Mat4) -> Mat4 {
    out := Mat4{}
    for r := 3; r >= 0; r -= 1 {
        for c := 3; c >= 0; c -= 1 {
            for k := 3; k >= 0; k -= 1 {
                out.m[r][c] += a.m[r][k] * b.m[k][c]
            }
        }
    }
    return out
}

scale_mat4 :: proc(m: Mat4, s: f64) -> Mat4 {
    out := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            out.m[r][c] = m.m[r][c] * s
        }
    }
    return out
}

add_mat4 :: proc(a, b: Mat4) -> Mat4 {
    out := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            out.m[r][c] = a.m[r][c] + b.m[r][c]
        }
    }
    return out
}

sub_mat4 :: proc(a, b: Mat4) -> Mat4 {
    out := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            out.m[r][c] = a.m[r][c] - b.m[r][c]
        }
    }
    return out
}

det2 :: proc(m: Mat2) -> f64 {
    return m.m[0][0]*m.m[1][1] - m.m[0][1]*m.m[1][0]
}

det3 :: proc(m: Mat3) -> f64 {
    ret := 0.0
    for i := 2; i >= 0; i -= 1 {
        sub := Mat2{}
        rr := 0
        for r := 2; r >= 1; r -= 1 {
            cc := 0
            for c := 2; c >= 0; c -= 1 {
                if c == i {
                    continue
                }
                sub.m[rr][cc] = m.m[r][c]
                cc += 1
            }
            rr += 1
        }

        cof := det2(sub)
        if i%2 != 0 {
            cof = -cof
        }
        ret += m.m[0][i] * cof
    }
    return ret
}

cofactor3 :: proc(m: Mat3, row, col: int) -> f64 {
    sub := Mat2{}
    for i := 1; i >= 0; i -= 1 {
        for j := 1; j >= 0; j -= 1 {
            src_i := i
            if i >= row {
                src_i += 1
            }
            src_j := j
            if j >= col {
                src_j += 1
            }
            sub.m[i][j] = m.m[src_i][src_j]
        }
    }

    cof := det2(sub)
    if (row+col)%2 != 0 {
        cof = -cof
    }
    return cof
}

invert_transpose3 :: proc(m: Mat3) -> (Mat3, bool) {
    adj_t := Mat3{}
    for i := 2; i >= 0; i -= 1 {
        for j := 2; j >= 0; j -= 1 {
            adj_t.m[i][j] = cofactor3(m, i, j)
        }
    }

    denom := adj_t.m[0][0]*m.m[0][0] + adj_t.m[0][1]*m.m[0][1] + adj_t.m[0][2]*m.m[0][2]
    if denom == 0 {
        return Mat3{}, false
    }

    inv_d := 1.0 / denom
    out := Mat3{}
    for i := 2; i >= 0; i -= 1 {
        for j := 2; j >= 0; j -= 1 {
            out.m[i][j] = adj_t.m[i][j] * inv_d
        }
    }
    return out, true
}

minor4 :: proc(m: Mat4, row_skip, col_skip: int) -> Mat3 {
    out := Mat3{}
    rr := 0
    for r in 0..<4 {
        if r == row_skip {
            continue
        }
        cc := 0
        for c in 0..<4 {
            if c == col_skip {
                continue
            }
            out.m[rr][cc] = m.m[r][c]
            cc += 1
        }
        rr += 1
    }
    return out
}

cofactor4 :: proc(m: Mat4, row, col: int) -> f64 {
    sign := 1.0
    if (row+col)%2 != 0 {
        sign = -1.0
    }
    return sign * det3(minor4(m, row, col))
}

det4 :: proc(m: Mat4) -> f64 {
    out := 0.0
    for c in 0..<4 {
        out += m.m[0][c] * cofactor4(m, 0, c)
    }
    return out
}

invert2 :: proc(m: Mat2) -> (Mat2, bool) {
    d := det2(m)
    if d == 0 {
        return Mat2{}, false
    }
    out := Mat2{}
    out.m[0][0] = m.m[1][1]
    out.m[0][1] = -m.m[0][1]
    out.m[1][0] = -m.m[1][0]
    out.m[1][1] = m.m[0][0]
    inv := 1.0 / d
    for r in 0..<2 {
        for c in 0..<2 {
            out.m[r][c] *= inv
        }
    }
    return out, true
}

invert3 :: proc(m: Mat3) -> (Mat3, bool) {
    d := det3(m)
    if d == 0 {
        return Mat3{}, false
    }

    cof := Mat3{}
    for r in 0..<3 {
        for c in 0..<3 {
            sub := Mat2{}
            rr := 0
            for r2 in 0..<3 {
                if r2 == r {
                    continue
                }
                cc := 0
                for c2 in 0..<3 {
                    if c2 == c {
                        continue
                    }
                    sub.m[rr][cc] = m.m[r2][c2]
                    cc += 1
                }
                rr += 1
            }
            sign := 1.0
            if (r+c)%2 != 0 {
                sign = -1.0
            }
            cof.m[r][c] = sign * det2(sub)
        }
    }

    adj_t := cof
    adj := transpose3(adj_t)
    inv := 1.0 / d
    out := Mat3{}
    for r in 0..<3 {
        for c in 0..<3 {
            out.m[r][c] = adj.m[r][c] * inv
        }
    }
    return out, true
}

invert4 :: proc(m: Mat4) -> (Mat4, bool) {
    d := det4(m)
    if d == 0 {
        return Mat4{}, false
    }

    cof := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            cof.m[r][c] = cofactor4(m, r, c)
        }
    }

    adj := transpose4(cof)
    inv := 1.0 / d
    out := Mat4{}
    for r in 0..<4 {
        for c in 0..<4 {
            out.m[r][c] = adj.m[r][c] * inv
        }
    }
    return out, true
}

invert_transpose4 :: proc(m: Mat4) -> (Mat4, bool) {
    inv, ok := invert4(m)
    if !ok {
        return Mat4{}, false
    }
    return transpose4(inv), true
}
