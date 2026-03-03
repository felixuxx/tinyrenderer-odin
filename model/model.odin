package tr_model

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import img "tr:image"
import m "tr:math"

Model :: struct {
    verts:     [dynamic]m.Vec4,
    norms:     [dynamic]m.Vec4,
    tex:       [dynamic]m.Vec2,
    facet_vrt: [dynamic]int,
    facet_nrm: [dynamic]int,
    facet_tex: [dynamic]int,

    diffusemap:  img.Image,
    normalmap:   img.Image,
    specularmap: img.Image,
}

load :: proc(filename: string) -> (Model, bool) {
    mdl := Model{}

    bytes, ok := os.read_entire_file(filename)
    if !ok {
        return mdl, false
    }
    defer delete(bytes)

    text := string(bytes)
    remaining := text

    parse_f64 :: proc(tok: string) -> (f64, bool) {
        return strconv.parse_f64(strings.trim_space(tok))
    }

    parse_i :: proc(tok: string) -> (int, bool) {
        v, ok := strconv.parse_i64(strings.trim_space(tok))
        if !ok {
            return 0, false
        }
        return int(v), true
    }

    parse_face_triplet :: proc(tok: string) -> (f, t, n: int, ok: bool) {
        s1 := strings.index_byte(tok, '/')
        if s1 < 0 {
            return 0, 0, 0, false
        }
        s2_rel := strings.index_byte(tok[s1+1:], '/')
        if s2_rel < 0 {
            return 0, 0, 0, false
        }
        s2 := s1 + 1 + s2_rel

        fv, ok1 := parse_i(tok[:s1])
        tv, ok2 := parse_i(tok[s1+1:s2])
        nv, ok3 := parse_i(tok[s2+1:])
        if !ok1 || !ok2 || !ok3 {
            return 0, 0, 0, false
        }
        return fv, tv, nv, true
    }

    for line, line_ok := strings.split_lines_iterator(&remaining); line_ok; line, line_ok = strings.split_lines_iterator(&remaining) {
        line = strings.trim_space(line)
        if len(line) == 0 || strings.has_prefix(line, "#") {
            continue
        }

        fields_src := line
        head, has_head := strings.fields_iterator(&fields_src)
        if !has_head {
            continue
        }

        switch head {
        case "v":
            x_tok, okx := strings.fields_iterator(&fields_src)
            y_tok, oky := strings.fields_iterator(&fields_src)
            z_tok, okz := strings.fields_iterator(&fields_src)
            if !okx || !oky || !okz {
                continue
            }
            x, okx_num := parse_f64(x_tok)
            y, oky_num := parse_f64(y_tok)
            z, okz_num := parse_f64(z_tok)
            if !okx_num || !oky_num || !okz_num {
                continue
            }
            append(&mdl.verts, m.Vec4{x, y, z, 1})

        case "vn":
            x_tok, okx := strings.fields_iterator(&fields_src)
            y_tok, oky := strings.fields_iterator(&fields_src)
            z_tok, okz := strings.fields_iterator(&fields_src)
            if !okx || !oky || !okz {
                continue
            }
            x, okx_num := parse_f64(x_tok)
            y, oky_num := parse_f64(y_tok)
            z, okz_num := parse_f64(z_tok)
            if !okx_num || !oky_num || !okz_num {
                continue
            }
            n := m.normalize4(m.Vec4{x, y, z, 0})
            append(&mdl.norms, n)

        case "vt":
            u_tok, oku := strings.fields_iterator(&fields_src)
            v_tok, okv := strings.fields_iterator(&fields_src)
            if !oku || !okv {
                continue
            }
            u, oku_num := parse_f64(u_tok)
            v, okv_num := parse_f64(v_tok)
            if !oku_num || !okv_num {
                continue
            }
            append(&mdl.tex, m.Vec2{u, 1-v})

        case "f":
            tri_count := 0
            for part, ok := strings.fields_iterator(&fields_src); ok; part, ok = strings.fields_iterator(&fields_src) {
                f, t, n, ok := parse_face_triplet(part)
                if !ok {
                    continue
                }
                append(&mdl.facet_vrt, f-1)
                append(&mdl.facet_tex, t-1)
                append(&mdl.facet_nrm, n-1)
                tri_count += 1
            }
            if tri_count != 3 {
                fmt.eprintln("Error: the obj file is supposed to be triangulated")
                return mdl, false
            }
        }
    }

    fmt.eprintln("# v#", nverts(mdl), "f#", nfaces(mdl))

    dot := strings.last_index_byte(filename, '.')
    if dot >= 0 {
        base := filename[:dot]

        load_texture :: proc(base, suffix: string, tex: ^img.Image) {
            texfile_bytes := make([dynamic]u8, 0, len(base)+len(suffix))
            defer delete(texfile_bytes)
            append(&texfile_bytes, ..transmute([]u8)base)
            append(&texfile_bytes, ..transmute([]u8)suffix)
            texfile := string(texfile_bytes[:])
            ok := img.read_tga_file(tex, texfile)
            status := "failed"
            if ok {
                status = "ok"
            }
            fmt.eprintln("texture file", texfile, "loading", status)
        }

        load_texture(base, "_diffuse.tga", &mdl.diffusemap)
        load_texture(base, "_nm_tangent.tga", &mdl.normalmap)
        load_texture(base, "_spec.tga", &mdl.specularmap)
    }

    return mdl, true
}

nverts :: proc(mdl: Model) -> int {
    return len(mdl.verts)
}

nfaces :: proc(mdl: Model) -> int {
    return len(mdl.facet_vrt) / 3
}

vert_indexed :: proc(mdl: Model, iface, nthvert: int) -> m.Vec4 {
    idx := mdl.facet_vrt[iface*3+nthvert]
    return mdl.verts[idx]
}

uv_indexed :: proc(mdl: Model, iface, nthvert: int) -> m.Vec2 {
    idx := mdl.facet_tex[iface*3+nthvert]
    return mdl.tex[idx]
}

normal_indexed :: proc(mdl: Model, iface, nthvert: int) -> m.Vec4 {
    idx := mdl.facet_nrm[iface*3+nthvert]
    return mdl.norms[idx]
}

normal_from_map :: proc(mdl: Model, uv: m.Vec2) -> m.Vec4 {
    x := int(uv.x * f64(img.width(mdl.normalmap)))
    y := int(uv.y * f64(img.height(mdl.normalmap)))
    c := img.get_pixel(mdl.normalmap, x, y)

    n := m.Vec4{
        x = f64(c.bgra[2]),
        y = f64(c.bgra[1]),
        z = f64(c.bgra[0]),
        w = 0,
    }
    n = m.sub4(m.scale4(n, 2.0/255.0), m.Vec4{1, 1, 1, 0})
    return m.normalize4(n)
}

diffuse :: proc(mdl: Model) -> img.Image {
    return mdl.diffusemap
}

specular :: proc(mdl: Model) -> img.Image {
    return mdl.specularmap
}
