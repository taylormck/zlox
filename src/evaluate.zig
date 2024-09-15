const std = @import("std");
const Expression = @import("parser/expression.zig").Expression;

pub fn evaluate(expr: Expression) !Value {
    switch (expr.type) {
        .literal => |literal| switch (literal) {
            .number => |n| return .{ .number = n },
            .bool => |b| return .{ .bool = b },
            .nil => return .nil,
            .string => |s| return .{ .string = s },
            else => @panic("Unsupported literal type"),
        },
        .grouping => {
            return evaluate(expr.children.items[0]);
        },
        .unary => |unary| {
            const rhs = try evaluate(expr.children.items[0]);

            return switch (unary) {
                .negate => switch (rhs) {
                    .number => |num| .{ .bool = num == 0 },
                    .bool => |b| .{ .bool = !b },
                    .nil => .{ .bool = true },
                    else => @panic("Unsupported operand for negate operator"),
                },
                .minus => switch (rhs) {
                    .number => |num| .{ .number = -num },
                    else => @panic("Unsupported operand to unary minus operator"),
                },
                else => @panic("Unsupported unary operator"),
            };
        },
        .factor => |factor| {
            const lhs = try evaluate(expr.children.items[0]);
            const rhs = try evaluate(expr.children.items[1]);

            var value: f64 = 0;

            switch (factor) {
                .multiply => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number * rhs.number;
                    } else {
                        @panic("Unsupported operands to multiply operator");
                    }
                },

                .divide => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number / rhs.number;
                    } else {
                        @panic("Unsupported operands to divide operator");
                    }
                },
                else => @panic("Unsupported term operator"),
            }

            return .{ .number = value };
        },
        .term => |term| {
            const lhs = try evaluate(expr.children.items[0]);
            const rhs = try evaluate(expr.children.items[1]);

            var value: f64 = 0;
            switch (term) {
                .add => {
                    if (lhs.is_string() and rhs.is_string()) {
                        return .{
                            .string = try std.fmt.allocPrint(
                                std.heap.page_allocator,
                                "{s}{s}",
                                .{ lhs.string, rhs.string },
                            ),
                        };
                    } else if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number + rhs.number;
                    } else {
                        @panic("Unsupported operands to add operator");
                    }
                },
                .subtract => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number - rhs.number;
                    } else {
                        @panic("Unsupported operands to subtract operator");
                    }
                },
                else => @panic("Unsupported term operator"),
            }

            return .{ .number = value };
        },
        .comparison => |comp| {
            const lhs = try evaluate(expr.children.items[0]);
            const rhs = try evaluate(expr.children.items[1]);

            if (!lhs.is_number() or !rhs.is_number()) {
                @panic("Unsupported operands to compare operator");
            }

            const value = switch (comp) {
                .less => lhs.number < rhs.number,
                .less_equal => lhs.number <= rhs.number,
                .greater => lhs.number > rhs.number,
                .greater_equal => lhs.number >= rhs.number,
                else => @panic("Unsupported compare operator"),
            };

            return .{ .bool = value };
        },
        .equality => |eql| {
            const lhs = try evaluate(expr.children.items[0]);
            const rhs = try evaluate(expr.children.items[1]);

            if (!lhs.is_same_type(rhs)) {
                return switch (eql) {
                    .equal => .{ .bool = false },
                    .not_equal => .{ .bool = true },
                    else => @panic("Unsupported compare operator"),
                };
            }

            const value = switch (eql) {
                .equal => switch (lhs) {
                    .number => lhs.number == rhs.number,
                    .bool => lhs.bool == rhs.bool,
                    .nil => true,
                    .string => std.mem.eql(u8, lhs.string, rhs.string),
                },
                .not_equal => switch (lhs) {
                    .number => lhs.number != rhs.number,
                    .bool => lhs.bool != rhs.bool,
                    .nil => false,
                    .string => !std.mem.eql(u8, lhs.string, rhs.string),
                },
                else => @panic("Unsupported compare operator"),
            };

            return .{ .bool = value };
        },
    }
}

const Value = union(enum) {
    number: f64,
    bool: bool,
    nil,
    string: []const u8,

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
            .string => |s| try writer.print("{s}", .{s}),
        }
    }

    fn is_number(self: @This()) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }

    fn is_string(self: @This()) bool {
        return switch (self) {
            .string => true,
            else => false,
        };
    }

    fn is_same_type(self: @This(), other: @This()) bool {
        return switch (self) {
            .number => switch (other) {
                .number => true,
                else => false,
            },
            .bool => switch (other) {
                .bool => true,
                else => false,
            },
            .nil => switch (other) {
                .nil => true,
                else => false,
            },
            .string => switch (other) {
                .string => true,
                else => false,
            },
        };
    }
};

