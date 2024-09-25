const std = @import("std");
const ArrayList = std.ArrayList;

const Result = @import("../Result.zig").Result;

const Literal = @import("Literal.zig").Literal;
const Operator = @import("Operator.zig").Operator;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const expression = @import("expression.zig");
const Expression = expression.Expression;

const evaluate = @import("../evaluate.zig");
const Value = evaluate.Value;
const EvaluateResult = evaluate.EvaluateResult;

const parser = @import("parser.zig");
const match = parser.match;
const consume = parser.consume;
const ParseError = parser.ParseError;
const ParseErrorType = parser.ParseErrorType;

const Scope = @import("../Scope.zig").Scope;

const StatementType = union(enum) {
    block: []Statement,
    declaration: struct { name: []const u8, initializer: Expression },
    print: Expression,
    expression: Expression,
    if_stmt: struct { condition: Expression, branches: ArrayList(Statement) },
    while_stmt: struct { condition: Expression, branches: ArrayList(Statement) },
};

const StatementResult = Result(Statement, ParseError);
const StatementParseErrorSet = error{UnwrappedError} || std.mem.Allocator.Error || ParseErrorType;

pub const Statement = struct {
    type: StatementType,

    const Self = @This();

    pub fn eval(self: *const Self, scope: *Scope) !EvaluateResult {
        switch (self.type) {
            .if_stmt => |stmt| {
                switch (try evaluate.evaluate(stmt.condition, scope)) {
                    .ok => |condition_value| {
                        if (condition_value.is_truthy()) {
                            return stmt.branches.items[0].eval(scope);
                        } else if (stmt.branches.items.len > 1) {
                            return stmt.branches.items[1].eval(scope);
                        }
                    },
                    .err => |err| return .{ .err = err },
                }

                return .{ .ok = .nil };
            },
            .while_stmt => |stmt| {
                var should_repeat = true;

                while (should_repeat) {
                    switch (try evaluate.evaluate(stmt.condition, scope)) {
                        .ok => |condition_value| {
                            if (condition_value.is_truthy()) {
                                switch (try stmt.branches.items[0].eval(scope)) {
                                    .err => |err| return .{ .err = err },
                                    else => {},
                                }
                            } else {
                                should_repeat = false;
                            }
                        },
                        .err => return .{ .err = .{ .type = .{ .IncorrectType = "bool" } } },
                    }
                }

                return .{ .ok = .nil };
            },
            .block => |statements| {
                var block_scope = Scope.init(scope, scope.allocator);

                for (statements) |stmt| {
                    switch (try stmt.eval(&block_scope)) {
                        .ok => {},
                        .err => |err| return .{ .err = err },
                    }
                }

                return .{ .ok = .nil };
            },
            .declaration => |variable| {
                switch (try evaluate.evaluate(variable.initializer, scope)) {
                    .ok => |value| {
                        try scope.put(variable.name, value);
                        return .{ .ok = value };
                    },
                    .err => |err| {
                        return .{ .err = err };
                    },
                }
            },
            .print => |expr| {
                switch (try evaluate.evaluate(expr, scope)) {
                    .ok => |val| {
                        try std.io.getStdOut().writer().print("{s}\n", .{val});
                        return .{ .ok = .nil };
                    },
                    .err => |err| {
                        return .{ .err = err };
                    },
                }
            },
            .expression => |expr| {
                switch (try evaluate.evaluate(expr, scope)) {
                    .ok => return .{ .ok = .nil },
                    .err => |err| {
                        return .{ .err = err };
                    },
                }
            },
        }
    }

    pub fn format(
        self: *const Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self.type) {
            .block => |statements| {
                try writer.print("{{\n", .{});

                for (statements) |stmt| {
                    try writer.print("{s}\n", .{stmt});
                }

                try writer.print("}}", .{});
            },
            .declaration => |variable| try writer.print(
                "var {s} = {?s};",
                .{ variable.name, variable.initializer },
            ),
            .print => |expr| try writer.print("print {s};", .{expr}),
            .expression => |expr| try writer.print("{s};", .{expr}),
            .if_stmt => |stmt| {
                try writer.print("if {s}\n{{\n{s}\n}}", .{ stmt.condition, stmt.branches.items[0] });

                if (stmt.branches.items.len > 1) {
                    try writer.print("\nelse\n{{\n{s}\n}}", .{stmt.branches.items[1]});
                }
            },
            .while_stmt => |stmt| {
                try writer.print("while {s}\n{{\n{s}\n}}", .{ stmt.condition, stmt.branches.items[0] });
            },
        }
    }

    pub fn parse(stream: *TokenStream) !StatementResult {
        if (match(stream, &.{.IF})) {
            return try parse_if_stmt(stream);
        }

        if (match(stream, &.{.WHILE})) {
            return try parse_while_stmt(stream);
        }

        if (match(stream, &.{.LEFT_BRACE})) {
            return try parse_block(stream);
        }

        if (match(stream, &.{.VAR})) {
            return try parse_declaration(stream);
        }

        if (match(stream, &.{.PRINT})) {
            return try parse_print(stream);
        }

        return try parse_expression_statement(stream);
    }

    fn parse_if_stmt(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = try consume(stream, .IF);
        _ = try consume(stream, .LEFT_PAREN);

        const condition = switch (try Expression.parse(stream)) {
            .ok => |expr| expr,
            .err => |err| return .{ .err = err },
        };

        _ = try consume(stream, .RIGHT_PAREN);

        var branches = ArrayList(Statement).init(std.heap.page_allocator);
        switch (try Statement.parse(stream)) {
            .ok => |stmt| try branches.append(stmt),
            .err => |err| return .{ .err = err },
        }

        if (match(stream, &.{.ELSE})) {
            _ = try consume(stream, .ELSE);

            switch (try Statement.parse(stream)) {
                .ok => |stmt| try branches.append(stmt),
                .err => |err| return .{ .err = err },
            }
        }

        return .{ .ok = .{ .type = .{ .if_stmt = .{
            .condition = condition,
            .branches = branches,
        } } } };
    }

    fn parse_while_stmt(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = try consume(stream, .WHILE);
        _ = try consume(stream, .LEFT_PAREN);

        const condition = switch (try Expression.parse(stream)) {
            .ok => |expr| expr,
            .err => |err| return .{ .err = err },
        };

        _ = try consume(stream, .RIGHT_PAREN);

        var branches = ArrayList(Statement).init(std.heap.page_allocator);
        switch (try Statement.parse(stream)) {
            .ok => |stmt| try branches.append(stmt),
            .err => |err| return .{ .err = err },
        }

        return .{ .ok = .{ .type = .{ .while_stmt = .{
            .condition = condition,
            .branches = branches,
        } } } };
    }

    fn parse_block(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = try consume(stream, .LEFT_BRACE);

        var statements = ArrayList(Statement).init(std.heap.page_allocator);

        while (!match(stream, &.{.RIGHT_BRACE})) {
            switch (try Self.parse(stream)) {
                .ok => |stmt| {
                    try statements.append(stmt);
                },
                .err => |err| return .{ .err = err },
            }
        }

        _ = try consume(stream, .RIGHT_BRACE);

        return .{ .ok = .{ .type = .{
            .block = statements.items,
        } } };
    }

    fn parse_declaration(stream: *TokenStream) !StatementResult {
        if (consume(stream, .VAR) catch false) {
            if (match(stream, &.{.IDENTIFIER})) {
                const name = try stream.next();

                var initializer: Expression = .{ .type = .{ .literal = .nil } };
                if (consume(stream, .EQUAL) catch false) {
                    const result = try Expression.parse(stream);

                    switch (result) {
                        .ok => |expr| {
                            initializer = expr;
                        },
                        .err => |err| {
                            return .{ .err = err };
                        },
                    }
                }

                if (consume(stream, .SEMICOLON) catch false) {
                    return .{ .ok = .{ .type = .{
                        .declaration = .{ .name = name.lexeme, .initializer = initializer },
                    } } };
                } else {
                    return .{ .err = .{
                        .type = error.UnexpectedToken,
                        .token = try stream.previous(),
                    } };
                }
            }
            return .{ .err = .{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            } };
        } else {
            return .{ .err = .{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            } };
        }
    }

    fn parse_print(stream: *TokenStream) !StatementResult {
        if (consume(stream, .PRINT) catch false) {
            const result = try Expression.parse(stream);

            switch (result) {
                .ok => |expr| {
                    if (consume(stream, .SEMICOLON) catch false) {
                        return .{ .ok = .{
                            .type = .{ .print = expr },
                        } };
                    } else {
                        return .{ .err = .{
                            .type = error.UnexpectedToken,
                            .token = try stream.previous(),
                        } };
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        } else {
            return .{ .err = .{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            } };
        }
    }

    fn parse_expression_statement(stream: *TokenStream) !StatementResult {
        if (Expression.parse(stream)) |result| {
            switch (result) {
                .ok => |expr| {
                    if (consume(stream, .SEMICOLON) catch false) {
                        return .{ .ok = .{
                            .type = .{ .expression = expr },
                        } };
                    } else {
                        return .{ .err = .{
                            .type = error.UnexpectedToken,
                            .token = try stream.previous(),
                        } };
                    }
                },
                .err => |err| {
                    return .{ .err = err };
                },
            }
        } else |err| {
            return err;
        }
    }
};
