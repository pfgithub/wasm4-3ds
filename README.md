run wasm4 games on 3ds

1. put wasm file in vendor/plctfarmer.wasm
2. `zig build run` (devkitpro must be installed & must be on macos-x86_64)

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
