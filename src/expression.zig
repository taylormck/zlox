const std = @import("std");
const ArrayList = std.ArrayList;
const Token = @import("token.zig").Token;
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
        }
    }
};

const ExpressionType = union(enum) {
    literal: Literal,
    grouping,
    unary: Operator,
    factor: Operator,
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
            .unary, .factor => |op| {
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
    const current_token = try stream.peek();

    if (current_token.type == .MINUS or current_token.type == .BANG) {
        const op = try stream.next();

        const child = try parse_unary(stream) orelse return error.UnexpectedToken;
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

pub fn parse_expression(stream: *TokenStream) !?Expression {
    return parse_unary(stream);
    // const current_token = try stream.next();

    // const lhs: Expression = switch (current_token.type) {
    //     .BANG => {
    //         const child = try parse_expression(stream) orelse return error.UnexpectedToken;
    //         var children = ArrayList(Expression).init(std.heap.page_allocator);
    //         try children.append(child);
    //
    //         return .{
    //             .type = .{ .unary = .negate },
    //             .children = children,
    //         };
    //     },
    //     .MINUS => {
    //         const child = try parse_expression(stream) orelse return error.UnexpectedToken;
    //         var children = ArrayList(Expression).init(std.heap.page_allocator);
    //         try children.append(child);
    //
    //         return .{
    //             .type = .{ .unary = .minus },
    //             .children = children,
    //         };
    //     },
    //     else => |token| std.debug.panic(
    //         "Tried to parse unsupported token: {}",
    //         .{token},
    //     ),
    // };

    // if (try stream.peek().type == .STAR) {
    //     // const op_token = try stream.next();
    //     _ = try stream.next();
    //     const rhs = try parse_expression(stream) orelse return error.UnexpectedToken;
    //
    //     var children = ArrayList(Expression).init(std.heap.page_allocator);
    //     try children.append(lhs);
    //     try children.append(rhs);
    //
    //     return .{
    //         .type = .{ .factor = .multiply },
    //         .children = children,
    //     };
    // } else {
    //     return lhs;
    // }
}

const ParserError = error{
    UnexpectedToken,
};
