const std = @import("std");
const Token = @import("token.zig").Token;
const TokenStream = @import("stream.zig").TokenStream;

const Terminal = union(enum) {
    nil,
    bool: bool,
    eof,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .nil => try writer.print("{s}", .{@tagName(self)}),
            .bool => |val| try writer.print("{}", .{val}),
            else => {},
        }
    }
};

const Expression = union(enum) {
    terminal: Terminal,
    poop,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .terminal => |terminal| try writer.print("{}", .{terminal}),
            else => {},
        }
    }
};

pub fn parse_tokens(tokens: []const Token) !?Expression {
    var stream = TokenStream.new(tokens);

    return parse_token(&stream);
}

fn parse_token(stream: *TokenStream) !?Expression {
    const next = try stream.next();

    const lhs = switch (next.type) {
        .NIL => Expression{ .terminal = .nil },
        .TRUE => Expression{ .terminal = .{ .bool = true } },
        .FALSE => Expression{ .terminal = .{ .bool = false } },
        else => |token| std.debug.panic("Tried to parse unsupported token: {}", .{token}),
    };

    return lhs;
}
