const std = @import("std");
const ArrayList = std.ArrayList;
const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const ExpressionType = union(enum) {
    literal: Literal,
    grouping,
    unary: Operator,
    factor: Operator,
    term: Operator,
    comparison: Operator,
    equality: Operator,
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
            .unary, .factor, .term, .comparison, .equality => |op| {
                try writer.print("({}", .{op});
                for (self.children.items) |exp| {
                    try writer.print(" {}", .{exp});
                }
                try writer.print(")", .{});
            },
        }
    }
};
