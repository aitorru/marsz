const std = @import("std");
const fs = std.fs;
const zap = @import("zap");

// TODO: It does not work.
extern fn start(c: bool) bool;
// extern fn formatString(c: []u8, args: []u8) []u8;

fn dispatch_routes(r: zap.SimpleRequest) void {
    // dispatch
    if (r.path) |the_path| {
        if (routes.get(the_path)) |handler| {
            handler(r);
            return;
        }
    }
    // or default: present menu
    r.sendBody("a") catch return;
}

var index_contents: []u8 = "";
fn return_index(r: zap.SimpleRequest) void {
    if (index_contents.len == 0) {
        // Open the index file
        var file = std.fs.cwd().openFile("deimos/_site/index.html", .{}) catch return;
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        // Reader buffer
        var file_buffer: [1024]u8 = undefined;

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var allocator = arena.allocator();

        var resulting_line: []u8 = "";
        var resulting_line_copy: []u8 = "";

        while (in_stream.readUntilDelimiterOrEof(&file_buffer, '\n') catch return) |line| {
            std.debug.print("{s}\n", .{line});
            resulting_line_copy = allocator.alloc(u8, resulting_line.len) catch return;

            std.mem.copy(u8, resulting_line_copy[0..], resulting_line[0..]);

            resulting_line = allocator.alloc(u8, resulting_line.len + line.len) catch return;

            std.mem.copy(u8, resulting_line[0..], resulting_line_copy[0..]);
            std.mem.copy(u8, resulting_line[resulting_line_copy.len..], line[0..]);

            std.debug.print("{s}\n", .{resulting_line});
        }

        index_contents = global_allocator.alloc(u8, resulting_line.len) catch return;
        std.mem.copy(u8, index_contents[0..], resulting_line[0..]);
    }
    std.debug.print("{s}\n", .{index_contents});
    std.debug.print("Is rust working?: {}\n", .{!start(false)});
    r.sendBody(index_contents) catch return;
}

var styles_contents: []u8 = "";
fn return_styles(r: zap.SimpleRequest) void {
    if (styles_contents.len == 0) {
        // Open the index file
        var file = std.fs.cwd().openFile("deimos/_site/styles.css", .{}) catch return;
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        // Reader buffer
        var file_buffer: [1024]u8 = undefined;

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var allocator = arena.allocator();

        var resulting_line: []u8 = "";
        var resulting_line_copy: []u8 = "";

        while (in_stream.readUntilDelimiterOrEof(&file_buffer, '\n') catch return) |line| {
            resulting_line_copy = allocator.alloc(u8, resulting_line.len) catch return;

            std.mem.copy(u8, resulting_line_copy[0..], resulting_line[0..]);

            resulting_line = allocator.alloc(u8, resulting_line.len + line.len) catch return;

            std.mem.copy(u8, resulting_line[0..], resulting_line_copy[0..]);
            std.mem.copy(u8, resulting_line[resulting_line_copy.len..], line[0..]);
        }

        styles_contents = global_allocator.alloc(u8, resulting_line.len) catch return;
        std.mem.copy(u8, styles_contents[0..], resulting_line[0..]);
    }
    r.sendBody(styles_contents) catch return;
}

fn static_site(r: zap.SimpleRequest) void {
    r.sendBody("<html><body><h1>Hello from STATIC ZAP!</h1></body></html>") catch return;
}

var dynamic_counter: i32 = 0;
fn dynamic_site(r: zap.SimpleRequest) void {
    dynamic_counter += 1;
    var buf: [128]u8 = undefined;
    const filled_buf = std.fmt.bufPrintZ(
        &buf,
        "<html><body><h1>Hello # {d} from DYNAMIC ZAP!!!</h1></body></html>",
        .{dynamic_counter},
    ) catch "ERROR";
    r.sendBody(filled_buf) catch return;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.SimpleHttpRequestFn).init(a);
    try routes.put("/", return_index);
    try routes.put("/styles.css", return_styles);
    try routes.put("/static", static_site);
    try routes.put("/dynamic", dynamic_site);
}

var routes: std.StringHashMap(zap.SimpleHttpRequestFn) = undefined;

var global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var global_allocator = global_arena.allocator();

pub fn main() !void {
    try setup_routes(std.heap.page_allocator);
    // Clean memory
    defer global_arena.deinit();
    var listener = zap.SimpleHttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
        .log = true,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
