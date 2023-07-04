const std = @import("std");
const c = @cImport({
    @cInclude("game.h");
});

const WasmEnv = struct {
    memory: c.wasm_rt_memory_t,
    disk_len: u32 = 0,
    disk: [1024]u8,
};

pub const Game = struct {
    env: WasmEnv,
    alloc: std.mem.Allocator,
    instance: c.w2c_plctfarmer,

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

        c.wasm2c_plctfarmer_instantiate(&game.instance, @ptrCast(env));
        errdefer c.wasm2c_plctfarmer_free(&game.instance);

        c.w2c_plctfarmer_start(&game.instance);

        return game;
    }
    pub fn free(game: *Game) void {
        const env = &game.env;
        c.wasm2c_plctfarmer_free(&game.instance);
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
            c.wasm2c_plctfarmer_free(&game.instance);
            c.wasm2c_plctfarmer_instantiate(&game.instance, @ptrCast(env));

            c.w2c_plctfarmer_start(&game.instance);
        }

        c.w2c_plctfarmer_update(&game.instance);
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

    export fn w2c_env_memory(env: *WasmEnv) *c.wasm_rt_memory_t {
        return &env.memory;
    }

    export fn w2c_env_diskr(env: *WasmEnv, dest_ptr: u32, size: u32) u32 {
        const read_count = @min(size, env.disk_len);
        for(0..read_count) |i| {
            if(env.memory.size < dest_ptr + i) unreachable;
            env.memory.data[dest_ptr + i] = env.disk[i];
        }
        return read_count;
    }

    export fn w2c_env_diskw(env: *WasmEnv, src_ptr: u32, size: u32) u32 {
        const write_count = @min(size, env.disk.len);
        for(0..write_count) |i| {
            if(env.memory.size < src_ptr + i) unreachable;
            env.disk[i] = env.memory.data[src_ptr + i];
        }
        env.disk_len = write_count;
        return write_count;
    }

    export fn w2c_env_line(env: *WasmEnv, x1: u32, y1: u32, x2: u32, y2: u32) void {
        _ = env;
        std.log.info("TODO line {} {} {} {}", .{x1, y1, x2, y2});
    }

    export fn w2c_env_rect(env: *WasmEnv, x: u32, y: u32, w: u32, h: u32) void {
        _ = env;
        std.log.info("TODO rect {} {} {} {}", .{x, y, w, h});
    }

    export fn w2c_env_textUtf8(env: *WasmEnv, str: u32, len: u32, x: u32, y: u32) void {
        if(env.memory.size < str + len) unreachable;
        std.log.info("TODO text \"{s}\" {} {}", .{env.memory.data[str..][0..len], x, y});
    }

    export fn w2c_env_tone(env: *c.struct_w2c_env, frequency: u32, duration: u32, volume: u32, flags: u32) void {
        _ = env;
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
