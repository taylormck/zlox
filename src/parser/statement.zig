const std = @import("std");
const ArrayList = std.ArrayList;

const Result = @import("../Result.zig").Result;

const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const expression = @import("expression.zig");
const Expression = expression.Expression;

const evaluate = @import("../evaluate.zig");
const Value = evaluate.Value;

const parser = @import("parser.zig");
const match = parser.match;
const consume = parser.consume;
const ParseError = parser.ParseError;

const StatementType = union(enum) {
    print: Expression,
    expression: Expression,
};

const StatementResult = Result(Statement, ParseError);

pub const Statement = struct {
    type: StatementType,

    pub fn eval(self: @This()) !void {
        switch (self.type) {
            .print => |expr| {
                switch (try evaluate.evaluate(expr)) {
                    .ok => |val| {
                        try std.io.getStdOut().writer().print("{s}\n", .{val});
                    },
                    .err => {
                        // TODO: throw a runtime exception
                    },
                }
            },
            .expression => |expr| {
                switch (try evaluate.evaluate(expr)) {
                    .ok => {},
                    .err => {
                        // TODO: throw a runtime exception
                    },
                }
            },
        }
    }

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self.type) {
            .print => |expr| try writer.print("print {s};", .{expr}),
            .expression => |expr| try writer.print("{s};", .{expr}),
        }
    }

    pub fn parse(stream: *TokenStream) !StatementResult {
        if (match(stream, &.{.PRINT})) {
            return try parse_print(stream);
        }

        return try parse_expression_statement(stream);
    }

    fn parse_print(stream: *TokenStream) !StatementResult {
        if (consume(stream, .PRINT) catch false) {
            const result = try Expression.parse(stream);

            switch (result) {
                .ok => |expr| {
                    if (consume(stream, .SEMICOLON) catch false) {
                        return .{ .ok = .{
                            .type = .{ .print = expr },
                        } };
                    } else {
                        return .{ .err = .{
                            .type = error.UnexpectedToken,
                            .token = try stream.previous(),
                        } };
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        } else {
            return .{ .err = .{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            } };
        }
    }

    fn parse_expression_statement(stream: *TokenStream) !StatementResult {
        if (Expression.parse(stream)) |result| {
            switch (result) {
                .ok => |expr| {
                    if (consume(stream, .SEMICOLON) catch false) {
                        return .{ .ok = .{
                            .type = .{ .expression = expr },
                        } };
                    } else {
                        return .{ .err = .{
                            .type = error.UnexpectedToken,
                            .token = try stream.previous(),
                        } };
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        } else |err| {
            return err;
        }
    }
};
