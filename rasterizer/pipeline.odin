package tr_rasterizer

import "core:math"
import "core:os"
import "core:thread"
import img "tr:image"
import m "tr:math"

Vertex_Proc :: #type proc(user_context: rawptr, face, vert: int) -> m.Vec4
Fragment_Proc :: #type proc(user_context: rawptr, bar: m.Vec3, out_color: ^img.Color) -> bool

Shader :: struct {
    user_context: rawptr,
    vertex_proc:  Vertex_Proc,
    frag_proc:    Fragment_Proc,
}

Triangle :: [3]m.Vec4

State :: struct {
    ModelView:   m.Mat4,
    Viewport:    m.Mat4,
    Perspective: m.Mat4,
    zbuffer:     [dynamic]f64,
}

global_state: State
parallel_pool: thread.Pool
parallel_pool_ready: bool
parallel_workers: int

Raster_Task :: struct {
    x0: int,
    x1: int,
    y0: int,
    y1: int,

    fb_w: int,

    inv_t: m.Mat3,
    ndc: [3]m.Vec4,
    clip: Triangle,

    shader: Shader,
    framebuffer: ^img.Image,
}

init_parallel_pool :: proc() {
    if parallel_pool_ready {
        return
    }

    cores := os.processor_core_count()
    if cores < 1 {
        cores = 1
    }
    parallel_workers = cores

    thread.pool_init(&parallel_pool, context.allocator, parallel_workers)
    thread.pool_start(&parallel_pool)
    parallel_pool_ready = true
}

raster_task_proc :: proc(task: thread.Task) {
    td := (^Raster_Task)(task.data)

    for x in td.x0..=td.x1 {
        for y in td.y0..=td.y1 {
            bc_screen := m.mul_mat3_vec3(td.inv_t, m.Vec3{f64(x), f64(y), 1})
            if bc_screen.x < 0 || bc_screen.y < 0 || bc_screen.z < 0 {
                continue
            }

            bc_clip := m.Vec3{
                bc_screen.x / td.clip[0].w,
                bc_screen.y / td.clip[1].w,
                bc_screen.z / td.clip[2].w,
            }
            sum := bc_clip.x + bc_clip.y + bc_clip.z
            bc_clip = m.div3(bc_clip, sum)

            z := m.dot3(bc_screen, m.Vec3{td.ndc[0].z, td.ndc[1].z, td.ndc[2].z})
            idx := x + y*td.fb_w
            if z <= global_state.zbuffer[idx] {
                continue
            }

            color := img.Color{}
            discard := td.shader.frag_proc(td.shader.user_context, bc_clip, &color)
            if discard {
                continue
            }

            global_state.zbuffer[idx] = z
            img.set_pixel(td.framebuffer, x, y, color)
        }
    }
}

init_state :: proc() {
    init_parallel_pool()

    global_state.ModelView = m.mat4_identity()
    global_state.Viewport = m.mat4_identity()
    global_state.Perspective = m.mat4_identity()
    if len(global_state.zbuffer) > 0 {
        delete(global_state.zbuffer)
    }
    global_state.zbuffer = make([dynamic]f64, 0)
}

lookat :: proc(eye, center, up: m.Vec3) {
    n := m.normalize3(m.sub3(eye, center))
    l := m.normalize3(m.cross3(up, n))
    mm := m.normalize3(m.cross3(n, l))

    orient := m.Mat4{}
    orient.m[0] = [4]f64{l.x, l.y, l.z, 0}
    orient.m[1] = [4]f64{mm.x, mm.y, mm.z, 0}
    orient.m[2] = [4]f64{n.x, n.y, n.z, 0}
    orient.m[3] = [4]f64{0, 0, 0, 1}

    translate := m.mat4_identity()
    translate.m[0][3] = -center.x
    translate.m[1][3] = -center.y
    translate.m[2][3] = -center.z

    global_state.ModelView = m.mul_mat4(orient, translate)
}

init_perspective :: proc(f: f64) {
    p := m.mat4_identity()
    p.m[3][2] = -1.0 / f
    global_state.Perspective = p
}

init_viewport :: proc(x, y, w, h: int) {
    vp := m.mat4_identity()
    vp.m[0][0] = f64(w) / 2.0
    vp.m[0][3] = f64(x) + f64(w)/2.0
    vp.m[1][1] = f64(h) / 2.0
    vp.m[1][3] = f64(y) + f64(h)/2.0
    global_state.Viewport = vp
}

init_zbuffer :: proc(width, height: int) {
    count := width * height
    if len(global_state.zbuffer) > 0 {
        delete(global_state.zbuffer)
    }
    global_state.zbuffer = make([dynamic]f64, count)
    for i in 0..<count {
        global_state.zbuffer[i] = -1000.0
    }
}

rasterize :: proc(clip: Triangle, shader: Shader, framebuffer: ^img.Image) {
    if framebuffer == nil || shader.frag_proc == nil {
        return
    }

    fb_w := img.width(framebuffer^)
    fb_h := img.height(framebuffer^)
    if fb_w <= 0 || fb_h <= 0 {
        return
    }

    ndc: [3]m.Vec4
    for i in 0..<3 {
        ndc[i] = m.div4(clip[i], clip[i].w)
    }

    screen: [3]m.Vec2
    for i in 0..<3 {
        sp := m.mul_mat4_vec4(global_state.Viewport, ndc[i])
        screen[i] = m.vec4_xy(sp)
    }

    abc := m.Mat3{}
    abc.m[0] = [3]f64{screen[0].x, screen[0].y, 1}
    abc.m[1] = [3]f64{screen[1].x, screen[1].y, 1}
    abc.m[2] = [3]f64{screen[2].x, screen[2].y, 1}

    if m.det3(abc) < 1.0 {
        return
    }

    inv_t, ok := m.invert_transpose3(abc)
    if !ok {
        return
    }

    min_x := screen[0].x
    max_x := screen[0].x
    min_y := screen[0].y
    max_y := screen[0].y
    for i in 1..<3 {
        if screen[i].x < min_x { min_x = screen[i].x }
        if screen[i].x > max_x { max_x = screen[i].x }
        if screen[i].y < min_y { min_y = screen[i].y }
        if screen[i].y > max_y { max_y = screen[i].y }
    }

    x0 := int(min_x)
    y0 := int(min_y)
    x1 := int(max_x)
    y1 := int(max_y)

    if x0 < 0 { x0 = 0 }
    if y0 < 0 { y0 = 0 }
    if x1 >= fb_w { x1 = fb_w-1 }
    if y1 >= fb_h { y1 = fb_h-1 }
    if x0 > x1 || y0 > y1 {
        return
    }

    span_x := x1 - x0 + 1
    workers := parallel_workers
    if workers < 1 {
        workers = 1
    }

    // Keep tiny triangles single-threaded to avoid scheduling overhead.
    if span_x < 64 || workers == 1 {
        td := Raster_Task{
            x0 = x0, x1 = x1,
            y0 = y0, y1 = y1,
            fb_w = fb_w,
            inv_t = inv_t,
            ndc = ndc,
            clip = clip,
            shader = shader,
            framebuffer = framebuffer,
        }
        raster_task_proc(thread.Task{data = rawptr(&td)})
        return
    }

    task_count := workers
    if task_count > span_x {
        task_count = span_x
    }

    tasks := make([]Raster_Task, task_count)
    defer delete(tasks)

    step := (span_x + task_count - 1) / task_count
    queued := 0

    // Queue all chunks except the first one.
    for i in 1..<task_count {
        sx := x0 + i*step
        ex := sx + step - 1
        if sx > x1 {
            break
        }
        if ex > x1 {
            ex = x1
        }

        tasks[i] = Raster_Task{
            x0 = sx, x1 = ex,
            y0 = y0, y1 = y1,
            fb_w = fb_w,
            inv_t = inv_t,
            ndc = ndc,
            clip = clip,
            shader = shader,
            framebuffer = framebuffer,
        }

        thread.pool_add_task(&parallel_pool, context.allocator, raster_task_proc, rawptr(&tasks[i]))
        queued += 1
    }

    // Process the first chunk on the calling thread.
    ex0 := x0 + step - 1
    if ex0 > x1 {
        ex0 = x1
    }
    tasks[0] = Raster_Task{
        x0 = x0, x1 = ex0,
        y0 = y0, y1 = y1,
        fb_w = fb_w,
        inv_t = inv_t,
        ndc = ndc,
        clip = clip,
        shader = shader,
        framebuffer = framebuffer,
    }
    raster_task_proc(thread.Task{data = rawptr(&tasks[0])})

    if queued > 0 {
        for thread.pool_num_outstanding(&parallel_pool) > 0 {
            thread.yield()
        }

        for {
            _, ok_done := thread.pool_pop_done(&parallel_pool)
            if !ok_done {
                break
            }
        }
    }
}

modelview :: proc() -> m.Mat4 {
    return global_state.ModelView
}

viewport :: proc() -> m.Mat4 {
    return global_state.Viewport
}

perspective :: proc() -> m.Mat4 {
    return global_state.Perspective
}
