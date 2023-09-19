const std = @import("std");
const fs = std.fs;
const static = @import("static.zig");
const utils = @import("utils.zig");
const zap = @import("zap");

extern fn start() void;
extern fn get_list_contents(u: [*]const u8, p: [*]const u8) [*:0]const u8;

fn dispatch_routes(r: zap.SimpleRequest) void {
    // dispatch
    if (r.path) |the_path| {
        if (routes.get(the_path)) |handler| {
            handler(r);
            return;
        }
    }
    // or default: present index.html
    static.read_file(global_allocator, &index_contents, "deimos/_site/index.html", '\n');
    r.sendBody(index_contents) catch return;
}

const ConvertError = error{ AllocationError, CalcSizeUpperBoundError, DecodeError };

const Link = struct {
    name: []const u8,
    link: []const u8,
};

var index_contents: []u8 = "";
var index_list: []u8 = undefined;
fn return_index(r: zap.SimpleRequest) void {
    static.read_file(global_allocator, &index_contents, "deimos/_site/index.html", '\n');
    r.sendBody(index_contents) catch return;
}

var styles_contents: []u8 = "";
fn return_styles(r: zap.SimpleRequest) void {
    static.read_file(global_allocator, &styles_contents, "deimos/_site/styles.css", '\n');
    r.sendBody(styles_contents) catch return;
}

fn pong(r: zap.SimpleRequest) void {
    r.sendBody("pong") catch return;
}

fn calculate_fetch(r: zap.SimpleRequest) void {
    const allocator = std.heap.page_allocator;
    defer allocator.free(index_list);
    errdefer allocator.free(index_list);
    var list = get_list_contents(username_secret.ptr, password_secret.ptr);
    utils.copy_cstring_until_sentinel(allocator, &index_list, &list) catch {
        r.sendError(ConvertError.AllocationError, 500);
        return;
    };

    const options = std.json.ParseOptions{ .ignore_unknown_fields = true };

    const parser_json = std.json.parseFromSliceLeaky([]Link, global_allocator, index_list, options) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        r.sendError(ConvertError.DecodeError, 500);
        return;
    };
    _ = parser_json;
    r.sendBody(
        \\<div class="bg-stone-100/10 animate-pulse rounded w-5/6 h-36 grid grid-cols-2 gap-3 p-5">
        \\  <div class="bg-stone-100/40 animate-pulse rounded"></div>
        \\      <div class="col-span-2 bg-stone-100/40 animate-pulse rounded"></div>
        \\      <div class="grid-cols-2 grid gap-3">
        \\      <button class="bg-stone-100/40 animate-pulse rounded"></button>
        \\      <button class="bg-stone-100/40 animate-pulse rounded"></button>
        \\  </div>
        \\</div>
        \\<div class="bg-stone-100/10 animate-pulse rounded w-5/6 h-36 grid grid-cols-2 gap-3 p-5">
        \\  <div class="bg-stone-100/40 animate-pulse rounded"></div>
        \\      <div class="col-span-2 bg-stone-100/40 animate-pulse rounded"></div>
        \\      <div class="grid-cols-2 grid gap-3">
        \\      <button class="bg-stone-100/40 animate-pulse rounded"></button>
        \\      <button class="bg-stone-100/40 animate-pulse rounded"></button>
        \\  </div>
        \\</div>
    ) catch return;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.SimpleHttpRequestFn).init(a);
    try routes.put("/", return_index);
    try routes.put("/index.html", return_index);
    try routes.put("/styles.css", return_styles);
    try routes.put("/fetch", calculate_fetch);
    try routes.put("/ping", pong);
}

var routes: std.StringHashMap(zap.SimpleHttpRequestFn) = undefined;

var global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var global_allocator = global_arena.allocator();

var username_secret: []u8 = undefined;
var password_secret: []u8 = undefined;

pub fn main() !void {
    // Read the credentials
    static.read_file(global_allocator, &username_secret, "secret_username", '\n');
    static.read_file(global_allocator, &password_secret, "secret_password", '\n');
    // Make them null terminated
    // TODO: Fix this
    // username_secret = try utils.nullTerminate(username_secret);
    // password_secret = try utils.nullTerminate(password_secret);
    // Setup all the routes
    try setup_routes(std.heap.page_allocator);
    // Clean memory
    defer global_arena.deinit();
    var listener = zap.SimpleHttpListener.init(.{
        .port = 3000,
        .on_request = dispatch_routes,
        .log = true,
    });
    try listener.listen();

    start();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
