const std = @import("std");
const testing = std.testing;

pub const NoParams = struct {};

const solver = @import("./solver.zig");
const newton = @import("./newton.zig");
const tsit5 = @import("./tsit5.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn probFunc(du: *[2]f64, _: *const [2]f64, _: f64, _: *NoParams) void {
    du[0] = 4.0;
}

fn callback(s: *solver.Solver(f64, 2), u: *const [2]f64, _: f64) void {
    if (u[0] > 40) {
        s.terminate();
    }
}

test "basic functionality" {
    var prob = newton.Newton(f64, 2, NoParams).init(probFunc, .{});
    const test_allocator = std.testing.allocator;
    var solv = prob.getSolver(test_allocator);

    var u: [2]f64 = .{ 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{});
    const stdout = std.io.getStdErr();
    try stdout.writeAll("\n");
    try sol.printInfo(stdout);
    defer sol.deinit();
}

test "basic tsit5 functionality" {
    var prob = tsit5.Tsit5(f64, 2, NoParams).init(probFunc, .{});
    const test_allocator = std.testing.allocator;
    var solv = prob.getSolver(test_allocator);

    var u: [2]f64 = .{ 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{ .callback = callback });
    const stdout = std.io.getStdErr();
    try stdout.writeAll("\n");
    try sol.printInfo(stdout);
    defer sol.deinit();
}
