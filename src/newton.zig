const std = @import("std");
const solver = @import("./solver.zig");
const Solver = solver.Solver;

pub fn Newton(comptime T: type, comptime N: usize, comptime P: type) type {
    return struct{
        const Self = @This();
        const SolverType = Solver(T,N);
        const U = SolverType.U;
        const ProbFn = fn(du: *U, u: *const U, t:T, p: *P) void;

        prob: *const ProbFn,
        params: P,

        pub fn init(comptime prob: *const ProbFn, params: P) Self {
            return .{.prob = prob, .params = params};
        }

        pub fn getSolver(self: *Self, allocator: std.mem.Allocator) SolverType {
            return SolverType.init(self, Self.step, allocator);
        }

        pub fn step(self: *Self, du: *U, u: *const U, _: T, t:T) !void {
            self.prob(du, u, t, &self.params);
        }
    };
}