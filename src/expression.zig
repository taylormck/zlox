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

pub const Expression = union(enum) {
    literal: Literal,
    grouping: []Expression,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .literal => |literal| try writer.print("{}", .{literal}),
            .grouping => |group| {
                try writer.print("(group", .{});

                for (group) |exp| {
                    try writer.print(" {}", .{exp});
                }

                try writer.print(")", .{});
            },
        }
    }
};

pub fn parse_expression(stream: *TokenStream) !?Expression {
    const current_token = try stream.next();

    const lhs: Expression = switch (current_token.type) {
        .NIL => .{ .literal = .nil },
        .SUPER => .{ .literal = .super },
        .THIS => .{ .literal = .this },
        .TRUE => .{ .literal = .{ .bool = true } },
        .FALSE => .{ .literal = .{ .bool = false } },
        .NUMBER => .{
            .literal = .{
                .number = std.fmt.parseFloat(f64, current_token.lexeme) catch unreachable,
            },
        },
        .STRING => .{ .literal = .{ .string = current_token.literal } },
        .IDENTIFIER => .{ .literal = .{ .identifier = current_token.lexeme } },
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

            return .{ .grouping = expression_list.items };
        },
        else => |token| std.debug.panic(
            "Tried to parse unsupported token: {}",
            .{token},
        ),
    };

    return lhs;
}
