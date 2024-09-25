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
const EvaluateOk = EvaluateResult.ok;
const EvaluateErr = EvaluateResult.err;

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
    while_stmt: struct { condition: Expression, body: ArrayList(Statement) },
};

const StatementResult = Result(Statement, ParseError);
const StatementOk = StatementResult.ok;
const StatementErr = StatementResult.err;

const StatementParseErrorSet = error{UnwrappedError} || std.mem.Allocator.Error || ParseErrorType;

pub const Statement = struct {
    type: StatementType,

    const Self = @This();

    pub fn eval(self: *const Self, scope: *Scope) !EvaluateResult {
        switch (self.type) {
            .if_stmt => |stmt| {
                const result = try evaluate.evaluate(stmt.condition, scope);

                if (!result.is_ok()) {
                    const err = result.unwrap_err() catch unreachable;
                    return EvaluateErr(err);
                }

                const val = result.unwrap() catch unreachable;

                if (val.is_truthy()) {
                    return stmt.branches.items[0].eval(scope);
                } else if (stmt.branches.items.len > 1) {
                    return stmt.branches.items[1].eval(scope);
                }

                return EvaluateOk(.nil);
            },
            .while_stmt => |stmt| {
                while (true) {
                    const result = try evaluate.evaluate(stmt.condition, scope);

                    if (!result.is_ok()) {
                        return EvaluateErr(.{ .type = .{ .IncorrectType = "bool" } });
                    }

                    const val = result.unwrap() catch unreachable;

                    if (!val.is_truthy()) {
                        break;
                    }

                    const block_result = try stmt.body.items[0].eval(scope);

                    if (!block_result.is_ok()) {
                        const err = block_result.unwrap_err() catch unreachable;
                        return EvaluateErr(err);
                    }
                }

                return EvaluateOk(.nil);
            },
            .block => |statements| {
                var block_scope = Scope.init(scope, scope.allocator);

                for (statements) |stmt| {
                    switch (try stmt.eval(&block_scope)) {
                        .ok => {},
                        .err => |err| return EvaluateErr(err),
                    }
                }

                return EvaluateOk(.nil);
            },
            .declaration => |variable| {
                switch (try evaluate.evaluate(variable.initializer, scope)) {
                    .ok => |value| {
                        try scope.put(variable.name, value);
                        return EvaluateOk(value);
                    },
                    .err => |err| return EvaluateErr(err),
                }
            },
            .print => |expr| {
                switch (try evaluate.evaluate(expr, scope)) {
                    .ok => |val| {
                        try std.io.getStdOut().writer().print("{s}\n", .{val});
                        return EvaluateOk(.nil);
                    },
                    .err => |err| return EvaluateErr(err),
                }
            },
            .expression => |expr| {
                switch (try evaluate.evaluate(expr, scope)) {
                    .ok => return EvaluateOk(.nil),
                    .err => |err| return EvaluateErr(err),
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
                try writer.print("if {s}\n{s}\n", .{ stmt.condition, stmt.branches.items[0] });

                if (stmt.branches.items.len > 1) {
                    try writer.print("\nelse\n{s}\n", .{stmt.branches.items[1]});
                }
            },
            .while_stmt => |stmt| {
                try writer.print("while {s}\n{s}\n", .{ stmt.condition, stmt.body.items[0] });
            },
        }
    }

    pub fn parse(stream: *TokenStream) !StatementResult {
        if (match(stream, &.{.FOR})) {
            return try parse_for_stmt(stream);
        }

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

    fn parse_for_stmt(stream: *TokenStream) (std.mem.Allocator.Error || StatementParseErrorSet)!StatementResult {
        _ = consume(stream, .FOR) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        _ = consume(stream, .LEFT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        var initializer = Statement{ .type = .{ .expression = .{ .type = .{ .literal = .nil } } } };
        var condition = Expression{ .type = .{ .literal = .nil } };
        var update = Expression{ .type = .{ .literal = .nil } };

        if (!match(stream, &.{.SEMICOLON})) {
            const init_result = try Statement.parse(stream);

            if (!init_result.is_ok()) {
                return init_result;
            }

            initializer = init_result.unwrap() catch unreachable;
        }

        if (!match(stream, &.{.SEMICOLON})) {
            const condition_result = try Expression.parse(stream);

            if (!condition_result.is_ok()) {
                const err = condition_result.unwrap_err() catch unreachable;
                return StatementErr(err);
            }

            condition = condition_result.unwrap() catch unreachable;
        }

        _ = consume(stream, .SEMICOLON) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        if (!match(stream, &.{.RIGHT_PAREN})) {
            const update_result = try Expression.parse(stream);

            if (!update_result.is_ok()) {
                const err = update_result.unwrap_err() catch unreachable;
                return StatementErr(err);
            }

            update = update_result.unwrap() catch unreachable;
        }

        _ = consume(stream, .RIGHT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        const body_result = try Statement.parse(stream);

        if (!body_result.is_ok()) {
            const err = body_result.unwrap_err() catch unreachable;
            return StatementErr(err);
        }

        const inner_body = body_result.unwrap() catch unreachable;
        var outer_body_statements = ArrayList(Statement).init(std.heap.page_allocator);
        try outer_body_statements.append(inner_body);
        try outer_body_statements.append(Statement{ .type = .{ .expression = update } });
        const outer_body_statement = Statement{ .type = .{ .block = outer_body_statements.items } };
        var while_body = ArrayList(Statement).init(std.heap.page_allocator);
        try while_body.append(outer_body_statement);

        var statements = ArrayList(Statement).init(std.heap.page_allocator);
        try statements.append(initializer);
        try statements.append(Statement{ .type = .{ .while_stmt = .{
            .condition = condition,
            .body = while_body,
        } } });

        return StatementOk(.{ .type = .{ .block = statements.items } });
    }

    fn parse_if_stmt(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = consume(stream, .IF) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        _ = consume(stream, .LEFT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        const condition = switch (try Expression.parse(stream)) {
            .ok => |expr| expr,
            .err => |err| return StatementErr(err),
        };

        _ = consume(stream, .RIGHT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        var branches = ArrayList(Statement).init(std.heap.page_allocator);
        switch (try Statement.parse(stream)) {
            .ok => |stmt| try branches.append(stmt),
            .err => |err| return StatementErr(err),
        }

        if (match(stream, &.{.ELSE})) {
            _ = consume(stream, .ELSE) catch unreachable;

            switch (try Statement.parse(stream)) {
                .ok => |stmt| try branches.append(stmt),
                .err => |err| return StatementErr(err),
            }
        }

        return StatementOk(.{ .type = .{ .if_stmt = .{
            .condition = condition,
            .branches = branches,
        } } });
    }

    fn parse_while_stmt(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = consume(stream, .WHILE) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        _ = consume(stream, .LEFT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        const condition = switch (try Expression.parse(stream)) {
            .ok => |expr| expr,
            .err => |err| return .{ .err = err },
        };

        _ = consume(stream, .RIGHT_PAREN) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        var body = ArrayList(Statement).init(std.heap.page_allocator);

        switch (try Statement.parse(stream)) {
            .ok => |stmt| try body.append(stmt),
            .err => |err| return .{ .err = err },
        }

        return StatementOk(.{ .type = .{ .while_stmt = .{
            .condition = condition,
            .body = body,
        } } });
    }

    fn parse_block(stream: *TokenStream) StatementParseErrorSet!StatementResult {
        _ = consume(stream, .LEFT_BRACE) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        var statements = ArrayList(Statement).init(std.heap.page_allocator);

        while (!match(stream, &.{.RIGHT_BRACE})) {
            switch (try Self.parse(stream)) {
                .ok => |stmt| {
                    try statements.append(stmt);
                },
                .err => |err| return StatementErr(err),
            }
        }

        _ = consume(stream, .RIGHT_BRACE) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        return StatementOk(.{ .type = .{
            .block = statements.items,
        } });
    }

    fn parse_declaration(stream: *TokenStream) !StatementResult {
        _ = consume(stream, .VAR) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        if (!match(stream, &.{.IDENTIFIER})) {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        }

        const name = try stream.next();
        var initializer: Expression = .{ .type = .{ .literal = .nil } };

        if (consume(stream, .EQUAL) catch false) {
            initializer = switch (try Expression.parse(stream)) {
                .ok => |expr| expr,
                .err => |err| return StatementErr(err),
            };
        }

        _ = consume(stream, .SEMICOLON) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        return StatementOk(.{ .type = .{
            .declaration = .{ .name = name.lexeme, .initializer = initializer },
        } });
    }

    fn parse_print(stream: *TokenStream) !StatementResult {
        _ = consume(stream, .PRINT) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        const result = try Expression.parse(stream);

        if (!result.is_ok()) {
            const err = result.unwrap_err() catch unreachable;
            return StatementErr(err);
        }

        const expr = result.unwrap() catch unreachable;

        _ = consume(stream, .SEMICOLON) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        return StatementOk(.{
            .type = .{ .print = expr },
        });
    }

    fn parse_expression_statement(stream: *TokenStream) !StatementResult {
        const result = try Expression.parse(stream);

        if (!result.is_ok()) {
            const err = result.unwrap_err() catch unreachable;
            return StatementErr(err);
        }

        const expr = result.unwrap() catch unreachable;

        _ = consume(stream, .SEMICOLON) catch {
            return StatementErr(.{
                .type = error.UnexpectedToken,
                .token = try stream.previous(),
            });
        };

        return StatementOk(.{
            .type = .{ .expression = expr },
        });
    }
};
