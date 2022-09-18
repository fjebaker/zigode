const std = @import("std");
const File = std.fs.File;

pub const ReturnCodes = enum { Success, Terminated, MaxIterReached, Error };

pub const SolverErrors = error{NoAllocator};

pub fn ProbFnType(comptime T: type, comptime N: usize, comptime P: type) type {
    const U = [N]T;
    return fn (du: *U, u: *const U, t: T, p: *P) void;
}

pub fn Solver(comptime T: type, comptime N: usize) type {
    return struct {
        pub const Self = @This();
        pub const U = [N]T;

        pub const Config = struct {
            callback: ?*const CallbackFn = null,
            max_iters: usize = 10_000,
            dt: T = @as(T, 0.1),
            save: bool = false,
            adaptive: bool = false,
        };

        pub const Solution = struct {
            t: []T,
            u: []U,
            retcode: ?ReturnCodes = null,
            allocator: std.mem.Allocator,
            index: usize = 0,

            pub fn init(allocator: std.mem.Allocator, max_size: usize) !@This() {
                var t = try allocator.alloc(T, max_size);
                errdefer allocator.free(t);

                var u = try allocator.alloc(U, max_size);
                errdefer allocator.free(u);

                return .{
                    .t = t,
                    .u = u,
                    .allocator = allocator,
                };
            }

            pub fn printInfo(self: *const @This(), f: File) !void {
                try f.writer().print(
                    \\ ZigODE Solution:
                    \\ ~~~~~~~~~~~~~~~~
                    \\ retcode      : {?}
                    \\ last t       : {e}
                    \\ last u       : {e}
                    \\ saved values : {d}
                    \\
                , .{ self.retcode, self.t[self.index - 1], self.u[self.index - 1], self.index});
            }

            pub fn saveStep(self: *@This(), t: T, u: *const U) void {
                std.debug.assert(self.index < self.t.len);
                self.t[self.index] = t;
                for (self.u[self.index]) |*v, i| {
                    v.* = u[i];
                }
                self.index += 1;
            }

            pub fn deinit(self: *@This()) void {
                self.allocator.free(self.t);
                self.allocator.free(self.u);
            }
        };

        // function types
        const StepFn = fn (ptr: *anyopaque, uprev: *U, t: T, dt: T) SolverErrors!void;
        pub const CallbackFn = fn (ptr: *Self, u: *const U, t: T) void;

        ptr: *anyopaque,
        performStep: *const StepFn,

        is_integrating: bool = false,
        retcode: ?ReturnCodes = null,

        uprev: U = undefined,

        allocator: std.mem.Allocator,

        pub fn init(
            pointer: anytype,
            comptime stepFn: fn (ptr: @TypeOf(pointer), uprev: *U, t: T, dt: T) SolverErrors!void,
            allocator: std.mem.Allocator,
        ) Self {
            const Ptr = @TypeOf(pointer);
            const ptr_info = @typeInfo(Ptr);
            const alignment = ptr_info.Pointer.alignment;
            // generating struct to wrap step function
            const gen = struct {
                fn performStep(ptr: *anyopaque, uprev: *U, t: T, dt: T) SolverErrors!void {
                    const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                    return @call(.{ .modifier = .always_inline }, stepFn, .{ self, uprev, dt, t });
                }
            };

            return .{ .ptr = pointer, .performStep = gen.performStep, .allocator = allocator };
        }

        pub fn solve(
            self: *Self,
            u: U,
            min_time: T,
            max_time: T,
            comptime config: Config,
        ) !Solution {
            // set uprev to initial u
            for (self.uprev) |*uprev, i| {
                uprev.* = u[i];
            }
            var t: T = min_time;

            var solution: Solution = try Solution.init(self.allocator, if (config.save) config.max_iters else 1);

            // as of *this* very moment, we're integrating
            self.is_integrating = true;
            // if we encounter an error, be sure to set this to false
            errdefer self.is_integrating = false;

            var dt: T = config.dt;
            var step_counter: usize = 0;
            while (step_counter < config.max_iters) : (step_counter += 1) {
                // calculate next time step
                dt = self.calcTimeStep(config.adaptive, dt);

                // do the integration step
                try self.performStep(self.ptr, &self.uprev, t, dt);
                t += dt;

                // maybe save
                if (config.save) {
                    solution.saveStep(t, &self.uprev);
                }

                if (t >= max_time) {
                    self.is_integrating = false;
                    self.retcode = ReturnCodes.Success;
                }

                // call the callback function
                if (config.callback) |cb| {
                    cb(self, &self.uprev, t);
                }

                if (!self.is_integrating) {
                    break;
                }
            } else self.retcode = ReturnCodes.MaxIterReached;
            // and now we have stopped
            self.is_integrating = false;

            if (!config.save) {
                // just save the last value
                solution.saveStep(t, &self.uprev);
            }

            solution.retcode = self.retcode;
            return solution;
        }

        fn calcTimeStep(_: *const Self, comptime adaptive: bool, dt: T) T {
            _ = adaptive;
            return dt;
        }

        pub fn terminate(self: *Self) void {
            self.is_integrating = false;
            self.retcode = ReturnCodes.Terminated;
        }
    };
}
