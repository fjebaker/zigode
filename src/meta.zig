const std = @import("std");

pub fn getChildType(comptime Pointer: type) type {
    switch (@typeInfo(Pointer)) {
        .Pointer => |p| return p.child,
        else => @compileError("Could not determine child type of pointer."),
    }
}

pub fn getSliceInfo(comptime Slice: type) std.builtin.Type.Array {
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

pub fn deduceTypes(comptime ProbFunc: anytype) type {
    const ProbFunctType = @TypeOf(ProbFunc);
    const Args = @typeInfo(std.meta.ArgsTuple(ProbFunctType));

    var du_array: std.builtin.Type.Array = undefined;
    var u_array: std.builtin.Type.Array = undefined;
    switch (Args) {
        .Struct => |A| {
            du_array = getSliceInfoFromPointer(A.fields[0].field_type);
            u_array = getSliceInfoFromPointer(A.fields[0].field_type);
        },
        else => @compileError("Arguments to ProbFunc are not inferable."),
    }
    const N = blk: {
        if (du_array.len != u_array.len) @compileError("ProbFunc du and u arguments must have the same (comptime known) array lengths.");
        break :blk du_array.len;
    };
    const T = blk: {
        if (du_array.child != u_array.child) @compileError("ProbFunc du and u must have the same array child type.");
        break :blk du_array.child;
    };

    return [N]T;
}
