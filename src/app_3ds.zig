const c = @import("c");
const std = @import("std");

const w4 = @import("w4rt");

export fn main(_: c_int, _: [*]const u8) c_int {
    app_main() catch @panic("error");
    return 0;
}

fn app_main() !void {
    const alloc = std.heap.c_allocator;

    c.gfxInitDefault();
    defer c.gfxExit();

    // if(!c.C3D_Init(c.C3D_DEFAULT_CMDBUF_SIZE)) @panic("3d init fail");
    // defer c.C3D_Fini();
    //
    // if(!c.C2D_Init(c.C2D_DEFAULT_MAX_OBJECTS)) @panic("3d init fail");
    // c.C2D_Prepare();
    // defer c.C2D_Fini();

    const console = c.consoleInit(c.GFX_TOP, null);
    _ = console;

    //const top: *c.C3D_RenderTarget = c.C2D_CreateScreenTarget(c.GFX_BOTTOM, c.GFX_BOTTOM) orelse @panic("create target fail");
    c.gfxSetDoubleBuffering(c.GFX_BOTTOM, true);

    const clr_clear: u32 = 0xFFD8B068;

    var i: u64 = 0;

    var game = try w4.Game.init(alloc);
    defer game.free();

    var image_data = try alloc.create([160 * 160 * 3]u8);
    defer alloc.free(image_data);
    for(image_data) |*v| v.* = 0;

    const left_offset = (360 - 160) / 2;
    const top_offset = (240 - 160) / 2;

    while(c.aptMainLoop()) : (i += 1) {
        c.hidScanInput();

        const k_down = c.hidKeysDown();
        const k_held = c.hidKeysHeld();

        var touch: c.touchPosition = undefined;
        c.hidTouchRead(&touch);

		//_ = c.printf("\x1b[1;1HSimple citro2d shapes example");
		//_ = c.printf("\x1b[2;1HCPU:     %6.2f%%\x1b[K", c.C3D_GetProcessingTime()*6.0);
		//_ = c.printf("\x1b[3;1HGPU:     %6.2f%%\x1b[K", c.C3D_GetDrawingTime()*6.0);
		//_ = c.printf("\x1b[4;1HCmdBuf:  %6.2f%%\x1b[K", c.C3D_GetCmdBufUsage()*100.0);
		//_ = c.printf("\x1b[5;1HNum:  %d\x1b[K", i);
        //std.log.info("Simple citro2d shapes example", .{});
        //const proc_time = @as(u32, @intFromFloat(c.C3D_GetProcessingTime()*6.0*100));
        //const draw_time = @as(u32, @intFromFloat(c.C3D_GetDrawingTime()*6.0*100));
        //const cmdbuf_usage = @as(u32, @intFromFloat(c.C3D_GetCmdBufUsage()*100.0*10));
        //std.log.info("CPU: {d}.{d:0>2}%", .{proc_time / 100, proc_time % 100});
        //std.log.info("GPU: {d}.{d:0>2}%", .{draw_time / 100, draw_time % 100});
        //std.log.info("CmdBuf: {d}.{d:0>2}%", .{cmdbuf_usage, cmdbuf_usage % 100});
        std.log.info("Frame: {d}", .{i});
        // if(k_held & c.KEY_TOUCH != 0) std.log.info("Touch: {d}, {d}", .{touch.px, touch.py});

		// Render the scene
		game.update(.{
            .mouse_x = std.math.lossyCast(i16, @as(i32, touch.px) - @as(i32, left_offset)),
            .mouse_y = std.math.lossyCast(i16, @as(i32, touch.py) - @as(i32, top_offset)),
            .mouse_left = (k_held & c.KEY_TOUCH != 0) and (k_held & c.KEY_L == 0) and (k_held & c.KEY_R == 0),
            .mouse_right = (k_held & c.KEY_TOUCH != 0) and (k_held & c.KEY_L != 0) and (k_held & c.KEY_R == 0),
            .mouse_middle = (k_held & c.KEY_TOUCH != 0) and (k_held & c.KEY_L == 0) and (k_held & c.KEY_R != 0),
            .pads = .{
                .{
                    .btn_1 = k_held & c.KEY_A != 0,
                    .btn_2 = k_held & c.KEY_B != 0,
                    .left = k_held & c.KEY_DLEFT != 0,
                    .right = k_held & c.KEY_DRIGHT != 0,
                    .up = k_held & c.KEY_DUP != 0,
                    .down = k_held & c.KEY_DDOWN != 0,
                },
                .{
                    .btn_1 = k_held & c.KEY_X != 0,
                    .btn_2 = k_held & c.KEY_Y != 0,
                    .left = k_held & c.KEY_CSTICK_LEFT != 0,
                    .right = k_held & c.KEY_CSTICK_RIGHT != 0,
                    .up = k_held & c.KEY_CSTICK_UP != 0,
                    .down = k_held & c.KEY_CSTICK_DOWN != 0,
                },
                .{},
                .{},
            },
            .pause_button_pressed = k_down & c.KEY_START != 0, // start : esc menu, one option will be 'reset'
        });
        if(game.should_exit) break;

		//if(!c.C3D_FrameBegin(c.C3D_FRAME_SYNCDRAW)) @panic("frame start fail");
		//c.C2D_TargetClear(top, clr_clear);
		//c.c_C2D_SceneBegin(top);

		//zig_update();

        _ = clr_clear;
        const top_fb = c.gfxGetFramebuffer(c.GFX_BOTTOM, c.GFX_BOTTOM, null, null); // 320*240*3
        game.render(top_fb, struct{fn f(top_fb2: [*c]u8, x: usize, y: usize, r: u8, g: u8, b: u8) void {
            // 320x240 (portrait)
            const height = 240;
            //const width = 320;
            const v = (height - (y + top_offset) - 1) + (x + left_offset) * height;
            //const fivesixfive = c.RGB565(r, g, b);
            top_fb2[v * 3 + 2] = r;
            top_fb2[v * 3 + 1] = g;
            top_fb2[v * 3 + 0] = b;
        }}.f);

		c.gfxFlushBuffers();
        c.c_gspWaitForVBlank();
        c.gfxSwapBuffers();

		//c.C3D_FrameEnd(0);
    }
}

pub const std_options = struct {
    // Set the log level to info
    // pub const log_level = .info; // logging lags so disable it in release
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
