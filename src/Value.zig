const std = @import("std");

pub const Value = union(enum) {
    number: f64,
    bool: bool,
    nil,
    string: []const u8,

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .number => |num| try writer.print("{d}", .{num}),
            .bool => |b| try writer.print("{}", .{b}),
            .nil => try writer.print("nil", .{}),
            .string => |s| try writer.print("{s}", .{s}),
        }
    }

    pub fn is_number(self: @This()) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }

    pub fn is_string(self: @This()) bool {
        return switch (self) {
            .string => true,
            else => false,
        };
    }

    pub fn is_same_type(self: @This(), other: @This()) bool {
        return switch (self) {
            .number => switch (other) {
                .number => true,
                else => false,
            },
            .bool => switch (other) {
                .bool => true,
                else => false,
            },
            .nil => switch (other) {
                .nil => true,
                else => false,
            },
            .string => switch (other) {
                .string => true,
                else => false,
            },
        };
    }
};
