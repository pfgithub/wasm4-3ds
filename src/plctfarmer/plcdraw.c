// /Users/pfg/Downloads/wabt-1.0.33/bin/wasm2c /Users/pfg/Downloads/plctfarmer.wasm > w4src_C.c
// (1.0.25) wasm2c cart.wasm -o cart.c
// (1.0.33) wasm2c cart.wasm -o cart.c // FAILS
// (1.0.25) wasm2c cart.wasm > cart.c
// (1.0.33) wasm2c cart.wasm > cart.c

// note: consider compiling w4 carts to c rather than including source code here
// - trouble: w4 uses volatile pointers rather than extern calls
// that way we can support multiple games
//
// w2c_i0 = 0u;
// w2c_i0 = i32_load8_u(Z_envZ_memory, (u64)(w2c_i0) + 22u);
//
// that's the load to read the gamepad at 0x16
// wasm4 uses lots of absolute memory addresses to read/write & our game
// doesn't store those in a table so they're scattered throughout source code
// we could hack i32_load8_u though
//
// OH WAIT
// perfect! we can pass a pointer to the memory
// so we allocate 64kb (wasm4 mem) & then define externs:
// Z_envZ_memory : wasm_rt_memory_t struct pointing to our allocated memory
// Z_envZ_textUtf8Z_viiii : fn(u32, u32, u32, u32)
// Z_envZ_diskrZ_iii : fn() :: we can implement savestates on start button press
// Z_envZ_rectZ_viiii :
// https://github.com/WebAssembly/wabt/blob/main/wasm2c/README.md
//
// also eventually if we could dynamic link, we could support converting .wasm carts
// to codegen'd .c libraries for 3ds in browser, but that seems complicated
//
// rendering: draw to top & bottom screen

// https://github.com/randomouscrap98/3ds_junkdraw/blob/master/source/main.c
// creates the gpu texture, copies 2bpp pixels (accounting for swizzling)
// https://github.com/devkitPro/tex3ds/blob/master/source/swizzle.cpp
