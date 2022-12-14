const std = @import("std");
const testing = std.testing;

const solver = @import("./solvers.zig");
const newton = @import("./newton.zig");
const tsit5 = @import("./tsit5.zig");
pub const Tsit5 = tsit5.Tsit5;
pub const AdaptiveTsit5 = tsit5.AdaptiveTsit5;
pub const Solver = solver.Solver;
pub const NoParams = struct { _: usize = 0 };

fn probFunc(du: *[2]f64, _: *const [2]f64, _: f64, _: *NoParams) void {
    du[0] = 4.0;
}

fn callback(s: *solver.Solver([2]f64, NoParams), u: *const [2]f64, _: f64, _: *NoParams) void {
    if (u[0] > 10) {
        s.terminate();
    }
}

fn lorenz(du: *[3]f64, u: *const [3]f64, _: f64, _: *NoParams) void {
    du[0] = 10.0 * (u[1] - u[0]);
    du[1] = u[0] * (28.0 - u[2]) - u[1];
    du[2] = u[0] * u[1] - (8.0 / 3.0) * u[2];
}

test "basic functionality" {
    var prob = newton.Newton(probFunc, NoParams).init(.{});
    const test_allocator = std.testing.allocator;
    var solv = prob.solver(test_allocator);

    var u: [2]f64 = .{ 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{});
    defer sol.deinit();
}

test "callbacks" {
    var prob = newton.Newton(probFunc, NoParams).init(.{});
    const test_allocator = std.testing.allocator;
    var solv = prob.solver(test_allocator);

    var u: [2]f64 = .{ 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{ .callback = callback });
    defer sol.deinit();
    try std.testing.expect(sol.u[sol.index - 1][0] < 10.0);
}

test "basic tsit5 functionality" {
    const test_allocator = std.testing.allocator;

    var prob = Tsit5(probFunc, NoParams).init(.{});
    var solv = prob.solver(test_allocator);

    var u: [2]f64 = .{ 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{ .save = true });
    defer sol.deinit();
    try std.testing.expectApproxEqRel(sol.t[sol.index - 1], 100.0, 1e-4);
}

test "basic tsit5 lorenz" {
    const test_allocator = std.testing.allocator;

    var prob = Tsit5(lorenz, NoParams).init(.{});
    var solv = prob.solver(test_allocator);

    var u: [3]f64 = .{ 1.0, 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{ .save = true, .dt = 1e-2 });
    defer sol.deinit();

    const stdout = std.io.getStdErr();
    try stdout.writeAll("\n");
    try sol.printInfo(stdout);

    var file = try std.fs.cwd().openFile("out.txt", .{ .mode = std.fs.File.OpenMode.write_only });
    defer file.close();

    for (sol.u) |*v| {
        try file.writer().print("{e}\n", .{v.*});
    }
}

test "adaptive tsit5 lorenz" {
    const test_allocator = std.testing.allocator;

    var prob = AdaptiveTsit5(lorenz, NoParams).init(.{});
    var solv = prob.solver(test_allocator);

    var u: [3]f64 = .{ 1.0, 0.0, 0.0 };
    var sol = try solv.solve(u, 0.0, 100.0, .{ .save = true, .dt = 1e-5 });
    defer sol.deinit();

    const stdout = std.io.getStdErr();
    try stdout.writeAll("\n");
    try sol.printInfo(stdout);

    var file = try std.fs.cwd().openFile("out2.txt", .{ .mode = std.fs.File.OpenMode.write_only });
    defer file.close();

    for (sol.u) |*v| {
        try file.writer().print("{e}\n", .{v.*});
    }
}

// // test "interpolated tsit5 functionality" {
// //     const test_allocator = std.testing.allocator;

// //     var prob = AdaptiveTsit5(f64, 2, NoParams).init(probFunc, .{});
// //     var solv = prob.solver(test_allocator);

// //     var u: [2]f64 = .{ 0.0, 0.0 };
// //     var sol = try solv.solve(u, 0.0, 100.0, .{ .interpolated_callback = callback, .save = true });

// //     const stdout = std.io.getStdErr();
// //     defer sol.deinit();
// //     try stdout.writeAll("\n");
// //     try sol.printInfo(stdout);
// // }
