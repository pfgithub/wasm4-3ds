const std = @import("std");
const c = @cImport({
    @cInclude("game.h");
});
const build_options = @import("wasm4_options");
const wasm4_font = @import("wasm4_font");

const WasmEnv = struct {
    memory: c.wasm_rt_memory_t,
    disk_len: u32 = 0,
    disk: [1024]u8,
};

pub const title = build_options.title;

pub const Game = struct {
    env: WasmEnv,
    alloc: std.mem.Allocator,
    instance: c.w2c_game,

    pub fn init(alloc: std.mem.Allocator) !*Game {
        var game = try alloc.create(Game);
        game.* = .{
            .env = .{
                .memory = undefined,
                .disk_len = 0,
                .disk = undefined,
            },
            .alloc = alloc,
            .instance = undefined,
        };
        const env = &game.env;

        c.wasm_rt_allocate_memory(&env.memory, 1, 1, false);
        errdefer c.wasm_rt_free_memory(&env.memory);

        c.wasm2c_game_instantiate(&game.instance, @ptrCast(game));
        errdefer c.wasm2c_game_free(&game.instance);

        c.w2c_game_start(&game.instance);

        return game;
    }
    pub fn free(game: *Game) void {
        const env = &game.env;
        c.wasm2c_game_free(&game.instance);
        c.wasm_rt_free_memory(&env.memory);
        game.alloc.destroy(game);
    }

    pub const PadButtons = struct {
        btn_1: bool = false,
        btn_2: bool = false,
        up: bool = false,
        left: bool = false,
        down: bool = false,
        right: bool = false,
    };
    pub const FrameIn = struct {
        mouse_x: i16 = -1,
        mouse_y: i16 = -1,
        mouse_left: bool = false,
        mouse_right: bool = false,
        mouse_middle: bool = false,
        pads: [4]PadButtons,
        reset_button_pressed: bool = false,
    };

    pub fn update(game: *Game, frame: FrameIn) void {
        const env = &game.env;

        const mouse_x = frame.mouse_x;
        const mouse_y = frame.mouse_y;
        std.mem.writeIntLittle(i16, env.memory.data[0x1A..][0..2], mouse_x);
        std.mem.writeIntLittle(i16, env.memory.data[0x1C..][0..2], mouse_y);
        env.memory.data[0x1E] = 0
            | @as(u8, if(frame.mouse_left) 0b001 else 0)
            | @as(u8, if(frame.mouse_right) 0b010 else 0)
            | @as(u8, if(frame.mouse_middle) 0b100 else 0)
        ;

        const BUTTON_1: u8 = 0b00000001;
        const BUTTON_2: u8 = 0b00000010;
        const BUTTON_LEFT: u8 = 0b00010000;
        const BUTTON_RIGHT: u8 = 0b00100000;
        const BUTTON_UP: u8 = 0b01000000;
        const BUTTON_DOWN: u8 = 0b10000000;
        const NONE: u8 = 0;
        for(frame.pads, 0x16..) |pad, addr| {
            env.memory.data[addr] = 0
                | (if(pad.btn_1) BUTTON_1 else NONE)
                | (if(pad.btn_2) BUTTON_2 else NONE)
                | (if(pad.left) BUTTON_LEFT else NONE)
                | (if(pad.right) BUTTON_RIGHT else NONE)
                | (if(pad.up) BUTTON_UP else NONE)
                | (if(pad.down) BUTTON_DOWN else NONE)
            ;
        }

        if(frame.reset_button_pressed) {
            c.wasm2c_game_free(&game.instance);
            c.wasm2c_game_instantiate(&game.instance, @ptrCast(env));

            c.w2c_game_start(&game.instance);
        }

        const system_flags = env.memory.data[0x1F];
        const flag_preserve_framebuffer = (system_flags & 0b01) != 0;
        if(!flag_preserve_framebuffer) {
            const rendered_frame = env.memory.data[0xA0..][0..6400];
            for(rendered_frame) |*pixel| pixel.* = 0;
        }

        c.w2c_game_update(&game.instance);
    }
    pub fn render(game: *Game, input_data: anytype, comptime setPixel: fn(data: @TypeOf(input_data), x: usize, y: usize, r: u8, g: u8, b: u8) void) void {
        const env = &game.env;
        const rendered_frame = env.memory.data[0xA0..][0..6400];
        const rendered_palette: [4]u32 = .{
            std.mem.readIntLittle(u32, env.memory.data[0x04..][0..4]),
            std.mem.readIntLittle(u32, env.memory.data[0x08..][0..4]),
            std.mem.readIntLittle(u32, env.memory.data[0x0C..][0..4]),
            std.mem.readIntLittle(u32, env.memory.data[0x10..][0..4]),
        };

        for(0..160) |y| {
            for(0..160 / 4) |x| {
                const target_byte = rendered_frame[(y * 160 + x * 4) / 4];
                for(0..4) |seg| {
                    const target_bit = (target_byte >> @intCast(seg * 2)) & 0b11;
                    const target_color = rendered_palette[target_bit];

                    const r: u8 = @intCast((target_color >> 16) & 0xFF);
                    const g: u8 = @intCast((target_color >> 8 ) & 0xFF);
                    const b: u8 = @intCast((target_color >> 0 ) & 0xFF);
                    setPixel(input_data, x * 4 + seg, y, r, g, b);
                }
            }
        }
    }


    // pub const PALETTE: *[4]u32 = @intToPtr(*[4]u32, 0x04);
    // pub const DRAW_COLORS: *u16 = @intToPtr(*u16, 0x14);
    // pub const GAMEPAD1: *const Gamepad = @intToPtr(*const Gamepad, 0x16);
    // pub const GAMEPAD2: *const Gamepad = @intToPtr(*const Gamepad, 0x17);
    // pub const GAMEPAD3: *const Gamepad = @intToPtr(*const Gamepad, 0x18);
    // pub const GAMEPAD4: *const Gamepad = @intToPtr(*const Gamepad, 0x19);
    //
    // pub const SYSTEM_FLAGS: *SystemFlags = @intToPtr(*SystemFlags, 0x1f);
    // pub const FRAMEBUFFER: *[CANVAS_SIZE * CANVAS_SIZE / 4]u8 = @intToPtr(*[6400]u8, 0xA0);
    // pub const CANVAS_SIZE = 160;

    // we will support save/load via savestates, so these just have to save into memory along with
    // regular updating of the savestate

    export fn w2c_env_memory(game: *Game) *c.wasm_rt_memory_t {
        return &game.env.memory;
    }

    export fn w2c_env_diskr(game: *Game, dest_ptr: u32, size: u32) u32 {
        const env = &game.env;
        const read_count = @min(size, env.disk_len);
        for(0..read_count) |i| {
            if(env.memory.size < dest_ptr + i) unreachable;
            env.memory.data[dest_ptr + i] = env.disk[i];
        }
        return read_count;
    }

    export fn w2c_env_diskw(game: *Game, src_ptr: u32, size: u32) u32 {
        const env = &game.env;
        const write_count = @min(size, env.disk.len);
        for(0..write_count) |i| {
            if(env.memory.size < src_ptr + i) unreachable;
            env.disk[i] = env.memory.data[src_ptr + i];
        }
        env.disk_len = write_count;
        return write_count;
    }

    fn drawColors(game: *Game) u16 {
        return std.mem.readIntLittle(u16, game.env.memory.data[0x14..][0..2]);
    }

    export fn w2c_env_line(game: *Game, x1: u32, y1: u32, x2: u32, y2: u32) void {
        _ = game;
        std.log.info("TODO line {} {} {} {}", .{x1, y1, x2, y2});
    }

    export fn w2c_env_rect(game: *Game, x: u32, y: u32, w: u32, h: u32) void {
        _ = game;
        std.log.info("TODO rect {} {} {} {}", .{x, y, w, h});
    }

    fn writePixel(game: *Game, x: i32, y: i32, value: u2, draw_colors: u16) void {
        if(x >= 160 or y >= 160 or x < 0 or y < 0) return;

        const col_v = (draw_colors >> (@as(u4, value) * 4)) & 0xF;
        if(col_v == 0) return;
        const color: u2 = @intCast(col_v - 1);

        const frame = game.env.memory.data[0xA0..][0..6400];
        const target_index: u32 = @intCast(@divFloor((y * 160 + @divFloor(x * 4, 4)), 4));
        const seg = @mod(x, 4);
        const delete_mask: u8 = (@as(u8, 0b11) << @intCast(seg * 2));
        const write_mask: u8 = (@as(u8, color) << @intCast(seg * 2));

        frame[target_index] &= ~delete_mask;
        frame[target_index] |= write_mask;
    }
    fn applyTransformations(x: *i32, y: *i32, w: i32, h: i32, flip_x: bool, flip_y: bool, rotate_90: bool) void {
        if(flip_x) {
            x.* = w - x.* - 1;
        }
        if(flip_y) {
            y.* = h - y.* - 1;
        }
        if(rotate_90) {
            const xv = x.*;
            const yv = y.*;
            x.* = h - yv - 1;
            y.* = xv;
        }
    }
    export fn w2c_env_blit(game: *Game, image: u32, x: i32, y: i32, w: i32, h: i32, flags: u32) void {
        return w2c_env_blitSub(game, image, x, y, w, h, 0, 0, w, flags);
    }
    export fn w2c_env_blitSub(game: *Game, image: u32, x: i32, y: i32, w: i32, h: i32, src_x: i32, src_y: i32, stride: i32, flags: u32) void {
        const flag_2bpp = (flags & 0b0001) != 0;
        const flag_flip_x = (flags & 0b0010) != 0; // 2,3 => -2,3 | 2:8,3:8 => 5:8,3:8
        const flag_flip_y = (flags & 0b0100) != 0; // 2,3 => 2,-3 | 2:8,3:8 => 2,8:4:8
        const flag_rotate_90 = (flags & 0b1000) != 0; // x,y=>-y,x
        const mem = game.getMem();

        const draw_colors = game.drawColors();
        if(h < 0 or w < 0) unreachable;
        for(0..@intCast(h)) |oy| {
            for(0..@intCast(w)) |ox| {
                var tx: i32 = @intCast(ox);
                var ty: i32 = @intCast(oy);
                const sx = tx + src_x;
                const sy = ty + src_y;
                const target_bit_index: u32 = @intCast(sy * stride + sx);

                const value: u2 = if (flag_2bpp) blk: {
                    var target_byte_index = target_bit_index / 4;
                    const target_bit: u3 = @as(u3, @as(u3, @intCast(3 - (target_bit_index % 4))) * 2);
                    break :blk @intCast((mem[image + target_byte_index] >> target_bit) & 0b11);
                }else blk: {
                    const target_byte_index = target_bit_index / 8;
                    const target_bit: u3 = 7 - @as(u3, @intCast(target_bit_index % 8));
                    break :blk @intCast((mem[image + target_byte_index] >> target_bit) & 0b1);
                };

                applyTransformations(&tx, &ty, w, h, flag_flip_x, flag_flip_y, flag_rotate_90);
                game.writePixel(x + tx, y + ty, value, draw_colors);
            }
        }
    }

    fn getMem(game: *Game) []u8 {
        return game.env.memory.data[0..game.env.memory.size];
    }
    export fn w2c_env_textUtf8(game: *Game, str: u32, len: u32, x: u32, y: u32) void {
        const mem = game.getMem();
        std.log.info("TODO text \"{s}\" {} {}", .{mem[str..][0..len], x, y});
    }
    export fn w2c_env_text(game: *Game, str: u32, x: u32, y: u32) void {
        const env = &game.env;
        const len = std.mem.indexOfScalar(u8, env.memory.data[str..@intCast(env.memory.size)], 0) orelse return;
        w2c_env_textUtf8(game, str, @intCast(len), x, y);
    }
    export fn w2c_env_trace(game: *Game, str: u32) void {
        const env = &game.env;
        const len = std.mem.indexOfScalar(u8, env.memory.data[str..@intCast(env.memory.size)], 0) orelse return;
        const slice = env.memory.data[str..][0..len];
        std.log.scoped(.trace).info("{s}", .{slice});
    }

    export fn w2c_env_tone(game: *Game, frequency: u32, duration: u32, volume: u32, flags: u32) void {
        _ = game;
        std.log.info("TODO tone {} {} {} {}", .{frequency, duration, volume, flags});
    }

    export fn wasm_rt_is_initialized() bool {
        return true;
    }
    export fn wasm_rt_trap(trap: c.wasm_rt_trap_t) void {
        _ = trap;
        unreachable;
    }
    export fn wasm_rt_allocate_memory(memory: *c.wasm_rt_memory_t, initial_pages: u32, max_pages: u32, is64: bool) void {
        const alloc = std.heap.c_allocator;
        const data = alloc.alloc(u8, initial_pages * 65536) catch @panic("oom");
        // errdefer alloc.free(data);
        memory.* = .{
            .data = data.ptr,
            .pages = initial_pages,
            .max_pages = max_pages,
            .size = @intCast(data.len),
            .is64 = is64,
        };
    }
    export fn wasm_rt_free_memory(memory: *c.wasm_rt_memory_t) void {
        const alloc = std.heap.c_allocator;
        alloc.free(memory.data[0..@intCast(memory.size)]);
    }
    export fn wasm_rt_allocate_funcref_table(table: *c.wasm_rt_funcref_table_t, elements: u32, max_elements: u32) void {
        const alloc = std.heap.c_allocator;
        const data = alloc.alloc(c.wasm_rt_funcref_t, elements) catch @panic("oom");
        //errdefer alloc.free(data);
        table.* = .{
            .data = data.ptr,
            .size = elements,
            .max_size = max_elements,
        };
    }
    export fn wasm_rt_free_funcref_table(table: *c.wasm_rt_funcref_table_t) void {
        const alloc = std.heap.c_allocator;
        alloc.free(table.data[0..table.size]);
    }

    // in place of wasm-rt-impl.c:
    //
    // void wasm_rt_init(void);
    // bool wasm_rt_is_initialized(void);
    // void wasm_rt_free(void);
    // void wasm_rt_trap(wasm_rt_trap_t) __attribute__((noreturn));
    // const char* wasm_rt_strerror(wasm_rt_trap_t trap);
    // void wasm_rt_allocate_memory(wasm_rt_memory_t*, uint32_t initial_pages, uint32_t max_pages, bool is64);
    // uint32_t wasm_rt_grow_memory(wasm_rt_memory_t*, uint32_t pages);
    // void wasm_rt_free_memory(wasm_rt_memory_t*);
    // void wasm_rt_allocate_funcref_table(wasm_rt_table_t*, uint32_t elements, uint32_t max_elements);
    // void wasm_rt_allocate_externref_table(wasm_rt_externref_table_t*, uint32_t elements, uint32_t max_elements);
    // void wasm_rt_free_funcref_table(wasm_rt_table_t*);
    // void wasm_rt_free_externref_table(wasm_rt_table_t*);
    // uint32_t wasm_rt_call_stack_depth; /* on platforms that don't use the signal handler to detect exhaustion */


};
