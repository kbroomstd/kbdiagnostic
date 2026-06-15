const std = @import("std");
const diag = @import("diagnostic.zig");

pub const ReportHandler = @This();
ptr: *const anyopaque,
vtable: *const VTable,

pub fn implBy(impl_obj: anytype) ReportHandler {
    const delegate = ReportHandlerDelegate(impl_obj);
    return .{
        .ptr = impl_obj,
        .vtable = &.{
            .display = delegate.display,
        },
    };
}

pub fn display(self: *const ReportHandler, allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
    try self.vtable.display(self.ptr, allocator, writer, err);
}

pub const VTable = struct {
    display: *const fn (*const anyopaque, std.mem.Allocator, *std.Io.Writer, *const diag.Diagnostic) std.Io.Writer.Error!void,
};

inline fn ReportHandlerDelegate(impl_obj: anytype) type {
    const ImplType = ImplChild(@TypeOf(impl_obj));
    const ImplPtrType = @TypeOf(impl_obj);
    return struct {
        fn display(impl: *const anyopaque, allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
            const obj = TPtr(ImplPtrType, impl);
            if (@hasDecl(ImplType, "display")) return obj.display(allocator, writer, err);
            return @field(obj, "display")(allocator, writer, err);
        }
    };
}

fn TPtr(T: type, opaque_ptr: *const anyopaque) T {
    return @as(T, @ptrFromInt(@intFromPtr(opaque_ptr)));
}

fn ImplChild(T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.child,
        else => T,
    };
}
