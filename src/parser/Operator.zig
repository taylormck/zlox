const std = @import("std");

pub const Operator = union(enum) {
    minus,
    negate,
    multiply,
    divide,
    add,
    subtract,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    not_equal,

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
            .less => try writer.print("<", .{}),
            .less_equal => try writer.print("<=", .{}),
            .greater => try writer.print(">", .{}),
            .greater_equal => try writer.print(">=", .{}),
            .equal => try writer.print("==", .{}),
            .not_equal => try writer.print("!=", .{}),
        }
    }
};
