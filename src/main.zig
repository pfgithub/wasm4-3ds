const c = @import("c");
const gfx = @import("gfx.zig");
const std = @import("std");

export fn zig_update() void {
    gfx.rect(.{0, 0, 0}, gfx.screen_size_2f, .{.r = 255, .g = 0, .b = 255, .a = 255});
}

export fn zig_add(a: u32, b: u32) u32 {
    return a + b;
}

const WasmEnv = struct {
    memory: c.wasm_rt_memory_t,
    disk_len: u32 = 0,
    disk: [1024]u8,
};

export fn main(_: c_int, _: [*]const u8) c_int {
    app_main() catch @panic("error");
    return 0;
}
fn app_main() !void {
    const alloc = std.heap.c_allocator;

    c.gfxInitDefault();
    defer c.gfxExit();

    if(!c.C3D_Init(c.C3D_DEFAULT_CMDBUF_SIZE)) @panic("3d init fail");
    defer c.C3D_Fini();

    if(!c.C2D_Init(c.C2D_DEFAULT_MAX_OBJECTS)) @panic("3d init fail");
    c.C2D_Prepare();
    defer c.C2D_Fini();

    const console = c.consoleInit(c.GFX_BOTTOM, null);
    _ = console;

    const top: *c.C3D_RenderTarget = c.C2D_CreateScreenTarget(c.GFX_TOP, c.GFX_LEFT) orelse @panic("create target fail");

    const clr_clear: u32 = 0xFFD8B068;

    var i: c_int = 0;

    c.wasm_rt_init();
    defer c.wasm_rt_free();

    var env: WasmEnv = .{
        .memory = undefined,
        .disk_len = 0,
        .disk = undefined,
    };

    c.wasm_rt_allocate_memory(&env.memory, 1, 1, false);
    defer c.wasm_rt_free_memory(&env.memory);

    var game: c.w2c_plctfarmer = undefined;
    c.wasm2c_plctfarmer_instantiate(&game, @ptrCast(&env));
    defer c.wasm2c_plctfarmer_free(&game);

    c.w2c_plctfarmer_start(&game);

    var image_data = try alloc.create([160 * 160 * 3]u8);
    defer alloc.free(image_data);
    for(image_data) |*v| v.* = 0;

    while(c.aptMainLoop()) : (i += 1) {
        c.hidScanInput();

        const k_down = c.hidKeysDown();
        if(k_down & c.KEY_START != 0) break;

		//_ = c.printf("\x1b[1;1HSimple citro2d shapes example");
		//_ = c.printf("\x1b[2;1HCPU:     %6.2f%%\x1b[K", c.C3D_GetProcessingTime()*6.0);
		//_ = c.printf("\x1b[3;1HGPU:     %6.2f%%\x1b[K", c.C3D_GetDrawingTime()*6.0);
		//_ = c.printf("\x1b[4;1HCmdBuf:  %6.2f%%\x1b[K", c.C3D_GetCmdBufUsage()*100.0);
		//_ = c.printf("\x1b[5;1HNum:  %d\x1b[K", i);
        std.log.info("Simple citro2d shapes example", .{});
        const proc_time = @as(u32, @intFromFloat(c.C3D_GetProcessingTime()*6.0*100));
        const draw_time = @as(u32, @intFromFloat(c.C3D_GetDrawingTime()*6.0*100));
        const cmdbuf_usage = @as(u32, @intFromFloat(c.C3D_GetCmdBufUsage()*100.0*10));

        std.log.info("CPU: {d}.{d:0>2}%", .{proc_time / 100, proc_time % 100});
        std.log.info("GPU: {d}.{d:0>2}%", .{draw_time / 100, draw_time % 100});
        std.log.info("CmdBuf: {d}.{d:0>2}%", .{cmdbuf_usage, cmdbuf_usage % 100});
        std.log.info("Num: {d}", .{i});

		// Render the scene

		if(!c.C3D_FrameBegin(c.C3D_FRAME_SYNCDRAW)) @panic("frame start fail");
		c.C2D_TargetClear(top, clr_clear);
		c.c_C2D_SceneBegin(top);

		zig_update();

		c.C3D_FrameEnd(0);
    }
}



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

var wasm_rt_is_initialized_val: bool = false;
export fn wasm_rt_init() void {
    wasm_rt_is_initialized_val = true;
}
export fn wasm_rt_is_initialized() bool {
    return wasm_rt_is_initialized_val;
}
export fn wasm_rt_free() void {
    wasm_rt_is_initialized_val = false;
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

pub const std_options = struct {
    // Set the log level to info
    //pub const log_level = .info;
    // Define logFn to override the std implementation
    pub const logFn = myLogFn;
};
pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime level.asText();
    const prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // TODO: printf(%s, message)
    var result: [1024]u8 = undefined;
    const result_slice = std.fmt.bufPrintZ(&result, level_txt ++ prefix ++ format ++ "\n", args) catch "too long";
    _ = c.printf("%s", result_slice.ptr);

    //std.debug.getStderrMutex().lock();
    //defer std.debug.getStderrMutex().unlock();
    //const stderr = std.io.getStdErr().writer();
    //nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}
