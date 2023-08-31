const std = @import("std");
const zap = @import("zap");

// TODO: It does not work.
extern fn start(c: bool) bool;

fn dispatch_routes(r: zap.SimpleRequest) void {
    // dispatch
    if (r.path) |the_path| {
        if (routes.get(the_path)) |handler| {
            handler(r);
            return;
        }
    }
    // or default: present menu
    r.sendBody(@embedFile("../deimos/_site/index.html")) catch return;
}
fn return_index(r: zap.SimpleRequest) void {
    r.sendBody(@embedFile("../deimos/_site/index.html"));
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
    try routes.put("/static", static_site);
    try routes.put("/dynamic", dynamic_site);
}

var routes: std.StringHashMap(zap.SimpleHttpRequestFn) = undefined;

pub fn main() !void {
    try setup_routes(std.heap.page_allocator);
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
