const std = @import("std");
const ArrayList = std.ArrayList;

const Result = @import("../Result.zig").Result;

const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const parser = @import("parser.zig");
const match = parser.match;
const consume = parser.consume;
const ParseError = parser.ParseError;

const ExpressionType = union(enum) {
    literal: Literal,
    grouping,
    unary: Operator,
    factor: Operator,
    term: Operator,
    comparison: Operator,
    equality: Operator,
};

pub const Expression = struct {
    type: ExpressionType,
    children: ArrayList(Expression) = ArrayList(Expression).init(std.heap.page_allocator),

    pub fn deinit(self: *@This()) void {
        for (self.children.items) |exp| {
            exp.deinit();
        }
        self.children.deinit();
    }

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self.type) {
            .literal => |literal| try writer.print("{}", .{literal}),
            .grouping => {
                try writer.print("(group", .{});

                for (self.children.items) |exp| {
                    try writer.print(" {}", .{exp});
                }

                try writer.print(")", .{});
            },
            .unary, .factor, .term, .comparison, .equality => |op| {
                try writer.print("({}", .{op});
                for (self.children.items) |exp| {
                    try writer.print(" {}", .{exp});
                }
                try writer.print(")", .{});
            },
        }
    }
};

const ParserExpressionGrammarResult = Result(Expression, ParseError);
pub const ParseExpressionResult = Result(Expression, []ParseError);

pub fn parse_expression(stream: *TokenStream) !ParserExpressionGrammarResult {
    return parse_equality(stream);
}

fn parse_equality(stream: *TokenStream) !ParserExpressionGrammarResult {
    const result = try parse_comparison(stream);

    switch (result) {
        .ok => |expr| {
            var lhs = expr;

            while (match(stream, &.{ .EQUAL_EQUAL, .BANG_EQUAL })) {
                const op = stream.next() catch |err| return ParseError{
                    .type = err,
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
                            else => return .{ .err = ParseError{
                                .type = error.UnexpectedToken,
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

fn parse_comparison(stream: *TokenStream) !ParserExpressionGrammarResult {
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
                            else => return .{ .err = ParseError{
                                .type = error.UnexpectedToken,
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

fn parse_term(stream: *TokenStream) !ParserExpressionGrammarResult {
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
                            else => return .{ .err = ParseError{
                                .type = error.UnexpectedToken,
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

fn parse_factor(stream: *TokenStream) !ParserExpressionGrammarResult {
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
                            else => return .{ .err = ParseError{
                                .type = error.UnexpectedToken,
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

fn parse_unary(stream: *TokenStream) !ParserExpressionGrammarResult {
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
                    else => return .{ .err = ParseError{
                        .type = error.UnexpectedToken,
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

fn parse_primary(stream: *TokenStream) !ParserExpressionGrammarResult {
    const current_token = try stream.next();

    const literal_type: Literal = switch (current_token.type) {
        .NIL => .nil,
        .SUPER => .super,
        .THIS => .this,
        .TRUE => .{ .bool = true },
        .FALSE => .{ .bool = false },
        .NUMBER => .{
            .number = std.fmt.parseFloat(f64, current_token.lexeme) catch return .{
                .err = ParseError{
                    .type = error.UnexpectedToken,
                    .token = current_token,
                },
            },
        },
        .STRING => .{ .string = current_token.literal },
        .IDENTIFIER => .{ .identifier = current_token.lexeme },
        .LEFT_PAREN => return parse_group(stream),
        else => return .{ .err = ParseError{
            .type = error.UnexpectedToken,
            .token = current_token,
        } },
    };

    return .{ .ok = .{
        .type = .{ .literal = literal_type },
    } };
}

fn parse_group(stream: *TokenStream) (std.mem.Allocator.Error)!ParserExpressionGrammarResult {
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

    return .{ .err = ParseError{
        .token = try stream.previous(),
        .type = error.UnexpectedToken,
    } };
}
