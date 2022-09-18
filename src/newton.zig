const std = @import("std");
const solver = @import("./solver.zig");
const Solver = solver.Solver;

pub fn Newton(comptime T: type, comptime N: usize, comptime P: type) type {
    return struct {
        const Self = @This();
        const SolverType = Solver(T, N);
        const U = SolverType.U;
        const ProbFn = solver.ProbFnType(T, N, P);

        prob: *const ProbFn,
        params: P,

        pub fn init(comptime prob: *const ProbFn, params: P) Self {
            return .{ .prob = prob, .params = params };
        }

        pub fn getSolver(self: *Self, allocator: std.mem.Allocator) SolverType {
            return SolverType.init(self, Self.step, allocator);
        }

        pub fn step(self: *Self, uprev: *U, t: T, dt: T) !void {
            var du: U = .{@as(T, 0.0)} ** N;
            self.prob(&du, uprev, t, &self.params);
            // update previous
            for (uprev) |*u, i| {
                u.* = u.* + dt * du[i];
            }
        }
    };
}
