const std = @import("std");
const solvers = @import("./solvers.zig");
const meta = @import("./meta.zig");
const InferSolver = solvers.InferSolver;

fn getChildType(comptime Pointer: type) type {
    switch (@typeInfo(Pointer)) {
        .Pointer => |p| return p.child,
        else => @compileError("Could not determine child type of pointer."),
    }
}

fn getSliceInfo(comptime Slice: type) std.builtin.Type.Array {
    switch (@typeInfo(Slice)) {
        .Array => |a| {
            return a;
        },
        else => @compileError("Could not infer info about slice."),
    }
}

fn getSliceInfoFromPointer(comptime Pointer: type) std.builtin.Type.Array {
    const Child = getChildType(Pointer);
    return getSliceInfo(Child);
}

// fn getSliceType()

pub fn Newton(comptime prob_function: anytype, comptime P: type) type {
    return struct {
        const Self = @This();
        const SolverType = InferSolver(prob_function, P);
        const T = SolverType.T;
        const N = SolverType.N;
        const U = SolverType.U;

        params: P,

        pub fn init(params: P) Self {
            return .{ .params = params };
        }

        pub fn solver(self: *Self, allocator: std.mem.Allocator) SolverType {
            return SolverType.init(self, Self.step, allocator);
        }

        pub fn step(self: *Self, solv: *SolverType) !void {
            const uprev = solv.uprev;

            var du: U = .{@as(T, 0.0)} ** N;
            prob_function(&du, &uprev, solv.t, &self.params);
            // update previous
            for (solv.u) |*u, i| {
                u.* = u.* + solv.dt * du[i];
            }
        }
    };
}
