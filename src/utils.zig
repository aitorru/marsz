const std = @import("std");

pub fn nullTerminate(global_allocator: std.mem.Allocator, str: []const u8) ![*:0]const u8 {
    var result: [*:0]u8 = undefined;
    result = try global_allocator.allocSentinel(u8, str.len + 1, 0);
    @memcpy(result[0..str.len], str[0..]);
    result[str.len] = 0;
    return result;
}

pub fn copy_cstring_until_sentinel(global_allocator: std.mem.Allocator, destination: *[]u8, origin: *[*:0]const u8) !void {
    // TODO: This is a fever dream, I need to find a better way to do this. Arraylists?
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    // Temporal buffer to copy the string
    var buffer: [500]u8 = undefined;
    var filled: usize = 0;

    // Final result to finally allocate memory
    var result: []u8 = try allocator.alloc(u8, 500);

    var i: usize = 0;
    while (origin.*[i] != 0) : (i += 1) {
        if (filled == buffer.len - 1) {
            // Create a temporal buffer
            var tmpBuffer = try allocator.alloc(u8, i);
            @memcpy(tmpBuffer[0 .. i - filled], result[0 .. i - filled]);

            // Allocate more memory
            result = try allocator.alloc(u8, i);
            @memcpy(result[0 .. i - filled], tmpBuffer[0 .. i - filled]);
            @memcpy(result[i - filled .. i], buffer[0..filled]);
            buffer = undefined;
            filled = 0;
        }
        buffer[filled] = origin.*[i];
        filled += 1;
    }

    // If the buffer is not empty, allocate memory and copy the buffer
    if (filled != 0) {
        // Create a temporal buffer
        var tmpBuffer = try allocator.alloc(u8, i);
        @memcpy(tmpBuffer[0 .. i - filled], result[0 .. i - filled]);
        result = try allocator.alloc(u8, i);
        @memcpy(result[0 .. i - filled], tmpBuffer[0 .. i - filled]);
        @memcpy(result[i - filled .. i], buffer[0..filled]);
    }

    // Allocate with the global allocator and copy the temporal buffer
    destination.* = try global_allocator.alloc(u8, i);
    @memcpy(destination.*[0..], result[0..]);
}

pub fn concatenate_string(global_allocator: std.mem.Allocator, origin: *[][]u8, destination: *[]u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var intermediary_buffer: []u8 = "";
    for (origin.*) |str| {
        var buffer: []u8 = try allocator.alloc(u8, str.len + intermediary_buffer.len);

        @memcpy(buffer[0..intermediary_buffer.len], intermediary_buffer[0..]);
        @memcpy(buffer[intermediary_buffer.len..], str[0..]);

        intermediary_buffer = try allocator.alloc(u8, buffer.len);
        @memcpy(intermediary_buffer[0..], buffer[0..]);
    }

    destination.* = try global_allocator.alloc(u8, intermediary_buffer.len);
    @memcpy(destination.*[0..], intermediary_buffer[0..]);
}
