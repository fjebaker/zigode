const std = @import("std");
const File = std.fs.File;

pub const ReturnCodes = enum { Success, Terminated, MaxIterReached, Error };

pub const SolverErrors = error{ NoAllocator, TimeStepTooSmall, TimeStepTooBig };

pub fn ProbFnType(comptime T: type, comptime N: usize, comptime P: type) type {
    const U = [N]T;
    return fn (du: *U, u: *const U, t: T, p: *P) void;
}

pub fn Solver(comptime T: type, comptime N: usize, comptime P: type) type {
    return struct {
        pub const Self = @This();
        pub const U = [N]T;

        pub const Config = struct {
            callback: ?*const CallbackFnProto = null,
            max_iters: usize = 10_000,
            dt: T = @as(T, 0.1),
            save: bool = false,
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
                    \\ ODE⚡Solution:
                    \\ ~~~~~~~~~~~~~~~~
                    \\ retcode      : {?}
                    \\ last t       : {e}
                    \\ last u       : {e}
                    \\ saved values : {d}
                    \\
                , .{ self.retcode, self.t[self.index - 1], self.u[self.index - 1], self.index });
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
        const StepFnProto = fn (*anyopaque, *Self) SolverErrors!void;
        pub const CallbackFnProto = fn (ptr: *Self, u: *const U, t: T, p: *P) void;

        ptr: *anyopaque,
        performStep: *const StepFnProto,

        is_integrating: bool = false,
        retcode: ?ReturnCodes = null,

        allocator: std.mem.Allocator,

        // solving variables
        uprev: U = undefined, // previous u
        u: U = undefined, // current u
        params: *P = undefined,
        t: T = 0.0,
        dt: T = undefined,
        dt_proposed: T = undefined,
        step_count: T = undefined,

        config: Config = undefined,

        pub fn init(
            pointer: anytype,
            comptime stepFn: fn (@TypeOf(pointer), *Self) SolverErrors!void,
            allocator: std.mem.Allocator,
        ) Self {
            const Ptr = @TypeOf(pointer);
            const ptr_info = @typeInfo(Ptr);
            const alignment = ptr_info.Pointer.alignment;

            // generating struct to wrap step function
            const gen = struct {
                fn performStep(ptr: *anyopaque, solver_self: *Self) SolverErrors!void {
                    const self = @ptrCast(Ptr, @alignCast(alignment, ptr));
                    try @call(
                        .{ .modifier = .always_inline },
                        stepFn,
                        .{ self, solver_self },
                    );
                }
            };

            // need access to params for the callback
            const params = &(@ptrCast(Ptr, @alignCast(alignment, pointer)).params);
            return .{ .ptr = pointer, .performStep = gen.performStep, .allocator = allocator, .params = params };
        }

        pub fn solve(
            self: *Self,
            u: U,
            min_time: T,
            max_time: T,
            comptime config: Config,
        ) !Solution {
            // save variables
            self.config = config;
            self.u = u;
            self.dt = config.dt;
            self.dt_proposed = self.dt;
            self.t = min_time;
            self.step_count = 0;
            // set uprev to initial u
            for (self.uprev) |*uprev, i| {
                uprev.* = u[i];
            }

            // initialise our solution storage
            var solution: Solution = try Solution.init(
                self.allocator,
                if (config.save) config.max_iters else 1,
            );
            errdefer solution.deinit();

            // as of *this* very moment, we're integrating
            self.is_integrating = true;
            defer self.is_integrating = false;

            while (self.step_count < config.max_iters) : (self.step_count += 1) {
                // maybe save
                if (config.save) {
                    solution.saveStep(self.t, &self.u);
                }

                // do the integration step
                try self.performStep(self.ptr, self);

                // increment with proposed dt
                self.dt = self.dt_proposed;
                self.t += self.dt;

                if (self.t >= max_time) {
                    self.is_integrating = false;
                    self.retcode = ReturnCodes.Success;
                }

                // call the callback function
                if (config.callback) |cb| {
                    cb(self, &self.u, self.t, self.params);
                }

                if (!self.is_integrating) {
                    break;
                } else {
                    for (self.uprev) |*v, i| {
                        v.* = self.u[i];
                    }
                }
            } else self.retcode = ReturnCodes.MaxIterReached;

            if (!config.save) {
                // just save the last good value
                solution.saveStep(self.t, &self.uprev);
            }

            solution.retcode = self.retcode;
            return solution;
        }

        pub fn terminate(self: *Self) void {
            self.is_integrating = false;
            self.retcode = ReturnCodes.Terminated;
        }
    };
}
