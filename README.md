# tinyrenderer (`odin version`)

This directory contains an Odin translation of [ssloy's tinyrenderer](https://github.com/ssloy/tinyrenderer) (software rasterizer).

The goal of this port is to mirror the original C++ pipeline and keep output parity while using idiomatic Odin modules.

## Project Layout

- `main.odin` - application entrypoint and Phong shader wiring
- `math/` - vector/matrix math (`geometry.h` equivalent)
- `image/` - TGA image loading/writing and pixel utilities (`tgaimage.*` equivalent)
- `model/` - OBJ parsing + texture loading (`model.*` equivalent)
- `rasterizer/` - camera transforms, z-buffer, triangle rasterization (`our_gl.*` equivalent)
- `obj/` - assets used by the renderer

## Features

- OBJ mesh loading (`v`, `vt`, `vn`, triangulated `f`)
- TGA texture support (raw and RLE)
- Perspective projection + viewport transform
- Barycentric triangle rasterization with z-buffer
- Tangent-space normal mapped Phong shading
- CPU parallelization in rasterization (OpenMP-style split on x-range)

## Run

From `odinversion/`:

```sh
odin run . -collection:tr=. -- ./obj/african_head/african_head.obj
```

Or render multiple models in one scene:

```sh
odin run . -collection:tr=. -- ./obj/diablo3_pose/diablo3_pose.obj ../tinyrenderer/obj/floor.obj
```

The renderer writes `framebuffer.tga` in the current directory.

## Verification

This port has been validated against the C++ reference renderer with hash-equal `framebuffer.tga` output on representative scenes.
