pub const vec2f = @Vector(2, f32);
pub const vec3f = @Vector(3, f32);

pub const x = 0;
pub const y = 1;
pub const z = 2;
pub const w = 3;

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
    // @Vector(4, u8) / vec4c

    pub fn from(r: u8, g: u8, b: u8, a: u8) Color {
        return .{.r = r, .g = g, .b = b, .a = a};
    }
    pub fn toU32(color: Color) u32 {
        return @bitCast(color);
    }
};
