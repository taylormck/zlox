/// Hypothetically, this function could be a method on the Expression
/// struct. However, it's huge.
/// I decided to leave it factored out as its own thing to avoid
/// making too much clutter in in Expression.zig
const std = @import("std");
const Expression = @import("parser/expression.zig").Expression;
const Result = @import("Result.zig").Result;
const ResultError = @import("Result.zig").ResultError;
const Value = @import("Value.zig").Value;
const Scope = @import("Scope.zig").Scope;

pub fn evaluate(expr: Expression, scope: *Scope) !EvaluateResult {
    switch (expr.type) {
        .literal => |literal| switch (literal) {
            .number => |n| return .{ .ok = .{ .number = n } },
            .bool => |b| return .{ .ok = .{ .bool = b } },
            .nil => return .{ .ok = .nil },
            .string => |s| return .{ .ok = .{ .string = s } },
            .identifier => |i| {
                if (scope.get(i)) |val| {
                    return .{ .ok = val };
                } else |_| {
                    return .{
                        .err = .{ .type = .{ .UndefinedVariable = i } },
                    };
                }
            },
            else => @panic("Unsupported literal type"),
        },
        .grouping => {
            return evaluate(expr.children.items[0], scope);
        },
        .unary => |unary| {
            const rhs = try evaluate(expr.children.items[0], scope);

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
            const lhs = try evaluate(expr.children.items[0], scope);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1], scope);

                    switch (rhs) {
                        .ok => |rhs_ok| {
                            var value: f64 = 0;

                            switch (factor) {
                                .multiply => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number * rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
                                    }
                                },

                                .divide => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number / rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
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
            const lhs = try evaluate(expr.children.items[0], scope);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1], scope);
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
                                        return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
                                    }
                                },
                                .subtract => {
                                    if (lhs_ok.is_number() and rhs_ok.is_number()) {
                                        value = lhs_ok.number - rhs_ok.number;
                                    } else {
                                        return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
                                    }
                                },
                                else => {
                                    return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
                                },
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
            const lhs = try evaluate(expr.children.items[0], scope);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1], scope);

                    switch (rhs) {
                        .ok => |rhs_ok| {
                            if (!lhs_ok.is_number() or !rhs_ok.is_number()) {
                                return .{ .err = .{ .type = .{ .InvalidOperands = "numbers" } } };
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
            const lhs = try evaluate(expr.children.items[0], scope);

            switch (lhs) {
                .ok => |lhs_ok| {
                    const rhs = try evaluate(expr.children.items[1], scope);

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
        .assignment => |name| {
            _ = scope.get(name) catch {
                return .{ .err = .{ .type = .{ .UndefinedVariable = name } } };
            };

            const rhs = try evaluate(expr.children.items[0], scope);

            switch (rhs) {
                .ok => |val| {
                    try scope.assign(name, val);
                    return .{ .ok = val };
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        },
        .logic_or => {
            switch (try evaluate(expr.children.items[0], scope)) {
                .ok => |or_val| {
                    switch (or_val) {
                        .bool => |val| {
                            if (val) {
                                return .{ .ok = .{ .bool = true } };
                            } else {
                                return evaluate(expr.children.items[1], scope);
                            }
                        },
                        else => return .{ .err = .{ .type = .{ .IncorrectType = "bool" } } },
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        },
        .logic_and => {
            switch (try evaluate(expr.children.items[0], scope)) {
                .ok => |and_val| {
                    switch (and_val) {
                        .bool => |val| {
                            if (val) {
                                return evaluate(expr.children.items[1], scope);
                            } else {
                                return .{ .ok = .{ .bool = false } };
                            }
                        },
                        else => return .{ .err = .{ .type = .{ .IncorrectType = "bool" } } },
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        },
    }
}

const EvaluateErrorType = union(enum) {
    InvalidOperand: []const u8,
    InvalidOperands: []const u8,
    UndefinedVariable: []const u8,
    IncorrectType: []const u8,
};

pub const EvaluateError = struct {
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
            .InvalidOperands => |needed_type| {
                try writer.print("Operands must be {s}.\n", .{needed_type});
            },
            .UndefinedVariable => |name| {
                try writer.print("Undefined variable '{s}'.\n", .{name});
            },
            .IncorrectType => |expected_type| {
                try writer.print("Expected {s}.\n", .{expected_type});
            },
        }
    }
};

pub const EvaluateResult = Result(Value, EvaluateError);
