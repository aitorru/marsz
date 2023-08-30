const std = @import("std");

extern fn start(c: bool) bool;

pub fn main() !void {
    std.debug.print("Hello from zig\n", .{});
    const result = start(false);
    std.debug.print("Result from rust: {any}\n", .{result});
}
