const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const w4 = @import("w4rt");

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.InitWindow(160 * 3 + 10 * 2, 160 * 3 + 10 * 2, w4.title);
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);

    var game = try w4.Game.init(alloc);
    defer game.free();

    var image_data = try alloc.create([160 * 160 * 3]u8);
    errdefer alloc.free(image_data);
    for(image_data) |*v| v.* = 0;

    const tex = ray.LoadTextureFromImage(.{
        .data = image_data,
        .width = 160,
        .height = 160,
        .mipmaps = 1,
        .format = ray.PIXELFORMAT_UNCOMPRESSED_R8G8B8,
    });
    defer ray.UnloadTexture(tex);

    while(!ray.WindowShouldClose()) {
        const sw = ray.GetScreenWidth();
        const sh = ray.GetScreenHeight();
        const max_axis = @min(sw, sh);
        var max_render_scale: c_int = 1;
        while(160 * (max_render_scale + 1) <= max_axis) {
            max_render_scale += 1;
        }
        const scale_factor = max_render_scale;
        const scale_factorf: f32 = @floatFromInt(max_render_scale);
        const padding_x = @divFloor(sw - (160 * scale_factor), 2);
        const padding_y = @divFloor(sh - (160 * scale_factor), 2);
        const padding_xf: f32 = @floatFromInt(padding_x);
        const padding_yf: f32 = @floatFromInt(padding_y);

        // pub const MOUSE: *const Mouse = @intToPtr(*const Mouse, 0x1a);
        // x: i16, y: i16, buttons: u8
        game.update(.{
            .mouse_x = std.math.lossyCast(i16, @divFloor(ray.GetMouseX() - padding_x, scale_factor)),
            .mouse_y = std.math.lossyCast(i16, @divFloor(ray.GetMouseY() - padding_y, scale_factor)),
            .mouse_left = ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT),
            .mouse_right = ray.IsMouseButtonDown(ray.MOUSE_BUTTON_RIGHT),
            .mouse_middle = ray.IsMouseButtonDown(ray.MOUSE_BUTTON_MIDDLE),
            .pads = .{
                .{
                    .btn_1 = ray.IsKeyDown(ray.KEY_X) or ray.IsKeyDown(ray.KEY_V) or ray.IsKeyDown(ray.KEY_SPACE) or ray.IsKeyDown(ray.KEY_RIGHT_SHIFT),
                    .btn_2 = ray.IsKeyDown(ray.KEY_Z) or ray.IsKeyDown(ray.KEY_C) or ray.IsKeyDown(ray.KEY_ENTER) or ray.IsKeyDown(ray.KEY_N),
                    .left = ray.IsKeyDown(ray.KEY_LEFT),
                    .right = ray.IsKeyDown(ray.KEY_RIGHT),
                    .up = ray.IsKeyDown(ray.KEY_UP),
                    .down = ray.IsKeyDown(ray.KEY_DOWN),
                },
                .{
                    .btn_1 = ray.IsKeyDown(ray.KEY_TAB) or ray.IsKeyDown(ray.KEY_LEFT_SHIFT),
                    .btn_2 = ray.IsKeyDown(ray.KEY_Q) or ray.IsKeyDown(ray.KEY_A),
                    .left = ray.IsKeyDown(ray.KEY_S),
                    .right = ray.IsKeyDown(ray.KEY_F),
                    .up = ray.IsKeyDown(ray.KEY_E),
                    .down = ray.IsKeyDown(ray.KEY_D),
                },
                .{},
                .{},
            },
            .reset_button_pressed = ray.IsKeyPressed(ray.KEY_R),
        });

        game.render(image_data, struct{fn f(image_data2: *[160*160*3]u8, x: usize, y: usize, r: u8, g: u8, b: u8) void {
            const v = y * 160 + x;
            image_data2[v * 3 + 0] = r;
            image_data2[v * 3 + 1] = g;
            image_data2[v * 3 + 2] = b;
        }}.f);
        ray.UpdateTexture(tex, image_data);

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(.{.r = 0, .g = 0, .b = 0, .a = 0});
        ray.DrawRectangleV(.{.x = padding_xf - 1, .y = padding_yf - 1}, .{.x = 160 * scale_factorf + 2, .y = 160 * scale_factorf + 2}, .{.r = 255, .g = 255, .b = 255, .a = 255});
        ray.DrawTextureEx(tex, .{.x = padding_xf, .y = padding_yf}, 0, scale_factorf, .{.r = 255, .g = 255, .b = 255, .a = 255});

        ray.DrawFPS(0, 0);
    }
}
