const std = @import("std");
const fs = std.fs;
const static = @import("static.zig");
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
    // or default: present index.html
    static.read_file(global_allocator, &index_contents, "deimos/_site/index.html");
    r.sendBody(index_contents) catch return;
}

var index_contents: []u8 = "";
fn return_index(r: zap.SimpleRequest) void {
    static.read_file(global_allocator, &index_contents, "deimos/_site/index.html");
    r.sendBody(index_contents) catch return;
}

var styles_contents: []u8 = "";
fn return_styles(r: zap.SimpleRequest) void {
    static.read_file(global_allocator, &styles_contents, "deimos/_site/styles.css");
    r.sendBody(styles_contents) catch return;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.SimpleHttpRequestFn).init(a);
    try routes.put("/", return_index);
    try routes.put("/index.html", return_index);
    try routes.put("/styles.css", return_styles);
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
