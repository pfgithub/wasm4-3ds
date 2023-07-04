#ifndef C_H_INCLUDED
#define C_H_INCLUDED

#include "zig.h"
#include <stdint.h>
#include <stdbool.h>
#include <3ds.h>
#include <citro2d.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef C_H_IMPL

#define BODY(x) x
#else
#define BODY(x) ;
#endif

#define f32 float
#define u32 uint32_t

zig_extern void c_rect(f32 x, f32 y, f32 z, f32 w, f32 h, u32 color) BODY({
    C2D_DrawRectangle(x, y, z, w, h, color, color, color, color);
})

zig_extern void c_C2D_SceneBegin(C3D_RenderTarget* target) BODY({
    C2D_SceneBegin(target);
})

#endif
