const std = @import("std");
const Expression = @import("parser/expression.zig").Expression;

pub fn evaluate(expr: Expression) !Value {
    switch (expr.type) {
        .literal => |literal| switch (literal) {
            .number => |n| return .{ .number = n },
            .bool => |b| return .{ .bool = b },
            .nil => return .nil,
            else => @panic("Unsupported literal type"),
        },
        .term => |term| {
            const lhs = try evaluate(expr.children.items[0]);
            const rhs = try evaluate(expr.children.items[1]);

            const value = switch (term) {
                .add => lhs.number + rhs.number,
                .subtract => lhs.number - rhs.number,
                else => @panic("Unsupported operator type"),
            };

            return .{ .number = value };
        },
        else => @panic("Unsupported expression type"),
    }
}

const Value = union(enum) {
    number: f64,
    bool: bool,
    nil,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .number => |num| try writer.print("{d}", .{num}),
            .bool => |b| try writer.print("{}", .{b}),
            .nil => try writer.print("nil", .{}),
        }
    }
};
