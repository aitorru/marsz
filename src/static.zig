const std = @import("std");

pub fn read_file(global_allocator: std.mem.Allocator, destination: *[]u8, comptime path: []const u8, comptime delimiter: u8) void {
    if (destination.*.len == 0) {
        // Open the index file
        var file = std.fs.cwd().openFile(path, .{}) catch return;
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        // Reader buffer
        var file_buffer: [5000]u8 = undefined;

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var allocator = arena.allocator();

        var resulting_line: []u8 = "";
        var resulting_line_copy: []u8 = "";

        // TODO: readUntilDelimiterOrEof is depecrated. Use streamUntilDelimiter instead.
        while (in_stream.readUntilDelimiterOrEof(&file_buffer, delimiter) catch return) |line| {
            resulting_line_copy = allocator.alloc(u8, resulting_line.len) catch return;

            std.mem.copy(u8, resulting_line_copy[0..], resulting_line[0..]);

            resulting_line = allocator.alloc(u8, resulting_line.len + line.len) catch return;

            std.mem.copy(u8, resulting_line[0..], resulting_line_copy[0..]);
            std.mem.copy(u8, resulting_line[resulting_line_copy.len..], line[0..]);
        }

        destination.* = global_allocator.alloc(u8, resulting_line.len) catch return;
        std.mem.copy(u8, destination.*[0..], resulting_line[0..]);
    }
}
