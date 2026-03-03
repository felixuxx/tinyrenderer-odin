package main

import "core:fmt"
import "core:math"
import "core:os"
import img "tr:image"
import mdl "tr:model"
import m "tr:math"
import rast "tr:rasterizer"

Phong_Context :: struct {
    model:      ^mdl.Model,
    light_eye:  m.Vec4,
    varying_uv: [3]m.Vec2,
    varying_n:  [3]m.Vec4,
    tri:        [3]m.Vec4,
}

sample2d :: proc(tex: img.Image, uv: m.Vec2) -> img.Color {
    x := int(uv.x * f64(img.width(tex)))
    y := int(uv.y * f64(img.height(tex)))
    return img.get_pixel(tex, x, y)
}

phong_vertex :: proc(user_context: rawptr, face, vert: int) -> m.Vec4 {
    ctx := (^Phong_Context)(user_context)
    modelview := rast.modelview()
    perspective := rast.perspective()

    ctx.varying_uv[vert] = mdl.uv_indexed(ctx.model^, face, vert)

    n_it, ok := m.invert_transpose4(modelview)
    if !ok {
        n_it = m.mat4_identity()
    }
    n_world := mdl.normal_indexed(ctx.model^, face, vert)
    ctx.varying_n[vert] = m.mul_mat4_vec4(n_it, n_world)

    gl_pos := m.mul_mat4_vec4(modelview, mdl.vert_indexed(ctx.model^, face, vert))
    ctx.tri[vert] = gl_pos
    return m.mul_mat4_vec4(perspective, gl_pos)
}

phong_fragment :: proc(user_context: rawptr, bar: m.Vec3, out_color: ^img.Color) -> bool {
    ctx := (^Phong_Context)(user_context)
    model := ctx.model^

    e0 := m.sub4(ctx.tri[1], ctx.tri[0])
    e1 := m.sub4(ctx.tri[2], ctx.tri[0])

    duv0 := m.sub2(ctx.varying_uv[1], ctx.varying_uv[0])
    duv1 := m.sub2(ctx.varying_uv[2], ctx.varying_uv[0])
    u := m.Mat2{}
    u.m[0] = [2]f64{duv0.x, duv0.y}
    u.m[1] = [2]f64{duv1.x, duv1.y}

    u_inv, ok := m.invert2(u)
    if !ok {
        return true
    }

    t := m.add4(m.scale4(e0, u_inv.m[0][0]), m.scale4(e1, u_inv.m[0][1]))
    b := m.add4(m.scale4(e0, u_inv.m[1][0]), m.scale4(e1, u_inv.m[1][1]))
    interp_n := m.normalize4(m.add4(
        m.add4(m.scale4(ctx.varying_n[0], bar.x), m.scale4(ctx.varying_n[1], bar.y)),
        m.scale4(ctx.varying_n[2], bar.z),
    ))

    uv := m.add2(
        m.add2(m.scale2(ctx.varying_uv[0], bar.x), m.scale2(ctx.varying_uv[1], bar.y)),
        m.scale2(ctx.varying_uv[2], bar.z),
    )

    nm := mdl.normal_from_map(model, uv)
    t = m.normalize4(t)
    b = m.normalize4(b)
    n := m.normalize4(m.add4(
        m.add4(m.scale4(t, nm.x), m.scale4(b, nm.y)),
        m.scale4(interp_n, nm.z),
    ))

    l := m.normalize4(ctx.light_eye)
    r := m.normalize4(m.sub4(m.scale4(n, m.dot4(n, l)*2.0), l))

    ambient := 0.4
    diffuse := math.max(0.0, m.dot4(n, l))
    spec_sample := sample2d(mdl.specular(model), uv)
    specular := (0.5 + 2.0*f64(spec_sample.bgra[0])/255.0) * math.pow(math.max(r.z, 0.0), 35.0)

    c := sample2d(mdl.diffuse(model), uv)
    intensity := ambient + diffuse + specular
    for ch in 0..<3 {
        v := int(f64(c.bgra[ch]) * intensity)
        if v > 255 {
            v = 255
        }
        if v < 0 {
            v = 0
        }
        c.bgra[ch] = u8(v)
    }
    c.bytespp = u8(img.Format.RGB)
    out_color^ = c
    return false
}

main :: proc() {
    if len(os.args) < 2 {
        fmt.println("Usage: odin run . -collection:tr=. -- obj/model.obj")
        return
    }

    width, height := 800, 800
    light := m.Vec3{1, 1, 1}
    eye := m.Vec3{-1, 0, 2}
    center := m.Vec3{0, 0, 0}
    up := m.Vec3{0, 1, 0}

    rast.init_state()
    rast.lookat(eye, center, up)
    rast.init_perspective(m.norm3(m.sub3(eye, center)))
    rast.init_viewport(width/16, height/16, width*7/8, height*7/8)
    rast.init_zbuffer(width, height)

    clear := img.Color{bgra = [4]u8{177, 195, 209, 255}, bytespp = u8(img.Format.RGB)}
    framebuffer := img.make_image(width, height, img.Format.RGB, clear)

    modelview := rast.modelview()
    light_eye := m.mul_mat4_vec4(modelview, m.Vec4{light.x, light.y, light.z, 0})

    for i in 1..<len(os.args) {
        model, ok := mdl.load(os.args[i])
        if !ok {
            fmt.eprintln("failed to load model:", os.args[i])
            continue
        }

        ctx := Phong_Context{
            model = &model,
            light_eye = light_eye,
        }
        shader := rast.Shader{
            user_context = rawptr(&ctx),
            vertex_proc = phong_vertex,
            frag_proc = phong_fragment,
        }

        for f in 0..<mdl.nfaces(model) {
            clip := rast.Triangle{
                shader.vertex_proc(shader.user_context, f, 0),
                shader.vertex_proc(shader.user_context, f, 1),
                shader.vertex_proc(shader.user_context, f, 2),
            }
            rast.rasterize(clip, shader, &framebuffer)
        }
    }

    if !img.write_tga_file(framebuffer, "framebuffer.tga") {
        fmt.eprintln("failed to write framebuffer.tga")
        os.exit(1)
    }
}
