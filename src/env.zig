const std = @import("std");

extern fn do_fetch(filename_ptr: [*]const u8, filename_len: usize, cb: *c_void, data_out: *FetchError![]u8) void;

export const ERROR_NOT_FOUND: usize = @errorToInt(FetchError.NotFound);
export const ERROR_OUT_OF_MEMORY: usize = @errorToInt(FetchError.OutOfMemory);

const FetchError = error {
    NotFound,
    OutOfMemory,
};

pub fn fetch(file_name: []const u8) FetchError![]const u8 {
    var data: FetchError![]u8 = undefined;
    suspend do_fetch(file_name.ptr, file_name.len, @frame(), &data);
    return data;
}

export fn _finalize_fetch(cb_void: *c_void, data_out: *FetchError![]u8, buffer: [*]u8, len: usize) void {
    const cb = @ptrCast(anyframe, @alignCast(8, cb_void));
    data_out.* = buffer[0..len];
    resume cb;
}

export fn _fail_fetch(cb_void: *c_void, data_out: *FetchError![]u8, errno: std.meta.Int(.unsigned, @sizeOf(anyerror) * 8)) void {
    const cb = @ptrCast(anyframe, @alignCast(8, cb_void));
    data_out.* = switch (@intToError(errno)) {
        error.NotFound, error.OutOfMemory => |e| e,
        else => unreachable,
    };
    resume cb;
}

export fn error_name_ptr(errno: std.meta.Int(.unsigned, @sizeOf(anyerror) * 8)) [*]const u8 {
    return @errorName(@intToError(errno)).ptr;
}
export fn error_name_len(errno: std.meta.Int(.unsigned, @sizeOf(anyerror) * 8)) usize {
    return @errorName(@intToError(errno)).len;
}

extern fn console_log_write(str_ptr: [*]const u8, str_len: usize) void;
extern fn console_log_flush() void;

fn consoleLogWrite(context: void, bytes: []const u8) error{}!usize {
    console_log_write(bytes.ptr, bytes.len);
    return bytes.len;
}

fn consoleLogWriter() std.io.Writer(void, error{}, consoleLogWrite) {
    return .{ .context = {} };
}

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const writer = consoleLogWriter();
    defer console_log_flush();
    writer.print("[{s}][{s}] ", .{ std.meta.tagName(message_level), std.meta.tagName(scope) }) catch {};
    writer.print(format, args) catch {};
}

pub fn panic(msg: []const u8, stacktrace: ?*std.builtin.StackTrace) noreturn {
    console_log_write(msg.ptr, msg.len);
    console_log_flush();
    while (true) {
        @breakpoint();
    }
}

pub extern fn reject_promise(promise_id: usize, errorno: usize) void;
pub extern fn resolve_promise(promise_id: usize, ptr: [*]u8, len: usize) void;
