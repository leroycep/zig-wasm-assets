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

//var main_task: @Frame(asyncMain) = undefined;
//pub fn main() anyerror!void {
//    main_task = async asyncMain();
//}

//var loader: Loader(TextFiles.load_text_files) = undefined;
var loading_complete: bool = false;
var loading_frame: @Frame(load_text_files) = undefined;
var text_files_opt: ?TextFiles = undefined;
var finished: bool = false;
export fn init() void {
    loading_frame = async load_text_files();
}

export fn update() void {
    if (finished) return;
    if (text_files_opt) |*text_files| {
        defer finished = true;

        //var text_files = nosuspend await loading_frame;
        defer text_files.deinit();

        std.log.info("contents of file: {s}", .{text_files.hello});
        std.log.info("contents of world file: {s}", .{text_files.world});
    }
}

const TextFiles = struct {
    hello: []const u8,
    world: []const u8,

    fn deinit(this: *@This()) void {
        allocator.free(this.hello);
        allocator.free(this.world);
    }
};

fn load_text_files() void {
    var hello_fetch = async env.fetch("hello.txt");
    var world_fetch = async env.fetch("world.txt");

    text_files_opt = TextFiles{
        .hello = await hello_fetch,
        .world = await world_fetch,
    };
}
