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
const parse_expression = expression.parse_expression;
const ExpressionError = expression.ExpressionError;

const evaluate = @import("../evaluate.zig");
const Value = evaluate.Value;

const parser = @import("parser.zig");
const match = parser.match;
const consume = parser.consume;
const ParseError = parser.ParseError;

const StatementType = union(enum) {
    print: Value,
};

pub const Statement = struct {
    type: StatementType,

    pub fn eval(self: @This()) !void {
        switch (self.type) {
            .print => |val| {
                try std.io.getStdOut().writer().print("{s}\n", .{val});
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
            .print => |expr| try writer.print("print {s};\n", .{expr}),
        }
    }
};

const ParseStatementGrammarResult = Result(Statement, ParseError);
pub const ParseStatementResult = Result(Statement, []ParseError);

pub fn parse_statement(stream: *TokenStream) !ParseStatementGrammarResult {
    if (match(stream, &.{.PRINT})) {
        return try parse_print(stream);
    }

    @panic("Unsupported statement type");
}

fn parse_print(stream: *TokenStream) !ParseStatementGrammarResult {
    _ = try consume(stream, .PRINT);

    const result = try parse_expression(stream);

    switch (result) {
        .ok => |expr| {
            if (try consume(stream, .SEMICOLON)) {
                return switch (try evaluate.evaluate(expr)) {
                    .ok => |val| .{ .ok = .{
                        .type = .{ .print = val },
                    } },
                    .err => .{ .err = .{
                        .type = error.UnexpectedError,
                        .token = try stream.previous(),
                    } },
                };
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
}
