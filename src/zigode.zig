const std = @import("std");
const testing = std.testing;

pub const NoParams = struct{};

const solver = @import("./solver.zig");
const newton = @import("./newton.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn probFunc(du: *[1] f32, _: *const[1]f32, _: f32, _:*NoParams) void {
    du[0] = 4.0; 
}

fn callback(s: solver.Solver(f32, 1), u: *const[1]f32, _:f32) void {
    if (u[0] > 40) {
        s.terminate();
    }
}


test "basic functionality" {
    var prob = newton.Newton(f32, 1, NoParams).init(probFunc, .{});
    const test_allocator = std.testing.allocator;
    var solv = prob.getSolver(test_allocator);

    var u: [1]f32 = .{0.0};
    var solution = try solv.solve(
        u, 0.0, 100.0, .{}
    );
    defer solution.deinit();
}
