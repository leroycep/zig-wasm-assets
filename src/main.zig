const std = @import("std");
const env = @import("./env.zig");

pub const log = env.log;
pub const panic = env.panic;

var gpa = std.heap.GeneralPurposeAllocator(.{.safety = false}){};
const allocator: *std.mem.Allocator = &gpa.allocator;//zee_alloc.ZeeAllocDefaults.wasm_allocator;

export fn malloc(bytes: usize) ?[*]u8 {
    const a = allocator.alloc(u8, bytes) catch {
        return null;
    };
    return a.ptr;
}

var loading_complete: bool = false;
var loading_frame: @Frame(load_text_files) = undefined;
var completed: bool = false;
var finished: bool = false;
export fn init() void {
    loading_frame = async load_text_files();
}

export fn update() void {
    if (finished) return;
    if (completed) {
        defer finished = true;

        var text_files = (nosuspend await loading_frame) catch |err| {
            std.log.err("Error loading text files: {}", .{err});
            return;
        };
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

fn load_text_files() !TextFiles {
    defer completed = true;

    var hello_fetch = async env.fetch("hello.txt");
    var world_fetch = async env.fetch("world.txt");

    return TextFiles{
        .hello = try await hello_fetch,
        .world = try await world_fetch,
    };
}

export fn reverse_file(js_promise_id: usize, str_ptr: [*]const u8, str_len: usize) void {
    const reverse_frame = allocator.create(@Frame(reverse_file_internal)) catch |err| {
        std.log.err("Couldn't allocate frame: {}", .{err});
        return;
    };
    reverse_frame.* = async reverse_file_internal(js_promise_id, str_ptr, str_len);
}

fn reverse_file_internal(js_promise_id: usize, str_ptr: [*]const u8, str_len: usize) void {
    var fetch_frame = async env.fetch(str_ptr[0..str_len]);

    const const_content = (await fetch_frame) catch |err| {
        env.reject_promise(js_promise_id, @errorToInt(err));
        return;
    };
    const content = std.mem.dupe(allocator, u8, const_content) catch |err| {
        env.reject_promise(js_promise_id, @errorToInt(err));
        return;
    };

    var i: usize = 0;
    while (i < content.len / 2) : (i += 1) {
        var tmp = content[content.len - (i + 1)];
        content[content.len - (i + 1)] = content[i];
        content[i] = tmp;
    }

    env.resolve_promise(js_promise_id, content.ptr, content.len);
}
