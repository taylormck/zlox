const std = @import("std");
const ArrayList = std.ArrayList;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const Result = @import("../Result.zig").Result;

const expression = @import("expression.zig");
const Expression = expression.Expression;
const ExpressionType = expression.ExpressionType;

const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const ParserErrorType = error{
    UnexpectedToken,
    UnexpectedError,
};

const ParserError = struct {
    err: ParserErrorType,
    token: Token,

    pub fn format(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.err) {
            error.UnexpectedToken => {
                try writer.print(
                    "[line {d}] Error at '{s}': Expect expression.",
                    .{ self.token.line, self.token.lexeme },
                );
            },
            error.UnexpectedError => {
                try writer.print("Unexpected error occurred.", .{});
            },
        }
    }
};

const ParserResult = Result(Expression, ParserError);
const ParseResult = Result(Expression, []ParserError);

pub fn parse(tokens: []const Token) !ParseResult {
    var stream = TokenStream.new(tokens);

    if (parse_expression(&stream)) |result| {
        return switch (result) {
            .ok => |expr| .{
                .ok = expr,
            },
            .err => |err| {
                var errors = ArrayList(ParserError).init(std.heap.page_allocator);
                try errors.append(err);

                return .{ .err = errors.items };
            },
        };
    } else |err| {
        return err;
    }
}

fn parse_expression(stream: *TokenStream) !ParserResult {
    return parse_equality(stream);
}

fn parse_equality(stream: *TokenStream) !ParserResult {
    const result = try parse_comparison(stream);

    switch (result) {
        .ok => |expr| {
            var lhs = expr;

            while (match(stream, &.{ .EQUAL_EQUAL, .BANG_EQUAL })) {
                const op = stream.next() catch |err| return ParserError{
                    .err = err,
                    .token = lhs,
                };

                const right_result = try parse_comparison(stream);

                switch (right_result) {
                    .ok => |rhs| {
                        var children = ArrayList(Expression).init(std.heap.page_allocator);
                        try children.append(lhs);
                        try children.append(rhs);

                        const equality_type: Operator = switch (op.type) {
                            .EQUAL_EQUAL => .equal,
                            .BANG_EQUAL => .not_equal,
                            else => return .{ .err = ParserError{
                                .err = error.UnexpectedToken,
                                .token = op,
                            } },
                        };

                        lhs = .{
                            .type = .{ .equality = equality_type },
                            .children = children,
                        };
                    },
                    .err => return right_result,
                }
            }

            return .{ .ok = lhs };
        },
        .err => return result,
    }
}

fn parse_comparison(stream: *TokenStream) !ParserResult {
    const result = try parse_term(stream);

    switch (result) {
        .ok => |expr| {
            var lhs = expr;

            while (match(stream, &.{ .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL })) {
                const op = try stream.next();

                const right_result = try parse_term(stream);

                switch (right_result) {
                    .ok => |rhs| {
                        var children = ArrayList(Expression).init(std.heap.page_allocator);
                        try children.append(lhs);
                        try children.append(rhs);

                        const comparison_type: Operator = switch (op.type) {
                            .LESS => .less,
                            .LESS_EQUAL => .less_equal,
                            .GREATER => .greater,
                            .GREATER_EQUAL => .greater_equal,
                            else => return .{ .err = ParserError{
                                .err = error.UnexpectedToken,
                                .token = op,
                            } },
                        };

                        lhs = .{
                            .type = .{ .comparison = comparison_type },
                            .children = children,
                        };
                    },
                    .err => return right_result,
                }
            }

            return .{ .ok = lhs };
        },
        .err => return result,
    }
}

fn parse_term(stream: *TokenStream) !ParserResult {
    const result = try parse_factor(stream);

    switch (result) {
        .ok => |expr| {
            var lhs = expr;

            while (match(stream, &.{ .PLUS, .MINUS })) {
                const op = try stream.next();

                const right_result = try parse_factor(stream);

                switch (right_result) {
                    .ok => |rhs| {
                        var children = ArrayList(Expression).init(std.heap.page_allocator);
                        try children.append(lhs);
                        try children.append(rhs);

                        const term_type: Operator = switch (op.type) {
                            .PLUS => .add,
                            .MINUS => .subtract,
                            else => return .{ .err = ParserError{
                                .err = error.UnexpectedToken,
                                .token = op,
                            } },
                        };

                        lhs = .{
                            .type = .{ .term = term_type },
                            .children = children,
                        };
                    },
                    .err => return right_result,
                }
            }

            return .{ .ok = lhs };
        },
        .err => return result,
    }
}

fn parse_factor(stream: *TokenStream) !ParserResult {
    const result = try parse_unary(stream);

    switch (result) {
        .ok => |expr| {
            var lhs = expr;

            while (match(stream, &.{ .STAR, .SLASH })) {
                const op = try stream.next();

                const right_result = try parse_unary(stream);

                switch (right_result) {
                    .ok => |rhs| {
                        var children = ArrayList(Expression).init(std.heap.page_allocator);
                        try children.append(lhs);
                        try children.append(rhs);

                        const factor_type: Operator = switch (op.type) {
                            .STAR => .multiply,
                            .SLASH => .divide,
                            else => return .{ .err = ParserError{
                                .err = error.UnexpectedToken,
                                .token = op,
                            } },
                        };

                        lhs = .{
                            .type = .{ .factor = factor_type },
                            .children = children,
                        };
                    },
                    .err => return right_result,
                }
            }

            return .{ .ok = lhs };
        },
        .err => return result,
    }
}

fn parse_unary(stream: *TokenStream) !ParserResult {
    if (match(stream, &.{ .MINUS, .BANG })) {
        const op = try stream.next();

        const right_result = try parse_unary(stream);

        switch (right_result) {
            .ok => |expr| {
                var children = ArrayList(Expression).init(std.heap.page_allocator);
                try children.append(expr);

                const unary_type: Operator = switch (op.type) {
                    .MINUS => .minus,
                    .BANG => .negate,
                    else => return .{ .err = ParserError{
                        .err = error.UnexpectedToken,
                        .token = op,
                    } },
                };

                return .{ .ok = .{
                    .type = .{ .unary = unary_type },
                    .children = children,
                } };
            },
            .err => return right_result,
        }
    }

    return parse_primary(stream);
}

fn parse_primary(stream: *TokenStream) !ParserResult {
    const current_token = try stream.next();

    const literal_type: Literal = switch (current_token.type) {
        .NIL => .nil,
        .SUPER => .super,
        .THIS => .this,
        .TRUE => .{ .bool = true },
        .FALSE => .{ .bool = false },
        .NUMBER => .{
            .number = std.fmt.parseFloat(f64, current_token.lexeme) catch return .{
                .err = ParserError{
                    .err = error.UnexpectedToken,
                    .token = current_token,
                },
            },
        },
        .STRING => .{ .string = current_token.literal },
        .IDENTIFIER => .{ .identifier = current_token.lexeme },
        .LEFT_PAREN => return parse_group(stream),
        else => return .{ .err = ParserError{
            .err = error.UnexpectedToken,
            .token = current_token,
        } },
    };

    return .{ .ok = .{
        .type = .{ .literal = literal_type },
    } };
}

fn parse_group(stream: *TokenStream) (std.mem.Allocator.Error)!ParserResult {
    const result = try parse_expression(stream);

    switch (result) {
        .ok => |expr| {
            if (consume(stream, .RIGHT_PAREN) catch false) {
                var expression_list = ArrayList(Expression).init(std.heap.page_allocator);
                try expression_list.append(expr);

                return .{ .ok = .{
                    .type = .grouping,
                    .children = expression_list,
                } };
            }
        },
        else => {},
    }

    return .{ .err = ParserError{
        .token = try stream.previous(),
        .err = error.UnexpectedToken,
    } };
}

fn match(stream: *TokenStream, expected: []const token.TokenType) bool {
    if (stream.at_end()) {
        return false;
    }

    const next_token = try stream.peek();

    for (expected) |token_type| {
        if (next_token.type == token_type) {
            return true;
        }
    }

    return false;
}

fn consume(stream: *TokenStream, expected: token.TokenType) !bool {
    if (match(stream, &.{expected})) {
        _ = try stream.next();
        return true;
    }

    return error.UnexpectedToken;
}
