const w4 = @This();
const std = @import("std");

/// PLATFORM CONSTANTS
pub const CANVAS_SIZE = 160;

/// Helpers
pub const Vec2 = @Vector(2, i32);
pub const x = 0;
pub const y = 1;

pub fn texLen(size: Vec2) usize {
    return @intCast(std.math.divCeil(i32, size[x] * size[y] * 2, 8) catch unreachable);
}

pub const Color = enum(u3) {
    black = 0,
    dark = 1,
    light = 2,
    white = 3,
    transparent = 4,
    pub fn fromInt(int: u2) Color {
        return @enumFromInt(int);
    }
};

pub const AnyTex = struct {
    data: *const anyopaque,
    get_fn: fn(data: *const anyopaque, pos: w4.Vec2) Color,
    pub fn get(tex: AnyTex, pos: w4.Vec2) Color {
        return tex.get_fn(tex.data, pos);
    }

    pub fn filter(tex: AnyTex, comptime filter_fn: anytype, data: FilterDataArg(filter_fn)) AutoFilter(filter_fn) {
        return AutoFilter(filter_fn).init(data, tex);
    }
};

// remap_colors: [4]u3, scale: Vec2

pub fn autoGetFn(comptime ff: anytype) fn(data: *const anyopaque, pos: w4.Vec2) Color {
    const ResTy = @typeInfo(@TypeOf(ff)).Fn.args[0].arg_type.?;
    return struct {
        fn f(v: *const anyopaque, pos: Vec2) Color {
            const ptr: *const ResTy = @ptrCast(@alignCast(v));
            return f(ptr.*, pos);
        }
    }.f;
}
pub fn autoAnyFn(comptime V: type) fn(tex: *const V) AnyTex {
    return struct {
        fn f(v: *const V) AnyTex {
            return .{
                .data = @ptrCast(v),
                .get_fn = autoGetFn(V.get),
            };
        }
    }.f;
}
// fn autoFilter(comptime fn: anytype)
// fn filterRemap(remap: [4]Color, tex: AnyTex, pos: w4.Vec2) Color {}
// pub const FilterRemap = autoFilter(filterRemap);
// tex.filter(FilterRemap, .{1, 2, 3, 4}).any();
// TODO ^that

pub const FilterRemap = AutoFilter(filterRemap);

pub fn FilterDataArg(comptime filter: anytype) type {
    return @typeInfo(@TypeOf(filter)).Fn.args[0].arg_type.?;
}
pub fn AutoFilter(comptime filter: anytype) type {
    const DataTy = FilterDataArg(filter);
    return struct {
        base: AnyTex,
        data: DataTy,
        pub fn get(v: @This(), pos: w4.Vec2) Color {
            return filter(v.data, v.base, pos);
        }
        pub const any = autoAnyFn(@This());

        pub fn init(data: DataTy, base: AnyTex) @This() {
            return .{
                .base = base,
                .data = data,
            };
        }
    };
}

pub fn filterRemap(remap: [4]Color, base: AnyTex, pos: w4.Vec2) Color {
    return remap[@intFromEnum(base.get(pos))];
}
pub fn filterTranslate(translate: Vec2, base: AnyTex, pos: w4.Vec2) Color {
    return base.get(pos + translate);
}
pub fn filterScale(scale: Vec2, base: AnyTex, pos: w4.Vec2) Color {
    return base.get(pos * scale);
}

pub const Mbl = enum { mut, cons };
pub fn Tex(comptime mbl: Mbl) type {
    return struct {
        // oh that's really annoying…
        // ideally there would be a way to have a readonly Tex and a mutable Tex
        // and the mutable should implicit cast to readonly
        data: switch (mbl) {
            .mut => [*]u8,
            .cons => [*]const u8,
        },
        size: Vec2,

        pub fn wrapSlice(slice: switch (mbl) {
            .mut => []u8,
            .cons => []const u8,
        }, size: Vec2) Tex(mbl) {
            if (slice.len != texLen(size)) {
                unreachable;
            }
            return .{
                .data = slice.ptr,
                .size = size,
            };
        }

        pub fn cons(tex: Tex(.mut)) Tex(.cons) {
            return .{
                .data = tex.data,
                .size = tex.size,
            };
        }

        pub const any = autoAnyFn(@This());

        // rather than including remap_colors and scale here,
        // make remapColors(tex: AnyTex, .{0, 1, 2, 3})
        // and scale(tex: AnyTex, .{2, 2})
        // that would be neat I think
        // measure to see how many more bytes of output this takes
        // and then we can also get rid of rect() and replace it with blit(solid(0b11))
        //
        // note: if AnyTex had a size, we could remove src_ul and src_wh from here
        pub fn blit(dest: Tex(.mut), dest_ul: Vec2, src: AnyTex, src_wh: Vec2) void {
            for (0..@intCast(src_wh[y])) |y_usz| {
                const yp: i32 = @intCast(y_usz);
                for (0..@intCast(src_wh[x])) |x_usz| {
                    const xp: i32 = @intCast(x_usz);
                    const pos = Vec2{ xp, yp };

                    dest.set(pos + dest_ul, src.get(pos));
                }
            }
        }
        /// consider removing this fn in favour of blit(solid(color))
        pub fn rect(dest: Tex(.mut), ul: Vec2, wh: Vec2, color: Color) void {
            for (0..std.math.lossyCast(usize, wh[y])) |y_usz| {
                const yp: i32 = @intCast(y_usz);
                for (0..std.math.lossyCast(usize, wh[x])) |x_usz| {
                    const xp: i32 = @intCast(x_usz);

                    dest.set(ul + Vec2{ xp, yp }, color);
                }
            }
        }
        pub fn get(tex: Tex(mbl), pos: Vec2) Color {
            if (@reduce(.Or, pos < w4.Vec2{ 0, 0 })) return .transparent;
            if (@reduce(.Or, pos >= tex.size)) return .transparent;
            const index_unscaled = pos[w4.x] + (pos[w4.y] * tex.size[w4.x]);
            const index: usize = @intCast(@divFloor(index_unscaled, 4));
            const byte_idx: u3 = @intCast((@mod(index_unscaled, 4)) * 2);
            return Color.fromInt(@truncate(tex.data[index] >> byte_idx));
        }
        pub fn set(tex: Tex(.mut), pos: Vec2, value_in: Color) void {
            const value_col: Color = if(@hasDecl(@import("root"), "globalValueRemap")) (
                @import("root").globalValueRemap(pos, value_in)
            ) else (
                value_in
            );
            if(value_col == .transparent) return;
            const value: u2 = @intCast(@intFromEnum(value_col));
            if (@reduce(.Or, pos < w4.Vec2{ 0, 0 })) return;
            if (@reduce(.Or, pos >= tex.size)) return;
            const index_unscaled = pos[w4.x] + (pos[w4.y] * tex.size[w4.x]);
            const index: usize = @intCast(@divFloor(index_unscaled, 4));
            const byte_idx: u3 = @intCast((@mod(index_unscaled, 4)) * 2);
            tex.data[index] &= ~(@as(u8, 0b11) << byte_idx);
            tex.data[index] |= @as(u8, value) << byte_idx;
        }
    };
}

pub fn range(len: usize) []const void {
    return @as([*]const void, &[_]void{})[0..len];
}

// pub const Tex1BPP = struct {…};

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Memory Addresses                                                          │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const PALETTE: *[4]u32 = @ptrFromInt(0x04);
pub const DRAW_COLORS: *u16 = @ptrFromInt(0x14);
pub const GAMEPAD1: *const Gamepad = @ptrFromInt(0x16);
pub const GAMEPAD2: *const Gamepad = @ptrFromInt(0x17);
pub const GAMEPAD3: *const Gamepad = @ptrFromInt(0x18);
pub const GAMEPAD4: *const Gamepad = @ptrFromInt(0x19);

pub const MOUSE: *const Mouse = @ptrFromInt(0x1a);
pub const SYSTEM_FLAGS: *SystemFlags = @ptrFromInt(0x1f);
pub const FRAMEBUFFER: *[CANVAS_SIZE * CANVAS_SIZE / 4]u8 = @ptrFromInt(0xA0); // [6400]u8
pub const ctx = Tex(.mut){
    .data = @ptrFromInt(0xA0), // apparently casting *[N]u8 to [*]u8 at comptime causes a compiler crash
    .size = .{ CANVAS_SIZE, CANVAS_SIZE },
};

pub const Gamepad = packed struct {
    button_1: bool = false,
    button_2: bool = false,
    _: u2 = 0,
    button_left: bool = false,
    button_right: bool = false,
    button_up: bool = false,
    button_down: bool = false,
    comptime {
        if (@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }

    pub fn format(value: @This(), comptime _: []const u8, _: @import("std").fmt.FormatOptions, writer: anytype) !void {
        if (value.button_1) try writer.writeAll("1");
        if (value.button_2) try writer.writeAll("2");
        if (value.button_left) try writer.writeAll("<"); //"←");
        if (value.button_right) try writer.writeAll(">");
        if (value.button_up) try writer.writeAll("^");
        if (value.button_down) try writer.writeAll("v");
    }
};

pub const Mouse = packed struct {
    x: i16 = 0,
    y: i16 = 0,
    buttons: MouseButtons = .{},
    pub fn pos(mouse: Mouse) Vec2 {
        return .{ mouse.x, mouse.y };
    }
    comptime {
        if (@sizeOf(@This()) != 5) unreachable;
    }
};

pub const MouseButtons = packed struct {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    _: u5 = 0,
    comptime {
        if (@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

pub const SystemFlags = packed struct {
    preserve_framebuffer: bool,
    hide_gamepad_overlay: bool,
    _: u6 = 0,
    comptime {
        if (@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

pub const SYSTEM_PRESERVE_FRAMEBUFFER: u8 = 1;
pub const SYSTEM_HIDE_GAMEPAD_OVERLAY: u8 = 2;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Drawing Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const externs = struct {
    pub extern fn blit(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, flags: u32) void;
    pub extern fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: i32, height: i32, src_x: i32, src_y: i32, strie: i32, flags: u32) void;
    pub extern fn line(x1: i32, y1: i32, x2: i32, y2: i32) void;
    pub extern fn oval(x: i32, y: i32, width: i32, height: i32) void;
    pub extern fn rect(x: i32, y: i32, width: i32, height: i32) void;
    pub extern fn textUtf8(strPtr: [*]const u8, strLen: usize, x: i32, y: i32) void;

    /// Draws a vertical line
    extern fn vline(x: i32, y: i32, len: u32) void;

    /// Draws a horizontal line
    extern fn hline(x: i32, y: i32, len: u32) void;

    pub extern fn tone(frequency: u32, duration: u32, volume: u32, flags: u32) void;
};

/// Copies pixels to the framebuffer.
pub fn blit(sprite: []const u8, pos: Vec2, size: Vec2, flags: BlitFlags) void {
    externs.blit(sprite.ptr, pos[x], pos[y], size[x], size[y], @bitCast(flags));
}

/// Copies a subregion within a larger sprite atlas to the framebuffer.
pub fn blitSub(sprite: []const u8, pos: Vec2, size: Vec2, src: Vec2, strie: i32, flags: BlitFlags) void {
    externs.blitSub(sprite.ptr, pos[x], pos[y], size[x], size[y], src[x], src[y], strie, @bitCast(flags));
}

pub const BlitFlags = packed struct {
    bpp: enum(u1) {
        b1,
        b2,
    },
    flip_x: bool = false,
    flip_y: bool = false,
    rotate: bool = false,
    _: u28 = 0,
    comptime {
        if (@sizeOf(@This()) != @sizeOf(u32)) unreachable;
    }
};

/// Draws a line between two points.
pub fn line(pos1: Vec2, pos2: Vec2) void {
    externs.line(pos1[x], pos1[y], pos2[x], pos2[y]);
}

/// Draws an oval (or circle).
pub fn oval(ul: Vec2, size: Vec2) void {
    externs.oval(ul[x], ul[y], size[x], size[y]);
}

/// Draws a rectangle.
pub fn rect(ul: Vec2, size: Vec2) void {
    externs.rect(ul[x], ul[y], size[x], size[y]);
}

/// Draws text using the built-in system font.
pub fn text(str: []const u8, pos: Vec2) void {
    externs.textUtf8(str.ptr, str.len, pos[x], pos[y]);
}

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Sound Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Plays a sound tone.
pub fn tone(frequency: ToneFrequency, duration: ToneDuration, volume: u32, flags: ToneFlags) void {
    return externs.tone(@bitCast(frequency), @bitCast(duration), volume, @bitCast(flags));
}
pub const ToneFrequency = packed struct {
    start: u16,
    end: u16 = 0,

    comptime {
        if (@sizeOf(@This()) != @sizeOf(u32)) unreachable;
    }
};

pub const ToneDuration = packed struct {
    sustain: u8 = 0,
    release: u8 = 0,
    decay: u8 = 0,
    attack: u8 = 0,

    comptime {
        if (@sizeOf(@This()) != @sizeOf(u32)) unreachable;
    }
};

pub const ToneFlags = packed struct {
    pub const Channel = enum(u2) {
        pulse1,
        pulse2,
        triangle,
        noise,
    };
    pub const Mode = enum(u2) {
        p12_5,
        p25,
        p50,
        p75,
    };

    channel: Channel,
    mode: Mode = .p12_5,
    _: u4 = 0,

    comptime {
        if (@sizeOf(@This()) != @sizeOf(u8)) unreachable;
    }
};

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Storage Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Reads up to `size` bytes from persistent storage into the pointer `dest`.
pub extern fn diskr(dest: [*]u8, size: u32) u32;

/// Writes up to `size` bytes from the pointer `src` into persistent storage.
pub extern fn diskw(src: [*]const u8, size: u32) u32;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Other Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Prints a message to the debug console.
/// Disabled in release builds.
pub fn trace(comptime fmt: []const u8, args: anytype) void {
    if(@import("builtin").mode != .Debug) @compileError("trace not allowed in release builds.");

    // stack size is [8192]u8
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();
    writer.print(fmt, args) catch {
        const err_msg = switch(@import("builtin").mode) {
            .Debug => "[trace err] "++fmt,
            else => "[trace err]", // max 100 bytes in trace message.
        };
        return traceUtf8(err_msg, err_msg.len);
    };

    traceUtf8(&buffer, fbs.pos);
}
extern fn traceUtf8(str_ptr: [*]const u8, str_len: usize) void;

/// Use with caution, as there's no compile-time type checking.
///
/// * %c, %d, and %x expect 32-bit integers.
/// * %f expects 64-bit floats.
/// * %s expects a *zero-terminated* string pointer.
///
/// See https://github.com/aduros/wasm4/issues/244 for discussion and type-safe
/// alternatives.
pub extern fn tracef(x: [*:0]const u8, ...) void;
