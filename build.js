const devkitpro = "/opt/devkitpro";
const include_dirs = [
  devkitpro + "/libctru/include",
  devkitpro + "/portlibs/3ds/include",
  "src",
  "artifact",
  "vendor",
];
const zig_flags = [
  "-target", "arm-freestanding-eabihf",
  "-mcpu=mpcore",
  ...include_dirs.map(id => "-I" + id),
  "-lc",
  "--libc", "libc.txt",
];
const c_files = [
  "src/c.c",
  // "src/main.c",
  "artifact/game.c",
];
const c_flags = ["-lcitro2d", "-lcitro3d", "-lctru", "-lm"];

async function clean() {
  await exec(["rm", "-rf", "artifact", "zig-cache"]);
}

async function main() {
  await exec(["mkdir", "-p", "artifact"]);
  await exec(["vendor/wasm2c", "vendor/plctfarmer.wasm", "-o", "artifact/game.c"]);

  let translate_c_res = await exec(["zig", "translate-c", "src/c.h", ...zig_flags]);
  translate_c_res = translate_c_res.replaceAll("@\"\"", "__INVALID_IDENTIFIER");
  translate_c_res = translate_c_res.replaceAll(`pub const struct_C3D_RenderTarget_tag = extern struct {
    next: ?*C3D_RenderTarget,
    prev: ?*C3D_RenderTarget,
    frameBuf: C3D_FrameBuf,
    used: bool,
    ownsColor: bool,
    ownsDepth: bool,
    linked: bool,
    screen: gfxScreen_t,
    side: gfx3dSide_t,
    transferFlags: @"u32",
};`, "pub const struct_C3D_RenderTarget_tag = opaque {};");
  await Bun.write("artifact/translate_c_res.zig", translate_c_res);

  await exec([
    "zig", "build-exe", "src/main.zig",
    "-ofmt=c",
    ...zig_flags,
    "-femit-bin=artifact/zigpart.c",
    "-femit-h=artifact/zigpart.h",
    "-OReleaseSafe",
    "--mod", "c::artifact/translate_c_res.zig",
    "--deps", "c",
    "-freference-trace",
  ]);

  let content = await Bun.file("artifact/zigpart.c").text();
  content = content.replaceAll("enum {\n};", "");
  await Bun.write("artifact/zigpart.c", content);

  await exec([
    devkitpro + "/devkitARM/bin/arm-none-eabi-gcc",
    "-g",
    "-march=armv6k",
    "-mtune=mpcore",
    "-mfloat-abi=hard",
    "-mtp=soft",
    "-specs=" + devkitpro + "/devkitARM/arm-none-eabi/lib/3dsx.specs",
    "artifact/zigpart.c",
    ...c_files,
    ...include_dirs.map(id => "-I" + id),
    "-L" + devkitpro + "/libctru/lib",
    "-L" + devkitpro + "/portlibs/3ds/lib",
    ...c_flags,
    "-o", "artifact/zig-3ds.elf",
  ]);

  await exec([
    devkitpro + "/tools/bin/3dsxtool",
    "artifact/zig-3ds.elf",
    "artifact/zig-3ds.3dsx",
  ]);

  // Bun.execSync(["vendor/wasm2c", "vendor/plctfarmer.wasm", "-o", "artifact/game.c"]);
}

async function exec(cmd) {
  const res = Bun.spawnSync(cmd, {stdio: ["inherit", "pipe", "inherit"]});
  if(res.exitCode !== 0) {
    console.log(cmd, res);
    process.exit(1);
  }
  return new TextDecoder().decode(res.stdout);
}

await main();
// await clean();
