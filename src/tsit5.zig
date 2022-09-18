const std = @import("std");
const solver = @import("./solver.zig");
const Solver = solver.Solver;

fn Coefficients(comptime T: type) type {
    return struct {
        const c = [_]T{
            0.161,
            0.327,
            0.9,
            0.9,
            0.9800255409045097,
            1.0,
            1.0,
        };
        const a = [_]T{
            0.161,
            -0.008480655492356989,
            0.335480655492357,
            2.8971530571054935,
            -6.359448489975075,
            4.3622954328695815,
            5.325864828439257,
            -11.748883564062828,
            7.4955393428898365,
            -0.09249506636175525,
            5.86145544294642,
            -12.92096931784711,
            8.159367898576159,
            -0.071584973281401,
            -0.028269050394068383,
            0.09646076681806523,
            0.01,
            0.4798896504144996,
            1.379008574103742,
            -3.290069515436081,
            2.324710524099774,
        };
        const b = [_]T{
            -0.00178001105222577714,
            -0.0008164344596567469,
            0.007880878010261995,
            -0.1447110071732629,
            0.5823571654525552,
            -0.45808210592918697,
            0.015151515151515152,
        };
        const r = [_]T{
            1.0,
            -2.763706197274826,
            2.9132554618219126,
            -1.0530884977290216,
            0.13169999999999998,
            -0.2234,
            0.1017,
            3.9302962368947516,
            -5.941033872131505,
            2.490627285651253,
            -12.411077166933676,
            30.33818863028232,
            -16.548102889244902,
            37.50931341651104,
            -88.1789048947664,
            47.37952196281928,
            -27.896526289197286,
            65.09189467479366,
            -34.87065786149661,
            1.5,
            -4,
            2.5,
        };
    };
}

pub fn Tsit5(comptime T: type, comptime N: usize, comptime P: type) type {
    return struct {
        const Self = @This();
        const SolverType = Solver(T, N);
        const U = SolverType.U;
        const ProbFn = solver.ProbFnType(T, N, P);

        const coeff = Coefficients(T);

        prob: *const ProbFn,
        params: P,
        k: [6]U = .{.{@as(T, 0.0)} ** N} ** 6,

        pub fn init(comptime prob: *const ProbFn, params: P) Self {
            return .{ .prob = prob, .params = params };
        }

        pub fn getSolver(self: *Self, allocator: std.mem.Allocator) SolverType {
            return SolverType.init(self, Self.step, allocator);
        }

        pub fn step(self: *Self, uprev: *U, t: T, dt: T) !void {
            var temp: U = .{0.0} ** N;
            // k0
            self.prob(&self.k[0], uprev, t, &self.params);
            for (temp) |*v, i| {
                v.* = uprev[i] + dt * Self.coeff.a[0] * self.k[0][i];
            }
            // k1
            self.prob(&self.k[1], &temp, t + Self.coeff.c[0] * dt, &self.params);
            for (temp) |*v, i| {
                v.* = uprev[i] + dt * (Self.coeff.a[1] * self.k[0][i] + Self.coeff.a[2] * self.k[1][i]);
            }
            // k2
            self.prob(&self.k[2], &temp, t + Self.coeff.c[1] * dt, &self.params);
            for (temp) |*v, i| {
                v.* = uprev[i] + dt * (Self.coeff.a[3] * self.k[0][i] + Self.coeff.a[4] * self.k[1][i] + Self.coeff.a[5] * self.k[2][i]);
            }
            // k3
            self.prob(&self.k[3], &temp, t + Self.coeff.c[2] * dt, &self.params);
            for (temp) |*v, i| {
                v.* = uprev[i] + dt * (Self.coeff.a[6] * self.k[0][i] + Self.coeff.a[7] * self.k[1][i] + Self.coeff.a[8] * self.k[2][i] + Self.coeff.a[9] * self.k[3][i]);
            }
            // k4
            self.prob(&self.k[4], &temp, t + Self.coeff.c[3] * dt, &self.params);
            for (temp) |*v, i| {
                v.* = uprev[i] + dt * (Self.coeff.a[10] * self.k[0][i] + Self.coeff.a[11] * self.k[1][i] + Self.coeff.a[12] * self.k[2][i] + Self.coeff.a[13] * self.k[3][i] + Self.coeff.a[14] * self.k[4][i]);
            }
            // k5
            self.prob(&self.k[5], &temp, t + dt, &self.params);
            // now assign to previous u value
            for (uprev) |*v, i| {
                v.* = uprev[i] + dt * (Self.coeff.a[15] * self.k[0][i] + Self.coeff.a[16] * self.k[1][i] + Self.coeff.a[17] * self.k[2][i] + Self.coeff.a[18] * self.k[3][i] + Self.coeff.a[19] * self.k[4][i] + Self.coeff.a[20] * self.k[5][i]);
            }
        }
    };
}
