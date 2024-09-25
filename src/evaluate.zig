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
            .number => |n| return Ok(.{ .number = n }),
            .bool => |b| return Ok(.{ .bool = b }),
            .nil => return Ok(.nil),
            .string => |s| return Ok(.{ .string = s }),
            .identifier => |i| {
                if (scope.get(i)) |val| {
                    return Ok(val);
                } else |_| {
                    return Err(.{ .type = .{ .UndefinedVariable = i } });
                }
            },
            else => @panic("Unsupported literal type"),
        },
        .grouping => {
            return evaluate(expr.children.items[0], scope);
        },
        .unary => |unary| {
            const result = try evaluate(expr.children.items[0], scope);

            if (!result.is_ok()) {
                return result;
            }

            const val = result.unwrap() catch unreachable;

            return switch (unary) {
                .negate => switch (val) {
                    .number => |num| Ok(.{ .bool = num == 0 }),
                    .bool => |b| Ok(.{ .bool = !b }),
                    .nil => Ok(.{ .bool = true }),
                    else => @panic("Unsupported operand for negate operator"),
                },
                .minus => switch (val) {
                    .number => |num| Ok(.{ .number = -num }),
                    else => Err(.{ .type = .{ .InvalidOperand = "number" } }),
                },
                else => @panic("Unsupported unary operator"),
            };
        },
        .factor => |factor| {
            const left_result = try evaluate(expr.children.items[0], scope);

            if (!left_result.is_ok()) {
                return left_result;
            }

            const right_result = try evaluate(expr.children.items[1], scope);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const lhs = left_result.unwrap() catch unreachable;
            const rhs = right_result.unwrap() catch unreachable;

            var value: f64 = 0;

            switch (factor) {
                .multiply => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number * rhs.number;
                    } else {
                        return Err(.{ .type = .{ .InvalidOperands = "numbers" } });
                    }
                },

                .divide => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number / rhs.number;
                    } else {
                        return Err(.{ .type = .{ .InvalidOperands = "numbers" } });
                    }
                },
                else => @panic("Unsupported factor operator"),
            }

            return Ok(.{ .number = value });
        },
        .term => |term| {
            const left_result = try evaluate(expr.children.items[0], scope);

            if (!left_result.is_ok()) {
                return left_result;
            }

            const right_result = try evaluate(expr.children.items[1], scope);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const lhs = left_result.unwrap() catch unreachable;
            const rhs = right_result.unwrap() catch unreachable;

            var value: f64 = 0;
            switch (term) {
                .add => {
                    if (lhs.is_string() and rhs.is_string()) {
                        return Ok(.{
                            .string = try std.fmt.allocPrint(
                                std.heap.page_allocator,
                                "{s}{s}",
                                .{ lhs.string, rhs.string },
                            ),
                        });
                    } else if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number + rhs.number;
                    } else {
                        return Err(.{ .type = .{ .InvalidOperands = "numbers" } });
                    }
                },
                .subtract => {
                    if (lhs.is_number() and rhs.is_number()) {
                        value = lhs.number - rhs.number;
                    } else {
                        return Err(.{ .type = .{ .InvalidOperands = "numbers" } });
                    }
                },
                else => @panic("Unsupported term operator"),
            }

            return Ok(.{ .number = value });
        },
        .comparison => |comp| {
            const left_result = try evaluate(expr.children.items[0], scope);

            if (!left_result.is_ok()) {
                return left_result;
            }

            const right_result = try evaluate(expr.children.items[1], scope);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const lhs = left_result.unwrap() catch unreachable;
            const rhs = right_result.unwrap() catch unreachable;

            if (!lhs.is_number() or !rhs.is_number()) {
                return Err(.{ .type = .{ .InvalidOperands = "numbers" } });
            }

            const value = switch (comp) {
                .less => lhs.number < rhs.number,
                .less_equal => lhs.number <= rhs.number,
                .greater => lhs.number > rhs.number,
                .greater_equal => lhs.number >= rhs.number,
                else => @panic("Unsupported compare operator"),
            };

            return Ok(.{ .bool = value });
        },
        .equality => |eql| {
            const left_result = try evaluate(expr.children.items[0], scope);

            if (!left_result.is_ok()) {
                return left_result;
            }

            const right_result = try evaluate(expr.children.items[1], scope);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const lhs = left_result.unwrap() catch unreachable;
            const rhs = right_result.unwrap() catch unreachable;

            if (!lhs.is_same_type(rhs)) {
                return switch (eql) {
                    .equal => Ok(.{ .bool = false }),
                    .not_equal => Ok(.{ .bool = true }),
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

            return Ok(.{ .bool = value });
        },
        .assignment => |name| {
            _ = scope.get(name) catch {
                return Err(.{ .type = .{ .UndefinedVariable = name } });
            };

            const result = try evaluate(expr.children.items[0], scope);

            if (!result.is_ok()) {
                const err = result.unwrap_err() catch unreachable;
                return Err(err);
            }

            const val = result.unwrap() catch unreachable;
            try scope.assign(name, val);

            return Ok(val);
        },
        .logic_or => {
            const result = try evaluate(expr.children.items[0], scope);

            if (!result.is_ok()) {
                return result;
            }

            const val = result.unwrap() catch unreachable;

            if (val.is_truthy()) {
                return Ok(.{ .bool = true });
            }

            return evaluate(expr.children.items[1], scope);
        },
        .logic_and => {
            const result = try evaluate(expr.children.items[0], scope);

            if (!result.is_ok()) {
                return result;
            }

            const val = result.unwrap() catch unreachable;

            if (val.is_truthy()) {
                return evaluate(expr.children.items[1], scope);
            }

            return Ok(.{ .bool = false });
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
const Ok = EvaluateResult.ok;
const Err = EvaluateResult.err;
