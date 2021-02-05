const std = @import("std");
const zee_alloc = @import("zee_alloc");
const env = @import("./env.zig");

pub const log = env.log;
pub const panic = env.panic;

const allocator: *std.mem.Allocator = zee_alloc.ZeeAllocDefaults.wasm_allocator;
comptime {
    (zee_alloc.ExportC{
        .allocator = allocator,
        .malloc = true,
        .free = true,
        .realloc = false,
        .calloc = false,
    }).run();
}

var main_task: @Frame(asyncMain) = undefined;
pub fn main() anyerror!void {
    main_task = async asyncMain();
}

pub fn asyncMain() anyerror!void {
    std.log.info("All your codebase are belong to us.", .{});

    var hello_fetch = async env.fetch("hello.txt");
    var world_fetch = async env.fetch("world.txt");

    const hello_contents = try await hello_fetch;
    defer allocator.free(hello_contents);
    const world_contents = try await world_fetch;
    defer allocator.free(world_contents);

    std.log.info("contents of file: {s}", .{hello_contents});
    std.log.info("contents of world file: {s}", .{world_contents});
}
