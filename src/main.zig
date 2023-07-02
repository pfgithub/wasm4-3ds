const c = @cImport({
    @cInclude("co.h");
});

export fn zig_add(a: u32, b: u32) u32 {
    return a + b;
}
