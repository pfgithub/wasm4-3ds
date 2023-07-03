#ifndef C_H_INCLUDED
#define C_H_INCLUDED

#include "zig.h"
#include <stdint.h>
#include <stdbool.h>
#include <3ds.h>

#ifdef C_H_IMPL

#include <citro2d.h>

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define BODY(x) x
#else
#define BODY(x) ;
#endif

zig_extern void c_rect(f32 x, f32 y, f32 z, f32 w, f32 h, u32 color) BODY({
    C2D_DrawRectangle(x, y, z, w, h, color, color, color, color);
})


#endif
