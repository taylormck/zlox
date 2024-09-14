const std = @import("std");

pub const Literal = union(enum) {
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
