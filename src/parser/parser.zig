const std = @import("std");
const ArrayList = std.ArrayList;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const expression = @import("expression.zig");
const Expression = expression.Expression;
const ExpressionType = expression.ExpressionType;

const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const ParseTokensResults = struct {
    expression: Expression,
    errors: []ParserError,
};

const ParserError = error{
    UnexpectedToken,
};

pub fn parse_tokens(tokens: []const Token) !?Expression {
    var stream = TokenStream.new(tokens);

    return parse_expression(&stream);
}

fn parse_expression(stream: *TokenStream) !?Expression {
    return parse_equality(stream);
}

fn parse_equality(stream: *TokenStream) !?Expression {
    var lhs = try parse_comparison(stream) orelse return null;

    while (match(stream, &.{ .EQUAL_EQUAL, .BANG_EQUAL })) {
        const op = try stream.next();
        const rhs = try parse_comparison(stream) orelse return error.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(lhs);
        try children.append(rhs);

        const equality_type: Operator = switch (op.type) {
            .EQUAL_EQUAL => .equal,
            .BANG_EQUAL => .not_equal,
            else => return ParserError.UnexpectedToken,
        };

        lhs = .{
            .type = .{ .equality = equality_type },
            .children = children,
        };
    }

    return lhs;
}

fn parse_comparison(stream: *TokenStream) !?Expression {
    var lhs = try parse_term(stream) orelse return null;

    while (match(stream, &.{ .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL })) {
        const op = try stream.next();
        const rhs = try parse_term(stream) orelse return error.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(lhs);
        try children.append(rhs);

        const comparison_type: Operator = switch (op.type) {
            .LESS => .less,
            .LESS_EQUAL => .less_equal,
            .GREATER => .greater,
            .GREATER_EQUAL => .greater_equal,
            else => return ParserError.UnexpectedToken,
        };

        lhs = .{
            .type = .{ .comparison = comparison_type },
            .children = children,
        };
    }

    return lhs;
}

fn parse_term(stream: *TokenStream) !?Expression {
    var lhs = try parse_factor(stream) orelse return null;

    while (match(stream, &.{ .PLUS, .MINUS })) {
        const op = try stream.next();
        const rhs = try parse_factor(stream) orelse return error.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(lhs);
        try children.append(rhs);

        const term_type: Operator = switch (op.type) {
            .PLUS => .add,
            .MINUS => .subtract,
            else => return ParserError.UnexpectedToken,
        };

        lhs = .{
            .type = .{ .term = term_type },
            .children = children,
        };
    }

    return lhs;
}

fn parse_factor(stream: *TokenStream) !?Expression {
    var lhs = try parse_unary(stream) orelse return null;

    while (match(stream, &.{ .STAR, .SLASH })) {
        const op = try stream.next();
        const rhs = try parse_unary(stream) orelse return error.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(lhs);
        try children.append(rhs);

        const factor_type: Operator = switch (op.type) {
            .STAR => .multiply,
            .SLASH => .divide,
            else => return ParserError.UnexpectedToken,
        };

        lhs = .{
            .type = .{ .factor = factor_type },
            .children = children,
        };
    }

    return lhs;
}

fn parse_unary(stream: *TokenStream) !?Expression {
    if (match(stream, &.{ .MINUS, .BANG })) {
        const op = try stream.next();

        const child = try parse_unary(stream) orelse return ParserError.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(child);

        const unary_type: Operator = switch (op.type) {
            .MINUS => .minus,
            .BANG => .negate,
            else => return ParserError.UnexpectedToken,
        };

        return .{
            .type = .{ .unary = unary_type },
            .children = children,
        };
    }

    return parse_primary(stream);
}

fn parse_primary(stream: *TokenStream) (ParserError || std.mem.Allocator.Error)!?Expression {
    const current_token = try stream.next();

    const literal_type: Literal = switch (current_token.type) {
        .NIL => .nil,
        .SUPER => .super,
        .THIS => .this,
        .TRUE => .{ .bool = true },
        .FALSE => .{ .bool = false },
        .NUMBER => .{
            .number = std.fmt.parseFloat(f64, current_token.lexeme) catch unreachable,
        },
        .STRING => .{ .string = current_token.literal },
        .IDENTIFIER => .{ .identifier = current_token.lexeme },
        .LEFT_PAREN => return parse_group(stream),
        else => return ParserError.UnexpectedToken,
    };

    return .{
        .type = .{ .literal = literal_type },
    };
}

fn parse_group(stream: *TokenStream) !?Expression {
    var expression_list = ArrayList(Expression).init(std.heap.page_allocator);

    while (!stream.at_end()) {
        const next_token = try stream.peek();

        switch (next_token.type) {
            .RIGHT_PAREN => {
                try stream.advance();
                break;
            },
            else => {
                const next_exp = try parse_expression(stream) orelse unreachable;
                try expression_list.append(next_exp);
            },
        }

        if (next_token.type != .RIGHT_PAREN) {
            // TODO: report parser error
        }
    }

    return .{
        .type = .grouping,
        .children = expression_list,
    };
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
