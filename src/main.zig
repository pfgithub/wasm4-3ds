const gfx = @import("gfx.zig");

export fn zig_update() void {
    gfx.rect(.{0, 0, 0}, gfx.screen_size_2f, .{.r = 255, .g = 0, .b = 255, .a = 255});
}

export fn zig_add(a: u32, b: u32) u32 {
    return a + b;
}
