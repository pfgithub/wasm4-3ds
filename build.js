async function clean() {
  await exec(["rm", "-rf", "intermediate"]);
}
async function cleanAll() {
  await exec(["rm", "-rf", "artifact", "zig-cache", "zig-out"]);
}

const b = {
  option(name, values, default_value) {
    const val = b.flags.get(name);
    if(val == null) {
      if(default_value === undefined) {
        b.error("Expected -D"+name+" with one of:\n"+values.map(v => "-D"+name+"="+v).join("\n"));
      }
      return default_value;
    }
    if(Array.isArray(values)) {
      if(!values.includes(val)) {
        b.error("-D"+name+" expected one of:\n"+values.map(v => "-D"+name+"="+v).join("\n"));
      }
      return val;
    }
    return val;
  },
  error(msg) {
    console.error(msg);
    process.exit(1);
  },
  args: [],
  flags: new Map(),
};

async function main() {
  const build_mode = b.option("optimize", ["ReleaseFast", "ReleaseSafe", "ReleaseSmall", "Debug"], "Debug");
  const game = b.option("game", "string");
  const platform = b.option("platform", ["3ds", "raylib"]);
  const run = b.option("run", "string", false);

  const gamefile = "vendor/games/"+game+".wasm";

  await exec(["mkdir", "-p", "intermediate"]);
  await exec(["mkdir", "-p", "artifact"]);

  await Bun.write("intermediate/game.wasm", Bun.file(gamefile));

  await exec(["vendor/wasm2c", "intermediate/game.wasm", "-o", "intermediate/game.c"]);
  let gamecontent = await Bun.file("intermediate/game.c").text();
  gamecontent = gamecontent.replaceAll("WASM_RT_USE_STACK_DEPTH_COUNT", "false");
  await Bun.write("intermediate/game.c", gamecontent);

  await exec(["w4", "png2src", "src/w4rt/font.png", "--c", "-o", "intermediate/font.png"]);

  await Bun.write("intermediate/build_options.zig", "pub const title = "+JSON.stringify(game)+";");
  const mods = ["build_options"];
  const mod_flags = ["--mod", "build_options::intermediate/build_options.zig"];
  const all_zig_flags = [
    "-O"+build_mode,
    ...mod_flags,
  ];

  if(platform === "raylib") {
    const raylib_flags = await exec([
      "pkg-config", "raylib", "--cflags", "--libs",
    ]);
    const raylib_flags_split = raylib_flags.split(" ").map(f => f.trim());
    await exec([
      "zig", "build-exe", "src/app_raylib.zig",
      ...all_zig_flags,
      "-femit-bin=intermediate/game",
      ...raylib_flags_split,
      "-lc",
      "--deps", [...mods].join(","),
      "-I" + "intermediate",
      "-I" + "vendor",
      "intermediate/game.c",
      "-freference-trace",
    ]);

    const out_name = "artifact/"+game+"-native";
    await Bun.write(out_name, Bun.file("intermediate/game"));

    if(run !== false) {
      await exec([out_name, ...b.args]);
    }
  }else if(platform === "3ds") {
    const devkitpro = "/opt/devkitpro";
    const include_dirs = [
      devkitpro + "/libctru/include",
      devkitpro + "/portlibs/3ds/include",
      "src/app_3ds",
      "intermediate",
      "vendor",
    ];
    const zig_flags_3ds = [
      "-target", "arm-freestanding-eabihf",
      "-mcpu=mpcore",
      ...include_dirs.map(id => "-I" + id),
      "-lc",
      "--libc", "libc.txt",
    ];
    const c_files = [
      "src/app_3ds/c.c",
      "intermediate/game.c",
    ];
    const c_flags = ["-lcitro2d", "-lcitro3d", "-lctru", "-lm"];

    let translate_c_res = await exec([
      "zig", "translate-c", "src/app_3ds/all-translate.h",
      ...zig_flags_3ds,
    ]);
      translate_c_res = translate_c_res.replaceAll("@\"\"", "__INVALID_IDENTIFIER");
      translate_c_res = translate_c_res.replaceAll(""
        + "pub const struct_C3D_RenderTarget_tag = extern struct {\n"
        + "    next: ?*C3D_RenderTarget,\n"
        + "    prev: ?*C3D_RenderTarget,\n"
        + "    frameBuf: C3D_FrameBuf,\n"
        + "    used: bool,\n"
        + "    ownsColor: bool,\n"
        + "    ownsDepth: bool,\n"
        + "    linked: bool,\n"
        + "    screen: gfxScreen_t,\n"
        + "    side: gfx3dSide_t,\n"
        + "    transferFlags: @\"u32\",\n"
        + "};",
        "pub const struct_C3D_RenderTarget_tag = opaque {};",
      );
      await Bun.write("intermediate/translate_c_res.zig", translate_c_res);

    await exec([
      "zig", "build-exe", "src/app_3ds.zig",
      "-ofmt=c",
      ...zig_flags_3ds,
      ...all_zig_flags,
      "-femit-bin=intermediate/zigpart.c",
      "-femit-h=intermediate/zigpart.h",
      //"-OReleaseSafe",
      "--mod", "c::intermediate/translate_c_res.zig",
      "--deps", ["c", ...mods].join(","),
      "-freference-trace",
    ]);

    let content = await Bun.file("intermediate/zigpart.c").text();
    content = content.replaceAll("enum {\n};", "");
    await Bun.write("intermediate/zigpart.c", content);

    await exec([
      devkitpro + "/devkitARM/bin/arm-none-eabi-gcc",
      "-g",
      "-march=armv6k",
      "-mtune=mpcore",
      "-mfloat-abi=hard",
      "-mtp=soft",
      "-specs=" + devkitpro + "/devkitARM/arm-none-eabi/lib/3dsx.specs",
      "intermediate/zigpart.c",
      ...c_files,
      ...include_dirs.map(id => "-I" + id),
      "-L" + devkitpro + "/libctru/lib",
      "-L" + devkitpro + "/portlibs/3ds/lib",
      ...c_flags,
      "-o", "intermediate/game.elf",
      "-Wno-incompatible-pointer-types",
      "-Wno-builtin-declaration-mismatch",
      build_mode === "Debug" ? "" : "-O3",
    ]);

    await exec([
      devkitpro + "/tools/bin/3dsxtool",
      "intermediate/game.elf",
      "intermediate/game.3dsx",
    ]);

    await Bun.write("artifact/"+game+".3dsx", Bun.file("intermediate/game.3dsx"));
  }

  // Bun.execSync(["vendor/wasm2c", "vendor/plctfarmer.wasm", "-o", "intermediate/game.c"]);
}

async function exec(cmd) {
  const res = Bun.spawnSync(cmd, {stdio: ["inherit", "pipe", "inherit"]});
  if(res.exitCode !== 0) {
    console.log(cmd, res);
    process.exit(1);
  }
  return new TextDecoder().decode(res.stdout);
}

const args = process.argv.slice(2);
let cmd = [];
while(args.length) {
  const arg = args.shift();
  if(arg.startsWith("-")) {
    if(arg === "--") {
      b.args = args;
      break;
    }else if(arg.startsWith("-D")) {
      const namev = arg.substring(2);
      let namevs = namev.split("=");
      const n0 = namevs.shift();
      const n1 = namevs.join("=");
      b.flags.set(n0, n1);
    }else {
      console.error("bad arg: "+arg);
      process.exit(1);
    }
  }else{
    cmd.push(arg);
  }
}

if(!cmd.length) {
  console.error("No command specified");
  process.exit(1);
}
while(cmd.length) {
  const cmdv = cmd.shift();
  if(cmdv === "clean") {
    await clean();
  }else if(cmdv === "clean-all") {
    await clean();
    await cleanAll();
  } else if(cmdv === "build") {
    await main();
  }
}
