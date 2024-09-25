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
    assignment: []const u8,
    equality: Operator,
    logic_or,
    logic_and,
    comparison: Operator,
    term: Operator,
    factor: Operator,
    unary: Operator,
    literal: Literal,
    grouping,
};

const ExpressionResult = Result(Expression, ParseError);

pub const Expression = struct {
    type: ExpressionType,
    children: ArrayList(Expression) = ArrayList(Expression).init(std.heap.page_allocator),

    const Self = @This();

    pub fn deinit(self: *Self) void {
        for (self.children.items) |exp| {
            exp.deinit();
        }
        self.children.deinit();
    }

    pub fn format(
        self: Self,
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
            .assignment => |name| {
                try writer.print("{s} = {s}", .{ name, self.children.items[0] });
            },
            .logic_and => {
                try writer.print("{s} and {s}", .{ self.children.items[0], self.children.items[1] });
            },
            .logic_or => {
                try writer.print("{s} or {s}", .{ self.children.items[0], self.children.items[1] });
            },
        }
    }

    pub fn parse(stream: *TokenStream) !ExpressionResult {
        return parse_assignment(stream);
    }

    fn parse_assignment(stream: *TokenStream) !ExpressionResult {
        const result = try parse_logic_or(stream);

        if (!result.is_ok()) {
            return result;
        }

        const lhs = result.unwrap() catch unreachable;

        if (match(stream, &.{.EQUAL})) {
            _ = consume(stream, .EQUAL) catch unreachable;

            const right_result = try parse_assignment(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

            switch (lhs.type) {
                .literal => |literal| {
                    switch (literal) {
                        .identifier => |name| {
                            var children = ArrayList(Expression).init(std.heap.page_allocator);
                            try children.append(rhs);

                            return .{ .ok = .{
                                .type = .{ .assignment = name },
                                .children = children,
                            } };
                        },
                        else => return .{ .err = .{
                            .type = error.InvalidAssignmentTarget,
                            .token = try stream.previous(),
                        } },
                    }
                },
                else => return .{ .err = .{
                    .type = error.InvalidAssignmentTarget,
                    .token = try stream.previous(),
                } },
            }
        }

        return .{ .ok = lhs };
    }

    fn parse_logic_or(stream: *TokenStream) !ExpressionResult {
        const result = try parse_logic_and(stream);

        if (!result.is_ok()) {
            return result;
        }
        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{.OR})) {
            _ = consume(stream, .OR) catch unreachable;

            const right_result = try parse_logic_and(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

            var children = ArrayList(Expression).init(std.heap.page_allocator);
            try children.append(lhs);
            try children.append(rhs);

            lhs = .{
                .type = .logic_or,
                .children = children,
            };
        }

        return .{ .ok = lhs };
    }

    fn parse_logic_and(stream: *TokenStream) !ExpressionResult {
        const result = try parse_equality(stream);

        if (!result.is_ok()) {
            return result;
        }

        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{.AND})) {
            _ = consume(stream, .AND) catch unreachable;

            const right_result = try parse_equality(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

            var children = ArrayList(Expression).init(std.heap.page_allocator);
            try children.append(lhs);
            try children.append(rhs);

            lhs = .{
                .type = .logic_and,
                .children = children,
            };
        }

        return .{ .ok = lhs };
    }

    fn parse_equality(stream: *TokenStream) !ExpressionResult {
        const result = try parse_comparison(stream);

        if (!result.is_ok()) {
            return result;
        }

        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{ .EQUAL_EQUAL, .BANG_EQUAL })) {
            const op = stream.next() catch |err| return ParseError{
                .type = err,
                .token = lhs,
            };

            const right_result = try parse_comparison(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

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
        }

        return .{ .ok = lhs };
    }

    fn parse_comparison(stream: *TokenStream) !ExpressionResult {
        const result = try parse_term(stream);

        if (!result.is_ok()) {
            return result;
        }

        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{ .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL })) {
            const op = try stream.next();

            const right_result = try parse_term(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

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
        }

        return .{ .ok = lhs };
    }

    fn parse_term(stream: *TokenStream) !ExpressionResult {
        const result = try parse_factor(stream);

        if (!result.is_ok()) {
            return result;
        }

        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{ .PLUS, .MINUS })) {
            const op = try stream.next();
            const right_result = try parse_factor(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

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
        }

        return .{ .ok = lhs };
    }

    fn parse_factor(stream: *TokenStream) !ExpressionResult {
        const result = try parse_unary(stream);

        if (!result.is_ok()) {
            return result;
        }

        var lhs = result.unwrap() catch unreachable;

        while (match(stream, &.{ .STAR, .SLASH })) {
            const op = try stream.next();

            const right_result = try parse_unary(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const rhs = right_result.unwrap() catch unreachable;

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
        }

        return .{ .ok = lhs };
    }

    fn parse_unary(stream: *TokenStream) !ExpressionResult {
        if (match(stream, &.{ .MINUS, .BANG })) {
            const op = try stream.next();

            const right_result = try parse_unary(stream);

            if (!right_result.is_ok()) {
                return right_result;
            }

            const expr = right_result.unwrap() catch unreachable;
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
        }

        return parse_primary(stream);
    }

    fn parse_primary(stream: *TokenStream) !ExpressionResult {
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

    fn parse_group(stream: *TokenStream) error{ OutOfMemory, UnwrappedError }!ExpressionResult {
        const result = try Self.parse(stream);

        if (result.is_ok()) {
            const expr = result.unwrap() catch unreachable;

            if (consume(stream, .RIGHT_PAREN) catch false) {
                var expression_list = ArrayList(Expression).init(std.heap.page_allocator);
                try expression_list.append(expr);

                return .{ .ok = .{
                    .type = .grouping,
                    .children = expression_list,
                } };
            }
        }

        return .{ .err = ParseError{
            .token = try stream.previous(),
            .type = error.UnexpectedToken,
        } };
    }
};
