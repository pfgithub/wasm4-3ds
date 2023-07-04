const c = @import("c");
const gfx = @import("gfx.zig");

export fn zig_update() void {
    gfx.rect(.{0, 0, 0}, gfx.screen_size_2f, .{.r = 255, .g = 0, .b = 255, .a = 255});
}

export fn zig_add(a: u32, b: u32) u32 {
    return a + b;
}

export fn main(_: c_int, _: [*]const u8) c_int {
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

    while(c.aptMainLoop()) : (i += 1) {
        c.hidScanInput();

        const k_down = c.hidKeysDown();
        if(k_down & c.KEY_START != 0) break;

		_ = c.printf("\x1b[1;1HSimple citro2d shapes example");
		_ = c.printf("\x1b[2;1HCPU:     %6.2f%%\x1b[K", c.C3D_GetProcessingTime()*6.0);
		_ = c.printf("\x1b[3;1HGPU:     %6.2f%%\x1b[K", c.C3D_GetDrawingTime()*6.0);
		_ = c.printf("\x1b[4;1HCmdBuf:  %6.2f%%\x1b[K", c.C3D_GetCmdBufUsage()*100.0);
		_ = c.printf("\x1b[5;1HNum:  %d\x1b[K", i);

		// Render the scene

		if(!c.C3D_FrameBegin(c.C3D_FRAME_SYNCDRAW)) @panic("frame start fail");
		c.C2D_TargetClear(top, clr_clear);
		c.c_C2D_SceneBegin(top);

		zig_update();

		c.C3D_FrameEnd(0);
    }

    return 0;
}

//export fn main(argc: c_int, argv: [*]const u8) c_int {
//    c.c_gfxInitDefault();
//    defer c.c_gfxExit();
//    c.c_initialize_c3d();
//    defer c.C3D_Fini();
//    c.c_initialize_c2d();
//    defer c.C2D_Fini();
//    c.c_prepare_c2d();
//    c.c_initialize_bottom_console();
//
//    while(gfx.mainLoop()) {
//        const input =
//    }
//}
//
