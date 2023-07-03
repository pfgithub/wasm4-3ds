const std = @import("std");
const builtin = @import("builtin");

const emulator = "citra";
const flags = .{"-lcitro2d", "-lcitro3d", "-lctru", "-lm"};
const devkitpro = "/opt/devkitpro";
const c_files = .{"src/c.c", "src/main.c"};
//const zig_install_dir = "/Users/pfg/zig/0.11.0-dev.3905+309aacfc8/files/";

pub fn build(b: *std.build.Builder) void {
    const optimize = b.standardOptimizeOption(.{});

    const obj = b.addObject(.{
        .name = "zig-3ds",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = .{
            .cpu_arch = .arm,
            .os_tag = .freestanding,
            .abi = .eabihf,
            .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
        },
        .optimize = optimize,
    });
    //obj.setOutputDir("zig-out");
    obj.linkLibC();
    obj.setLibCFile(std.build.FileSource{ .path = "libc.txt" });
    const include_dir_1 = devkitpro ++ "/libctru/include";
    const include_dir_2 = devkitpro ++ "/portlibs/3ds/include";
    const include_dir_3 = "src";
    obj.addIncludePath(include_dir_1);
    obj.addIncludePath(include_dir_2);
    obj.addIncludePath(include_dir_3);
    obj.emit_h = true;

    //std.log.info("out_filename: {any}", .{obj.output_path_source});

    const insf = b.addInstallFile(.{.generated = &obj.output_path_source}, "zig-3ds.o");

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = b.addSystemCommand(&(.{
        devkitpro ++ "/devkitARM/bin/arm-none-eabi-gcc" ++ extension,
        "-g",
        "-march=armv6k",
        "-mtune=mpcore",
        "-mfloat-abi=hard",
        "-mtp=soft",
        "-Wl,-Map,zig-out/zig-3ds.map",
        "-specs=" ++ devkitpro ++ "/devkitARM/arm-none-eabi/lib/3dsx.specs",
        "zig-out/zig-3ds.o",
    } ++ c_files ++ .{
        "-I" ++ include_dir_1,
        "-I" ++ include_dir_2,
        "-I" ++ include_dir_3,
        "-I" ++ ".",
        //"-I" ++ zig_install_dir ++ "/lib",
        "-L" ++ devkitpro ++ "/libctru/lib",
        "-L" ++ devkitpro ++ "/portlibs/3ds/lib",
    } ++ flags ++ .{
        "-o", "zig-out/zig-3ds.elf",
    }));

    const dsx = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/3dsxtool" ++ extension,
        "zig-out/zig-3ds.elf",
        "zig-out/zig-3ds.3dsx",
    });
    //dsx.stdout_action = .ignore;

    b.default_step.dependOn(&dsx.step);
    dsx.step.dependOn(&elf.step);
    elf.step.dependOn(&insf.step);

    const run_step = b.step("run", "Run in Citra");
    const citra = b.addSystemCommand(&.{ emulator, "zig-out/zig-3ds.3dsx" });
    run_step.dependOn(&dsx.step);
    run_step.dependOn(&citra.step);
}
