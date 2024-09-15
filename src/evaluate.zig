const std = @import("std");
const Expression = @import("parser/expression.zig").Expression;
const Result = @import("Result.zig").Result;

pub fn evaluate(expr: Expression) !EvaluateResult {
    switch (expr.type) {
        .literal => |literal| switch (literal) {
            .number => |n| return .{ .ok = .{ .number = n } },
            .bool => |b| return .{ .ok = .{ .bool = b } },
            .nil => return .{ .ok = .nil },
            .string => |s| return .{ .ok = .{ .string = s } },
            else => @panic("Unsupported literal type"),
        },
        .grouping => {
            return evaluate(expr.children.items[0]);
        },
        .unary => |unary| {
            const rhs = try evaluate(expr.children.items[0]);

            switch (rhs) {
                .ok => |rhs_ok| {
                    return switch (unary) {
                        .negate => switch (rhs_ok) {
                            .number => |num| .{ .ok = .{ .bool = num == 0 } },
                            .bool => |b| .{ .ok = .{ .bool = !b } },
                            .nil => .{ .ok = .{ .bool = true } },
                            else => @panic("Unsupported operand for negate operator"),
                        },
                        .minus => switch (rhs_ok) {
                            .number => |num| .{ .ok = .{ .number = -num } },
                            else => .{ .err = .{
                                .type = .{ .InvalidOperand = "number" },
                            } },
                        },
                        else => @panic("Unsupported unary operator"),
                    };
                },
                .err => {
                    return rhs;
                },
            }
        },
        .factor => |factor| {
            const lhs = try evaluate(expr.children.items[0]);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1]);

                    switch (rhs) {
                        .ok => |rhs_ok| {
                            var value: f64 = 0;

                            switch (factor) {
                                .multiply => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number * rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperand = "number" } } };
                                    }
                                },

                                .divide => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number / rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperand = "number" } } };
                                    }
                                },
                                else => @panic("Unsupported term operator"),
                            }

                            return .{ .ok = .{ .number = value } };
                        },
                        .err => {
                            return rhs;
                        },
                    }
                },
                .err => {
                    return lhs;
                },
            }
        },
        .term => |term| {
            const lhs = try evaluate(expr.children.items[0]);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1]);
                    switch (rhs) {
                        .ok => |rhs_ok| {
                            var value: f64 = 0;
                            switch (term) {
                                .add => {
                                    if (lhs_ok.is_string() and rhs_ok.is_string()) {
                                        return .{ .ok = .{
                                            .string = try std.fmt.allocPrint(
                                                std.heap.page_allocator,
                                                "{s}{s}",
                                                .{ lhs_ok.string, rhs_ok.string },
                                            ),
                                        } };
                                    } else if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number + rhs_ok.number;
                                    } else {
                                        @panic("Unsupported operands to add operator");
                                    }
                                },
                                .subtract => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number - rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperand = "number" } } };
                                    }
                                },
                                else => @panic("Unsupported term operator"),
                            }

                            return .{ .ok = .{ .number = value } };
                        },
                        .err => {
                            return rhs;
                        },
                    }
                },
                .err => {
                    return lhs;
                },
            }
        },
        .comparison => |comp| {
            const lhs = try evaluate(expr.children.items[0]);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1]);

                    switch (rhs) {
                        .ok => |rhs_ok| {
                            if (!lhs_ok.is_number() or !rhs_ok.is_number()) {
                                return .{ .err = .{ .type = .{ .InvalidOperand = "number" } } };
                            }

                            const value = switch (comp) {
                                .less => lhs_ok.number < rhs_ok.number,
                                .less_equal => lhs_ok.number <= rhs_ok.number,
                                .greater => lhs_ok.number > rhs_ok.number,
                                .greater_equal => lhs_ok.number >= rhs_ok.number,
                                else => @panic("Unsupported compare operator"),
                            };

                            return .{ .ok = .{ .bool = value } };
                        },
                        .err => {
                            return rhs;
                        },
                    }
                },
                .err => {
                    return lhs;
                },
            }
        },
        .equality => |eql| {
            const lhs = try evaluate(expr.children.items[0]);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1]);

                    switch (rhs) {
                        .ok => |rhs_ok| {
                            if (!lhs_ok.is_same_type(rhs_ok)) {
                                return switch (eql) {
                                    .equal => .{ .ok = .{ .bool = false } },
                                    .not_equal => .{ .ok = .{ .bool = true } },
                                    else => @panic("Unsupported compare operator"),
                                };
                            }

                            const value = switch (eql) {
                                .equal => switch (lhs_ok) {
                                    .number => lhs_ok.number == rhs_ok.number,
                                    .bool => lhs_ok.bool == rhs_ok.bool,
                                    .nil => true,
                                    .string => std.mem.eql(u8, lhs_ok.string, rhs_ok.string),
                                },
                                .not_equal => switch (lhs_ok) {
                                    .number => lhs_ok.number != rhs_ok.number,
                                    .bool => lhs_ok.bool != rhs_ok.bool,
                                    .nil => false,
                                    .string => !std.mem.eql(u8, lhs_ok.string, rhs_ok.string),
                                },
                                else => @panic("Unsupported compare operator"),
                            };

                            return .{ .ok = .{ .bool = value } };
                        },
                        .err => {
                            return rhs;
                        },
                    }
                },
                .err => {
                    return lhs;
                },
            }
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

const EvaluateErrorType = union(enum) {
    InvalidOperand: []const u8,
};

const EvaluateError = struct {
    type: EvaluateErrorType,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self.type) {
            .InvalidOperand => |needed_type| {
                try writer.print("Operand must be a {s}.\n", .{needed_type});
            },
        }
    }
};

const EvaluateResult = Result(Value, EvaluateError);

