const c = @import("c.zig");
const math = @import("math.zig");

pub fn rect(pos: math.vec3f, size: math.vec2f, color: math.Color) void {
    c.c_rect(pos[math.x], pos[math.y], pos[math.z], size[math.x], size[math.y], color.toU32());
}

pub const screen_size_2f = math.vec2f{400, 240};
