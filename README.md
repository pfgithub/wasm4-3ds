run wasm4 games on 3ds

building (macos-x86_64 only)

install:
- bun (https://bun.sh),
- zig (https://ziglang.org),
- node, npm (https://nodejs.org) (might not be necessary)
- wasm4 (https://wasm4.org) (`npm install --global wasm4` / `bun add --global wasm4`),
- devkitpro (`dkp-pacman -S 3ds-dev`)

1. add wasm files to `vendor/games/`
2. build and run: `bun build.js clean build -Dgame=GAMENAME -Dplatform=raylib -Drun`

# TODO

- more wasm4 support:
  - sound, ...
- improve plctfarmer performance
  - reduce image decompression. currently, four frame images are decompressed every frame.
    we can make this happen less often.
  - rain. currently rain is calculated like a shader by generating a random number at every pixel
    on the screen. we can render it the traditional way instead, as an overlay instead of a cpu shader.
  - benchmark. these are my guesses based on observed behaviour, but there might be other things
    that are issues.
- build every game into one file? wasm4 launcher with all the games in site/static/carts/
