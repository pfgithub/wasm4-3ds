const w4 = @import("wasm4.zig");
const std = @import("std");

export fn start() void {}

const MiniScreenshot = struct {}; // 28x28, 2bpp
const FullSizeScreenshot = struct {
    screen: [6400]u8 = undefined,
    palette: [4]u32 = undefined,
};

const StartMenuSelection = enum{
    save_0,
    save_1,
    save_2,
    delete_save,
    exit,
    fn getSaveID(sms: StartMenuSelection) ?u2 {
        return switch(sms) {
            .save_0 => 0,
            .save_1 => 1,
            .save_2 => 2,
            else => null,
        };
    }
};
const StartMenu = struct {
    selection: StartMenuSelection = .save_0,
    clear_active: bool = false,
};
const PauseMenu = struct {
    selection: enum{continue_game, reset_game, save_game, save_and_exit} = .continue_game,
    screenshot: FullSizeScreenshot = .{},
};
const State = struct {
    screen: enum{
        start_menu,
        pause_menu,
        playing,
    } = .start_menu,
    start_menu: StartMenu = .{},
    pause_menu: PauseMenu = .{},
    save_slot: u2 = 3,
};

var state: State = .{};
var prev_controller: w4.Gamepad = .{};
export fn update() void {
    const controller = w4.GAMEPAD1.*;
    defer prev_controller = controller;

    if(state.screen == .playing) {
        state.screen = .pause_menu;
        state.pause_menu.selection = .continue_game;
        state.pause_menu.screenshot.palette = w4.PALETTE.*;
        state.pause_menu.screenshot.screen = w4.FRAMEBUFFER.*;
    }

    switch(state.screen) {
        .start_menu => {
            updateStartMenu();
        },
        .pause_menu => {
            updatePauseMenu();
        },
        .playing => unreachable,
    }
}

// we can manage serialization/deserialization of this metadata. host just
// has to save the file itself. eg we could say 'save: [128]u8, id: number' and it would
// combine them
const SlotStats = union(enum) {
    empty,
    created: struct {
        frames: u64,
        screenshot: MiniScreenshot,
    },
    comptime {
        if(@sizeOf(SlotStats) > META_SIZE) {
            @compileLog(@sizeOf(SlotStats));
            @compileError("SlotStats too big");
        }
    }
};
const slot_stats: [3]SlotStats = .{
    .{.created = .{
        .frames = 12940,
        .screenshot = .{},
    }},
    .empty,
    .empty,
};

// for palettes:
// - use the palette from the screenshot
// - sort by brightness
// - if there isn't enough contrast ratio, add another element
// alternatively:
// - sort by brightness
// - transform: 0 1 2 3 => 01:[0 0] 23:[1 1]
// - then we have two colors to ourself
// - or we can even have three if we do [0] [1 2] [3]
//   and then pick a contrasting color for 4

fn advanceEnum(val: anytype) @TypeOf(val) {
    const Ty = @TypeOf(val);
    var intval = @intFromEnum(val);
    intval +%= 1;
    intval %= @intCast(std.meta.fields(Ty).len);
    return @enumFromInt(intval);
}
fn devanceEnum(val: anytype) @TypeOf(val) {
    const Ty = @TypeOf(val);
    var intval = @intFromEnum(val);
    if(intval == 0) {
        intval = std.meta.fields(Ty).len - 1;
    }else{
        intval -= 1;
    }
    return @enumFromInt(intval);
}

var fmt_out: [1024]u8 = undefined;
fn fmt(comptime a: []const u8, b: anytype) []u8 {
    return std.fmt.bufPrint(&fmt_out, a, b) catch &fmt_out;
}

fn updateStartMenu() void {
    const controller = w4.GAMEPAD1.*;

    w4.PALETTE.* = .{0x000000, 0xFFFFFF, 0xAA0000, 0xFF0000};

    if((controller.button_up and !prev_controller.button_up) or
        (controller.button_left and !prev_controller.button_left)
    ) {
        state.start_menu.selection = devanceEnum(state.start_menu.selection);
    }
    if((controller.button_down and !prev_controller.button_down) or
        (controller.button_right and !prev_controller.button_right)
    ) {
        state.start_menu.selection = advanceEnum(state.start_menu.selection);
    }
    if(w4rt_pause_button_pressed()) {
        w4rt_set_exit();
        return;
    }

    for(&[_]StartMenuSelection{.save_0, .save_1, .save_2}) |save_slot| {
        const save_id = save_slot.getSaveID().?;
        const offset: i32 = @intCast(save_slot.getSaveID().?);
        w4.DRAW_COLORS.* = 0x21;
        w4.rect(.{10, 10 + offset * 40}, .{160 - 10 - 10, 40 - 10});

        const selected: bool = state.start_menu.selection == save_slot;
        if(selected) {
            w4.DRAW_COLORS.* = 0x0020;
            w4.rect(.{10 - 2, 10 - 2 + offset * 40}, .{160 - 10 - 10 + 4, 40 - 10 + 4});
        }

        const slot_val = &slot_stats[save_id];
        switch(slot_val.*) {
            .created => |*created| {
                w4.DRAW_COLORS.* = 0x0034;
                w4.rect(.{11, 11 + offset * 40}, .{28, 28});
                if(selected) {
                    w4.DRAW_COLORS.* = 0x0022;
                    w4.rect(.{10 + 25 + 4, 11 + offset * 40}, .{160 - 10 - 10 - 26 - 4, 11});
                    w4.DRAW_COLORS.* = 0x0001;
                }else{
                    w4.DRAW_COLORS.* = 0x0002;
                }
                w4.text(fmt("Slot {d}", .{offset + 1}), .{10 + 28 + 4, 13 + offset * 40});
                const minutes = created.frames / 60 / 60;
                w4.DRAW_COLORS.* = 0x0002;
                w4.text(fmt("{d} minute{s}", .{minutes, if(minutes == 1) "" else "s"}), .{10 + 28 + 4, 15 + 14 + offset * 40});
            },
            .empty => {
                const newgame = "- New Game -";
                if(false and selected) {
                    w4.DRAW_COLORS.* = 0x0022;
                    w4.rect(.{10 + 22, 19 + offset * 40}, .{newgame.len * 8 + 2, 8 + 2});
                    w4.DRAW_COLORS.* = 0x0001;
                }else{
                    w4.DRAW_COLORS.* = 0x0002;
                }
                w4.text(newgame, .{10 + 23, 20 + offset * 40});
            },
        }
    }

    w4.DRAW_COLORS.* = 0x21;
    w4.rect(.{10, 10 + 120}, .{75 - 10, 20});
    if(state.start_menu.selection == .delete_save) {
        w4.DRAW_COLORS.* = 0x20;
        w4.rect(.{10 - 2, 10 + 120 - 2}, .{75 - 10 + 4, 20 + 4});
    }
    w4.DRAW_COLORS.* = 0x02;
    w4.text("Clear", .{10 + 2 + 11, 10 + 120 + 2 + 4});

    w4.DRAW_COLORS.* = 0x21;
    w4.rect(.{75 + 10, 10 + 120}, .{75 - 10, 20});
    if(state.start_menu.selection == .exit) {
        w4.DRAW_COLORS.* = 0x20;
        w4.rect(.{75 + 10 - 2, 10 + 120 - 2}, .{75 - 10 + 4, 20 + 4});
    }
    w4.DRAW_COLORS.* = 0x02;
    w4.text("Exit", .{75 + 10 + 2 + 15, 10 + 120 + 2 + 4});

    if(controller.button_1 and !prev_controller.button_1) {
        switch(state.start_menu.selection) {
            .save_0, .save_1, .save_2 => |v| {
                if(state.start_menu.clear_active) {
                    // TODO clear confirm screen
                }else{
                    const save_slot = v.getSaveID().?;
                    state.save_slot = save_slot;
                    state.screen = .playing;
                    w4rt_load(save_slot);
                    w4rt_set_continue();
                    return;
                }
            },
            .delete_save => {
                state.start_menu.clear_active = !state.start_menu.clear_active;
            },
            .exit => {
                w4rt_set_exit();
                return;
            },
        }
    }
    if(controller.button_2 and !prev_controller.button_2) {
        if(state.start_menu.clear_active) {
            state.start_menu.clear_active = false;
        }
    }
}
fn updatePauseMenu() void {
    if(w4rt_pause_button_pressed()) {
        state.screen = .playing;
        w4rt_set_continue();
        return;
    }
}

const META_SIZE = 256;
extern fn w4rt_save(save_id: u32, meta_ptr: *[META_SIZE]u8) void;
extern fn w4rt_load(save_id: u32) void;
extern fn w4rt_delete(save_id: u32) void;
extern fn w4rt_getmeta(save_id: u32, meta_ptr: *[META_SIZE]u8) bool; // true = written, false = no save in slot
extern fn w4rt_reset() void;
extern fn w4rt_set_continue() void;
extern fn w4rt_set_exit() void;
extern fn w4rt_pause_button_pressed() bool;
