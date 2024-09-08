const std = @import("std");
const Token = @import("token.zig").Token;
const TokenStream = @import("stream.zig").TokenStream;

const Terminal = union(enum) {
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
            .number => |val| try writer.print("{d}", .{val}),
            .identifier, .string => |val| try writer.print("{s}", .{val}),
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

    const lhs: Expression = switch (next.type) {
        .NIL => .{ .terminal = .nil },
        .SUPER => .{ .terminal = .super },
        .THIS => .{ .terminal = .this },
        .TRUE => .{ .terminal = .{ .bool = true } },
        .FALSE => .{ .terminal = .{ .bool = false } },
        .NUMBER => .{
            .terminal = .{
                .number = std.fmt.parseFloat(f64, next.lexeme) catch unreachable,
            },
        },
        .STRING => .{ .terminal = .{ .string = next.lexeme } },
        .IDENTIFIER => .{ .terminal = .{ .identifier = next.lexeme } },
        else => |token| std.debug.panic(
            "Tried to parse unsupported token: {}",
            .{token},
        ),
    };

    return lhs;
}
