const std = @import("std");
const builtin = @import("builtin");

// try ofmt=c on zig code?

const emulator = "citra";
const flags = .{"-lcitro2d", "-lcitro3d", "-lctru", "-lm"};
const devkitpro = "/opt/devkitpro";
const c_files = .{
    "src/c.c",
    "src/main.c",
    "artifact/game.c",
};
//const zig_install_dir = "/Users/pfg/zig/0.11.0-dev.3905+309aacfc8/files/";

const include_dir_1 = devkitpro ++ "/libctru/include";
const include_dir_2 = devkitpro ++ "/portlibs/3ds/include";
const include_dir_3 = "src";
const include_dir_4 = "artifact";
const include_dir_5 = "vendor";

pub fn build(b: *std.build.Builder) void {
    // const optimize = b.standardOptimizeOption(.{});
    //
    // const obj = b.addObject(.{
    //     .name = "zig-3ds",
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = .{
    //         .cpu_arch = .arm,
    //         .os_tag = .freestanding,
    //         .abi = .eabihf,
    //         .cpu_model = .{ .explicit = &std.Target.arm.cpu.mpcore },
    //     },
    //     .optimize = optimize,
    // });
    // //obj.setOutputDir("zig-out");
    // obj.linkLibC();
    // obj.setLibCFile(std.build.FileSource{ .path = "libc.txt" });
    // obj.addIncludePath(include_dir_1);
    // obj.addIncludePath(include_dir_2);
    // obj.addIncludePath(include_dir_3);
    // obj.addIncludePath(include_dir_4);
    // obj.emit_h = true;

    // const insf = b.addInstallFile(.{.generated = &obj.output_path_source}, "zig-3ds.o");

    const insf4 = b.addSystemCommand(&.{
        "mkdir", "-p", "artifact",
    });

    const insf3 = b.addSystemCommand(&.{
        "vendor/wasm2c",
        "vendor/plctfarmer.wasm",
        "-o", "artifact/game.c",
    });
    insf3.step.dependOn(&insf4.step);

    const insf2 = b.addSystemCommand(&.{
        "zig", "build-exe", "src/main.zig",
        "-ofmt=c",
        "-target", "arm-freestanding-eabihf",
        "-mcpu=mpcore",
        "-I" ++ include_dir_1,
        "-I" ++ include_dir_2,
        "-I" ++ include_dir_3,
        "-I" ++ include_dir_4,
        "-I" ++ include_dir_5,
        "-lc",
        "--libc", "libc.txt",
        "-femit-bin=artifact/zigpart.c",
        "-femit-h=artifact/zigpart.h",
        "-OReleaseFast",
    });
    insf2.step.dependOn(&insf3.step);

    const insf = b.addSystemCommand(&.{
        "bun", "fix.js",
    });
    insf.step.dependOn(&insf2.step);

    //std.log.info("out_filename: {any}", .{obj.output_path_source});

    const extension = if (builtin.target.os.tag == .windows) ".exe" else "";
    const elf = b.addSystemCommand(&(.{
        devkitpro ++ "/devkitARM/bin/arm-none-eabi-gcc" ++ extension,
        "-g",
        "-march=armv6k",
        "-mtune=mpcore",
        "-mfloat-abi=hard",
        "-mtp=soft",
        //"-Wl,-Map,zig-out/zig-3ds.map",
        "-specs=" ++ devkitpro ++ "/devkitARM/arm-none-eabi/lib/3dsx.specs",
        // "zig-out/zig-3ds.o",
        "artifact/zigpart.c",
    } ++ c_files ++ .{
        "-I" ++ include_dir_1,
        "-I" ++ include_dir_2,
        "-I" ++ include_dir_3,
        "-I" ++ include_dir_4,
        "-I" ++ include_dir_5,
        "-I" ++ ".",
        //"-I" ++ zig_install_dir ++ "/lib",
        "-L" ++ devkitpro ++ "/libctru/lib",
        "-L" ++ devkitpro ++ "/portlibs/3ds/lib",
    } ++ flags ++ .{
        "-o", "artifact/zig-3ds.elf",
    }));

    const dsx = b.addSystemCommand(&.{
        devkitpro ++ "/tools/bin/3dsxtool" ++ extension,
        "artifact/zig-3ds.elf",
        "artifact/zig-3ds.3dsx",
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
