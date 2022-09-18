const std = @import("std");
const solvers = @import("./solvers.zig");
const Solver = solvers.Solver;

pub fn Newton(comptime T: type, comptime N: usize, comptime P: type) type {
    return struct {
        const Self = @This();
        const SolverType = Solver(T, N, P);
        const U = SolverType.U;
        const ProbFn = solvers.ProbFnType(T, N, P);

        prob: *const ProbFn,
        params: P,

        pub fn init(comptime prob: *const ProbFn, params: P) Self {
            return .{ .prob = prob, .params = params };
        }

        pub fn solver(self: *Self, allocator: std.mem.Allocator) SolverType {
            return SolverType.init(self, Self.step, allocator);
        }

        pub fn step(self: *Self, solv: *SolverType) !void {
            const uprev = solv.uprev;

            var du: U = .{@as(T, 0.0)} ** N;
            self.prob(&du, &uprev, solv.t, &self.params);
            // update previous
            for (solv.u) |*u, i| {
                u.* = u.* + solv.dt * du[i];
            }
        }
    };
}
