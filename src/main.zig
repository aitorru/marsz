const std = @import("std");
const fs = std.fs;
const static = @import("static.zig");
const utils = @import("utils.zig");
const zap = @import("zap");
const ArrayList = std.ArrayList;

extern fn start() void;
extern fn get_list_contents(u: [*]const u8, p: [*]const u8) [*:0]const u8;
extern fn decode_url(u: [*]const u8) [*:0]u8;
extern fn upload_new_link(n: [*]const u8, l: [*]const u8, u: [*]const u8, p: [*]const u8) bool;

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

const HeaderError = error{ HeaderNotFound, HeaderNotValid };

var styles_contents: []u8 = "";
fn return_styles(r: zap.SimpleRequest) void {
    static.read_file(global_allocator, &styles_contents, "deimos/_site/styles.css", '\n');
    r.setHeader("Content-type", "text/css") catch {
        r.sendError(HeaderError.HeaderNotValid, 500);
        return;
    };
    r.sendBody(styles_contents) catch return;
}

fn pong(r: zap.SimpleRequest) void {
    r.sendBody("pong") catch return;
}

fn calculate_fetch(r: zap.SimpleRequest) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var list = get_list_contents(username_secret_c, password_secret_c);
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

    var html_list: []u8 = undefined;
    defer allocator.free(html_list);
    var html_lists: [][]u8 = allocator.alloc([]u8, parser_json.len) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        r.sendError(ConvertError.AllocationError, 500);
        return;
    };

    for (parser_json, 0..) |item, index| {
        const template =
            \\<div class="bg-stone-100/10 rounded w-5/6 h-36 grid grid-cols-2 gap-3 p-5">
            \\ <div class="text-2xl text-white font-semibold">{s}</div>
            \\ <div class="col-span-2 text-sm text-white font-semibold">{s}</div>
            \\ <div class="grid-cols-2 grid gap-3">
            \\  <button class="bg-amber-400 rounded text-black font-semibold text-sm">Open</button>
            \\  <button class="bg-red-600 rounded text-black font-semibold text-sm">Delete</button>
            \\</div>
            \\</div>
        ;

        var buffer: [1024]u8 = undefined;

        const filled_buffer = std.fmt.bufPrintZ(&buffer, template, .{ item.name, item.link }) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            r.sendError(ConvertError.AllocationError, 500);
            return;
        };

        html_lists[index] = allocator.alloc(u8, filled_buffer.len) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            r.sendError(ConvertError.AllocationError, 500);
            return;
        };

        @memcpy(html_lists[index][0..filled_buffer.len], filled_buffer[0..]);
    }

    utils.concatenate_string(allocator, &html_lists, &html_list) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        r.sendError(ConvertError.AllocationError, 500);
        return;
    };

    r.sendBody(html_list) catch return;
}

const BodyParserPart = enum {
    Pre,
    Name,
    Divider,
    Link,
};

const UploadError = error{CouldNotUpload};

fn new_link(r: zap.SimpleRequest) void {
    const body = if (r.body) |b| b else return;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var part = BodyParserPart.Pre;

    var count: usize = 0;

    var name = ArrayList(u8).init(allocator);
    var link = ArrayList(u8).init(allocator);

    // TODO: This is a very naive parser, it should be improved
    for (body) |s| {
        switch (part) {
            BodyParserPart.Pre => {
                if (s == '=') {
                    part = BodyParserPart.Name;
                }
            },
            BodyParserPart.Name => {
                if (s == '&') {
                    part = BodyParserPart.Divider;
                } else {
                    // Only the name require the + to be replaced with a space
                    name.append(if (s == '+') ' ' else s) catch |err| {
                        std.debug.print("Error: {any}\n", .{err});
                        r.sendError(ConvertError.AllocationError, 500);
                        return;
                    };
                }
            },
            BodyParserPart.Divider => {
                if (s == '=') {
                    part = BodyParserPart.Link;
                    count = 0;
                }
            },
            BodyParserPart.Link => {
                if (s == ' ') {
                    break;
                } else {
                    link.append(s) catch |err| {
                        std.debug.print("Error: {any}\n", .{err});
                        r.sendError(ConvertError.AllocationError, 500);
                        return;
                    };
                }
            },
        }
    }
    // TODO: This needs cleaning up
    // Now decode the url
    var decoded_link_sentinel = decode_url(utils.nullTerminate(allocator, link.items) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        r.sendError(ConvertError.AllocationError, 500);
        return;
    });

    var dedoced_link: []u8 = undefined;

    utils.copy_cstring_until_sentinel(allocator, &dedoced_link, &decoded_link_sentinel) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        r.sendError(ConvertError.AllocationError, 500);
        return;
    };

    std.debug.print("Decoded link: {s}\n", .{dedoced_link});

    // Now upload the new link
    var upload_result = upload_new_link(
        utils.nullTerminate(allocator, name.items) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            r.sendError(ConvertError.AllocationError, 500);
            return;
        },
        utils.nullTerminate(allocator, dedoced_link) catch |err| {
            std.debug.print("Error: {any}\n", .{err});
            r.sendError(ConvertError.AllocationError, 500);
            return;
        },
        username_secret_c,
        password_secret_c,
    );

    if (upload_result) {
        std.debug.print("Uploaded new link\n", .{});
        r.sendBody("Ok") catch return;
    } else {
        std.debug.print("Failed to upload new link\n", .{});
        r.sendError(UploadError.CouldNotUpload, 500);
    }
}

fn delete_entry(r: zap.SimpleRequest) void {
    // TODO: Implement
    _ = r;
    unreachable;
}

fn setup_routes(a: std.mem.Allocator) !void {
    routes = std.StringHashMap(zap.SimpleHttpRequestFn).init(a);
    try routes.put("/", return_index);
    try routes.put("/index.html", return_index);
    try routes.put("/styles.css", return_styles);
    try routes.put("/fetch", calculate_fetch);
    try routes.put("/ping", pong);
    try routes.put("/new", new_link);
    try routes.put("/delete", delete_entry);
}

var routes: std.StringHashMap(zap.SimpleHttpRequestFn) = undefined;

var global_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var global_allocator = global_arena.allocator();

var username_secret: []u8 = undefined;
var username_secret_c: [*:0]const u8 = undefined;
var password_secret: []u8 = undefined;
var password_secret_c: [*:0]const u8 = undefined;

pub fn main() !void {
    // Read the credentials
    static.read_file(global_allocator, &username_secret, "secret_username", '\n');
    static.read_file(global_allocator, &password_secret, "secret_password", '\n');
    // Make they are null terminated
    username_secret_c = try utils.nullTerminate(global_allocator, username_secret);
    password_secret_c = try utils.nullTerminate(global_allocator, password_secret);
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
