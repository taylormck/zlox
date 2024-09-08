const std = @import("std");
const Token = @import("token.zig").Token;
const TokenStream = @import("stream.zig").TokenStream;

const Terminal = union(enum) {
    nil,
    bool: bool,
    eof,
    number: f64,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .nil => try writer.print("{s}", .{@tagName(self)}),
            .bool => |val| try writer.print("{}", .{val}),
            .number => |val| try writer.print("{d}", .{val}),
            else => {},
        }
    }
};

pub const Expression = union(enum) {
    terminal: Terminal,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .terminal => |terminal| try writer.print("{}", .{terminal}),
        }
    }
};

pub fn parse_expression(stream: *TokenStream) !?Expression {
    const next = try stream.next();

    const lhs = switch (next.type) {
        .NIL => Expression{ .terminal = .nil },
        .TRUE => Expression{ .terminal = .{ .bool = true } },
        .FALSE => Expression{ .terminal = .{ .bool = false } },
        .NUMBER => Expression{ .terminal = .{ .number = std.fmt.parseFloat(f64, next.lexeme) catch unreachable } },
        else => |token| std.debug.panic("Tried to parse unsupported token: {}", .{token}),
    };

    return lhs;
}
