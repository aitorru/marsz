const std = @import("std");

// pub fn nullTerminate(str: []const u8) ![]u8 {
//     var nullTermStr = try std.mem.dupe(u8, std.heap.page_allocator, str);
//     try nullTermStr.append(0); // Add null terminator
//     return nullTermStr;
// }

pub fn copy_cstring_until_sentinel(global_allocator: std.mem.Allocator, destination: *[]u8, origin: *[*:0]const u8) !void {
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
