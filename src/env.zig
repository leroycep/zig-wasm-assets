const std = @import("std");

extern fn do_fetch(filename_ptr: [*]const u8, filename_len: usize, cb: *c_void, data_out: *[]u8) void;

pub fn fetch(file_name: []const u8) ![]const u8 {
    var data: []u8 = undefined;
    suspend do_fetch(file_name.ptr, file_name.len, @frame(), &data);
    return data;
}

export fn _finalize_fetch(cb_void: *c_void, data_out: *[]u8, buffer: [*]u8, len: usize) void {
    const cb = @ptrCast(anyframe, @alignCast(8, cb_void));
    data_out.* = buffer[0..len];
    resume cb;
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
