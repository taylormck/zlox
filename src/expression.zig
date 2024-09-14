const std = @import("std");
const ArrayList = std.ArrayList;
const token = @import("token.zig");
const TokenStream = @import("stream.zig").TokenStream;

const Literal = union(enum) {
    nil,
    super,
    this,
    bool: bool,
    eof,
    number: f64,
    string: []const u8,
    identifier: []const u8,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .nil, .super, .this => try writer.print("{s}", .{@tagName(self)}),
            .bool => |val| try writer.print("{}", .{val}),
            .number => |val| {
                if (@mod(val, 1) == 0) {
                    try writer.print("{d}.0", .{val});
                } else {
                    try writer.print("{d}", .{val});
                }
            },
            .identifier, .string => |val| try writer.print("{s}", .{val}),
            else => {},
        }
    }
};

const Operator = union(enum) {
    minus,
    negate,
    multiply,
    divide,
    add,
    subtract,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .minus => try writer.print("-", .{}),
            .negate => try writer.print("!", .{}),
            .multiply => try writer.print("*", .{}),
            .divide => try writer.print("/", .{}),
            .add => try writer.print("+", .{}),
            .subtract => try writer.print("-", .{}),
        }
    }
};

const ExpressionType = union(enum) {
    literal: Literal,
    grouping,
    unary: Operator,
    factor: Operator,
    term: Operator,
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
            .unary, .factor, .term => |op| {
                try writer.print("({}", .{op});
                for (self.children.items) |exp| {
                    try writer.print(" {}", .{exp});
                }
                try writer.print(")", .{});
            },
        }
    }
};

fn parse_primary(stream: *TokenStream) (ParserError || std.mem.Allocator.Error)!?Expression {
    const current_token = try stream.next();

    const expr: Expression = switch (current_token.type) {
        .NIL => .{ .type = .{ .literal = .nil } },
        .SUPER => .{ .type = .{ .literal = .super } },
        .THIS => .{ .type = .{ .literal = .this } },
        .TRUE => .{ .type = .{ .literal = .{ .bool = true } } },
        .FALSE => .{ .type = .{ .literal = .{ .bool = false } } },
        .NUMBER => .{ .type = .{ .literal = .{
            .number = std.fmt.parseFloat(f64, current_token.lexeme) catch unreachable,
        } } },
        .STRING => .{ .type = .{ .literal = .{ .string = current_token.literal } } },
        .IDENTIFIER => .{ .type = .{ .literal = .{ .identifier = current_token.lexeme } } },
        .LEFT_PAREN => {
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
        },
        else => return ParserError.UnexpectedToken,
    };

    return expr;
}

fn parse_unary(stream: *TokenStream) !?Expression {
    if (match(stream, &.{ .MINUS, .BANG })) {
        const op = try stream.next();

        const child = try parse_unary(stream) orelse return ParserError.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(child);

        return switch (op.type) {
            .MINUS => .{ .type = .{ .unary = .minus }, .children = children },
            .BANG => .{ .type = .{ .unary = .negate }, .children = children },
            else => return ParserError.UnexpectedToken,
        };
    }

    return parse_primary(stream);
}

fn parse_factor(stream: *TokenStream) !?Expression {
    var lhs = try parse_unary(stream) orelse return null;

    while (match(stream, &.{ .STAR, .SLASH })) {
        const op = try stream.next();
        const rhs = try parse_unary(stream) orelse return error.UnexpectedToken;
        var children = ArrayList(Expression).init(std.heap.page_allocator);
        try children.append(lhs);
        try children.append(rhs);

        lhs = switch (op.type) {
            .STAR => .{ .type = .{ .factor = .multiply }, .children = children },
            .SLASH => .{ .type = .{ .factor = .divide }, .children = children },
            else => return ParserError.UnexpectedToken,
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

        lhs = switch (op.type) {
            .PLUS => .{ .type = .{ .factor = .add }, .children = children },
            .MINUS => .{ .type = .{ .factor = .subtract }, .children = children },
            else => return ParserError.UnexpectedToken,
        };
    }

    return lhs;
}

pub fn parse_expression(stream: *TokenStream) !?Expression {
    return parse_term(stream);
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

const ParserError = error{
    UnexpectedToken,
};
