package tr_image

import "core:fmt"
import "core:os"

Format :: enum u8 {
    GRAYSCALE = 1,
    RGB       = 3,
    RGBA      = 4,
}

Color :: struct {
    bgra:    [4]u8,
    bytespp: u8,
}

Image :: struct {
    w:    int,
    h:    int,
    bpp:  u8,
    data: [dynamic]u8,
}

width :: proc(img: Image) -> int {
    return img.w
}

height :: proc(img: Image) -> int {
    return img.h
}

TGA_Header :: struct #packed {
    idlength:         u8,
    colormaptype:     u8,
    datatypecode:     u8,
    colormaporigin:   u16,
    colormaplength:   u16,
    colormapdepth:    u8,
    x_origin:         u16,
    y_origin:         u16,
    width:            u16,
    height:           u16,
    bitsperpixel:     u8,
    imagedescriptor:  u8,
}

make_image :: proc(w, h: int, bpp: Format, clear: Color = {}) -> Image {
    out := Image{w = w, h = h, bpp = u8(bpp)}
    count := w * h * int(out.bpp)
    if count > 0 {
        out.data = make([dynamic]u8, count)
    }

    for y in 0..<h {
        for x in 0..<w {
            set_pixel(&out, x, y, clear)
        }
    }
    return out
}

set_pixel :: proc(img: ^Image, x, y: int, c: Color) {
    if img == nil || x < 0 || y < 0 || x >= img.w || y >= img.h {
        return
    }
    base := (x + y*img.w) * int(img.bpp)
    for i in 0..<int(img.bpp) {
        img.data[base+i] = c.bgra[i]
    }
}

get_pixel :: proc(img: Image, x, y: int) -> Color {
    if x < 0 || y < 0 || x >= img.w || y >= img.h || len(img.data) == 0 {
        return Color{}
    }
    out := Color{bytespp = img.bpp}
    base := (x + y*img.w) * int(img.bpp)
    for i in 0..<int(img.bpp) {
        out.bgra[i] = img.data[base+i]
    }
    return out
}

flip_horizontally :: proc(img: ^Image) {
    if img == nil || img.w <= 1 || img.h <= 0 || img.bpp == 0 {
        return
    }
    bpp := int(img.bpp)
    for x in 0..<(img.w/2) {
        xr := img.w - 1 - x
        for y in 0..<img.h {
            l := (x + y*img.w) * bpp
            r := (xr + y*img.w) * bpp
            for b in 0..<bpp {
                tmp := img.data[l+b]
                img.data[l+b] = img.data[r+b]
                img.data[r+b] = tmp
            }
        }
    }
}

flip_vertically :: proc(img: ^Image) {
    if img == nil || img.h <= 1 || img.w <= 0 || img.bpp == 0 {
        return
    }
    bpp := int(img.bpp)
    for y in 0..<(img.h/2) {
        yr := img.h - 1 - y
        for x in 0..<img.w {
            t := (x + y*img.w) * bpp
            b := (x + yr*img.w) * bpp
            for c in 0..<bpp {
                tmp := img.data[t+c]
                img.data[t+c] = img.data[b+c]
                img.data[b+c] = tmp
            }
        }
    }
}

u16_le_at :: proc(buf: []u8, idx: int) -> u16 {
    return u16(buf[idx]) | (u16(buf[idx+1]) << 8)
}

set_u16_le :: proc(dst: ^[dynamic]u8, v: u16) {
    append(dst, u8(v & 0x00ff))
    append(dst, u8((v >> 8) & 0x00ff))
}

load_rle_data :: proc(img: ^Image, src: []u8, cursor: ^int) -> bool {
    pixelcount := img.w * img.h
    currentpixel := 0
    currentbyte := 0
    bpp := int(img.bpp)

    for currentpixel < pixelcount {
        if cursor^ >= len(src) {
            fmt.eprintln("an error occurred while reading the data")
            return false
        }
        chunkheader := src[cursor^]
        cursor^ += 1

        if chunkheader < 128 {
            count := int(chunkheader) + 1
            for _ in 0..<count {
                if cursor^+bpp > len(src) {
                    fmt.eprintln("an error occurred while reading the data")
                    return false
                }
                if currentbyte+bpp > len(img.data) {
                    fmt.eprintln("Too many pixels read")
                    return false
                }
                copy(img.data[currentbyte:currentbyte+bpp], src[cursor^:cursor^+bpp])
                cursor^ += bpp
                currentbyte += bpp
                currentpixel += 1
                if currentpixel > pixelcount {
                    fmt.eprintln("Too many pixels read")
                    return false
                }
            }
        } else {
            count := int(chunkheader - 127)
            if cursor^+bpp > len(src) {
                fmt.eprintln("an error occurred while reading the data")
                return false
            }
            color := src[cursor^:cursor^+bpp]
            cursor^ += bpp

            for _ in 0..<count {
                if currentbyte+bpp > len(img.data) {
                    fmt.eprintln("Too many pixels read")
                    return false
                }
                copy(img.data[currentbyte:currentbyte+bpp], color)
                currentbyte += bpp
                currentpixel += 1
                if currentpixel > pixelcount {
                    fmt.eprintln("Too many pixels read")
                    return false
                }
            }
        }
    }

    return true
}

unload_rle_data :: proc(img: Image, dst: ^[dynamic]u8) -> bool {
    max_chunk_length := 128
    npixels := img.w * img.h
    curpix := 0
    bpp := int(img.bpp)

    for curpix < npixels {
        chunkstart := curpix * bpp
        curbyte := curpix * bpp
        run_length := 1
        raw := true

        for curpix+run_length < npixels && run_length < max_chunk_length {
            succ_eq := true
            for t in 0..<bpp {
                if img.data[curbyte+t] != img.data[curbyte+t+bpp] {
                    succ_eq = false
                    break
                }
            }
            curbyte += bpp

            if run_length == 1 {
                raw = !succ_eq
            }
            if raw && succ_eq {
                run_length -= 1
                break
            }
            if !raw && !succ_eq {
                break
            }
            run_length += 1
        }

        curpix += run_length
        if raw {
            append(dst, u8(run_length-1))
            append(dst, ..img.data[chunkstart:chunkstart+run_length*bpp])
        } else {
            append(dst, u8(run_length+127))
            append(dst, ..img.data[chunkstart:chunkstart+bpp])
        }
    }

    return true
}

read_tga_file :: proc(img: ^Image, filename: string) -> bool {
    if img == nil {
        return false
    }

    bytes, ok := os.read_entire_file(filename)
    if !ok {
        fmt.eprintln("can't open file", filename)
        return false
    }
    defer delete(bytes)

    if len(bytes) < size_of(TGA_Header) {
        fmt.eprintln("an error occurred while reading the header")
        return false
    }

    h := TGA_Header{}
    h.idlength = bytes[0]
    h.colormaptype = bytes[1]
    h.datatypecode = bytes[2]
    h.colormaporigin = u16_le_at(bytes, 3)
    h.colormaplength = u16_le_at(bytes, 5)
    h.colormapdepth = bytes[7]
    h.x_origin = u16_le_at(bytes, 8)
    h.y_origin = u16_le_at(bytes, 10)
    h.width = u16_le_at(bytes, 12)
    h.height = u16_le_at(bytes, 14)
    h.bitsperpixel = bytes[16]
    h.imagedescriptor = bytes[17]

    img.w = int(h.width)
    img.h = int(h.height)
    img.bpp = h.bitsperpixel >> 3

    if img.w <= 0 || img.h <= 0 || (img.bpp != u8(Format.GRAYSCALE) && img.bpp != u8(Format.RGB) && img.bpp != u8(Format.RGBA)) {
        fmt.eprintln("bad bpp (or width/height) value")
        return false
    }

    nbytes := img.w * img.h * int(img.bpp)
    img.data = make([dynamic]u8, nbytes)

    cursor := int(size_of(TGA_Header)) + int(h.idlength)
    if cursor > len(bytes) {
        fmt.eprintln("an error occurred while reading the header")
        return false
    }

    if h.datatypecode == 2 || h.datatypecode == 3 {
        if cursor+nbytes > len(bytes) {
            fmt.eprintln("an error occurred while reading the data")
            return false
        }
        copy(img.data[:], bytes[cursor:cursor+nbytes])
    } else if h.datatypecode == 10 || h.datatypecode == 11 {
        if !load_rle_data(img, bytes, &cursor) {
            fmt.eprintln("an error occurred while reading the data")
            return false
        }
    } else {
        fmt.eprintln("unknown file format", h.datatypecode)
        return false
    }

    if (h.imagedescriptor & 0x20) == 0 {
        flip_vertically(img)
    }
    if (h.imagedescriptor & 0x10) != 0 {
        flip_horizontally(img)
    }

    fmt.eprintln(img.w, "x", img.h, "/", int(img.bpp)*8)
    return true
}

write_tga_file :: proc(img: Image, filename: string, vflip: bool = true, rle: bool = true) -> bool {
    if img.w <= 0 || img.h <= 0 || (img.bpp != u8(Format.GRAYSCALE) && img.bpp != u8(Format.RGB) && img.bpp != u8(Format.RGBA)) {
        return false
    }

    out := make([dynamic]u8, 0)
    defer delete(out)

    datatypecode := u8(0)
    if img.bpp == u8(Format.GRAYSCALE) {
        if rle {
            datatypecode = 11
        } else {
            datatypecode = 3
        }
    } else {
        if rle {
            datatypecode = 10
        } else {
            datatypecode = 2
        }
    }

    imagedescriptor := u8(0x20)
    if vflip {
        imagedescriptor = 0x00
    }

    append(&out, 0) // idlength
    append(&out, 0) // colormaptype
    append(&out, datatypecode)
    set_u16_le(&out, 0) // colormaporigin
    set_u16_le(&out, 0) // colormaplength
    append(&out, 0) // colormapdepth
    set_u16_le(&out, 0) // x_origin
    set_u16_le(&out, 0) // y_origin
    set_u16_le(&out, u16(img.w))
    set_u16_le(&out, u16(img.h))
    append(&out, img.bpp << 3)
    append(&out, imagedescriptor)

    if !rle {
        append(&out, ..img.data[:])
    } else {
        if !unload_rle_data(img, &out) {
            fmt.eprintln("can't dump the tga file")
            return false
        }
    }

    // developer area ref (4), extension area ref (4), TRUEVISION-XFILE footer (18)
    append(&out, 0, 0, 0, 0)
    append(&out, 0, 0, 0, 0)
    append(&out,
        u8('T'), u8('R'), u8('U'), u8('E'), u8('V'), u8('I'), u8('S'), u8('I'),
        u8('O'), u8('N'), u8('-'), u8('X'), u8('F'), u8('I'), u8('L'), u8('E'),
        u8('.'), 0,
    )

    if !os.write_entire_file(filename, out[:]) {
        fmt.eprintln("can't open file", filename)
        return false
    }

    return true
}
