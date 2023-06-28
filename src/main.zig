const std = @import("std");
const c = @cImport({
    @cInclude("citro2d.h");
});

extern fn main(argc: c_int, argv: [*][*]const c_int) callconv(.C) c_int {
    // Init libs
    c.gfxInitDefault();
    defer c.gfxExit();
    c.C3D_Init(c.C3D_DEFAULT_CMDBUF_SIZE);
    defer c.C3D_Fini();
    c.C2D_Init(c.C2D_DEFAULT_MAX_OBJECTS);
    defer c.C2D_Fini();
    c.C2D_Prepare();
    c.consoleInit(c.GFX_BOTTOM, null);

    // Create screens
    const top: *c.C3D_RenderTarget = c.C2D_CreateScreenTarget(c.GFX_TOP, c.GFX_LEFT);

    // Create colors
    const clrWhite: u32 = c.C2D_Color32(0xFF, 0xFF, 0xFF, 0xFF);
    const clrGreen: u32 = c.C2D_Color32(0x00, 0xFF, 0x00, 0xFF);
    const clrRed: u32 = c.C2D_Color32(0xFF, 0x00, 0x00, 0xFF);
    const clrBlue: u32 = c.C2D_Color32(0x00, 0x00, 0xFF, 0xFF);

    const clrCircle1: u32 = c.C2D_Color32(0xFF, 0x00, 0xFF, 0xFF);
	const clrCircle2: u32 = c.C2D_Color32(0xFF, 0xFF, 0x00, 0xFF);
	const clrCircle3: u32 = c.C2D_Color32(0x00, 0xFF, 0xFF, 0xFF);

	const clrSolidCircle: u32 = c.C2D_Color32(0x68, 0xB0, 0xD8, 0xFF);

	const clrTri1: u32 = c.C2D_Color32(0xFF, 0x15, 0x00, 0xFF);
	const clrTri2: u32 = c.C2D_Color32(0x27, 0x69, 0xE5, 0xFF);

	const clrRec1: u32 = c.C2D_Color32(0x9A, 0x6C, 0xB9, 0xFF);
	const clrRec2: u32 = c.C2D_Color32(0xFF, 0xFF, 0x2C, 0xFF);
	const clrRec3: u32 = c.C2D_Color32(0xD8, 0xF6, 0x0F, 0xFF);
	const clrRec4: u32 = c.C2D_Color32(0x40, 0xEA, 0x87, 0xFF);

	const clrClear: u32 = c.C2D_Color32(0xFF, 0xD8, 0xB0, 0x68);

    // Main loop
    while(c.aptMainLoop() != 0) {
        c.hidScanInput();

        // Respond to user input
        const kDown = c.hidKeysDown();
        if(kDown & c.KEY_START) {
            break; // exit to menu
        }
		c.printf("\x1b[1;1HSimple citro2d shapes example");
		c.printf("\x1b[2;1HCPU:     %6.2f%%\x1b[K", c.C3D_GetProcessingTime()*6.0);
		c.printf("\x1b[3;1HGPU:     %6.2f%%\x1b[K", c.C3D_GetDrawingTime()*6.0);
		c.printf("\x1b[4;1HCmdBuf:  %6.2f%%\x1b[K", c.C3D_GetCmdBufUsage()*100.0);

		// Render the scene
		c.C3D_FrameBegin(c.C3D_FRAME_SYNCDRAW);
		c.C2D_TargetClear(top, clrClear);
		c.C2D_SceneBegin(top);

		c.C2D_DrawTriangle(50 / 2, c.SCREEN_HEIGHT - 50, clrWhite,
			0,  c.SCREEN_HEIGHT, clrTri1,
			50, c.SCREEN_HEIGHT, clrTri2, 0);
		c.C2D_DrawRectangle(c.SCREEN_WIDTH - 50, 0, 0, 50, 50, clrRec1, clrRec2, clrRec3, clrRec4);

		// Circles require a state change (an expensive operation) within citro2d's internals, so draw them last.
		// Although it is possible to draw them in the middle of drawing non-circular objects
		// (sprites, images, triangles, rectangles, etc.) this is not recommended. They should either
		// be drawn before all non-circular objects, or afterwards.
		// (or use c3d instead)
		c.C2D_DrawEllipse(0, 0, 0, c.SCREEN_WIDTH, c.SCREEN_HEIGHT, clrCircle1, clrCircle2, clrCircle3, clrWhite);
		c.C2D_DrawCircle(c.SCREEN_WIDTH / 2, c.SCREEN_HEIGHT / 2, 0, 50, clrCircle3, clrWhite, clrCircle1, clrCircle2);
		c.C2D_DrawCircle(25, 25, 0, 25,
			clrRed, clrBlue, clrGreen, clrWhite);
		c.C2D_DrawCircleSolid(c.SCREEN_WIDTH - 25, c.SCREEN_HEIGHT - 25, 0, 25, clrSolidCircle);
		c.C3D_FrameEnd(0);
    }

    return 0;
}
