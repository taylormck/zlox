const std = @import("std");

const stream = @import("stream.zig");
const TokenStream = stream.TokenStream;

const Token = @import("token.zig").Token;
const Statement = @import("parser/statement.zig").Statement;
const Expression = @import("parser/expression.zig").Expression;

const scanner = @import("scanner.zig");
const parser = @import("parser/parser.zig");
const evaluater = @import("evaluate.zig");

pub fn main() !void {
    const command = try parse_args();
    switch (command) {
        .tokenize => |filename| _ = try tokenize(filename, true),
        .parse => |filename| _ = try parse(filename, true),
        .parse_statements => |filename| try parse_statements(filename, true),
        .evaluate => |filename| _ = try evaluate(filename, true),
        .run => |filename| _ = try run(filename),
    }
}

const Command = union(enum) {
    tokenize: []const u8,
    parse: []const u8,
    parse_statements: []const u8,
    evaluate: []const u8,
    run: []const u8,
};

fn parse_args() !Command {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    if (args.len < 3) {
        report_usage_error_and_quit();
    }

    const command = args[1];
    const filename = args[2];

    inline for (comptime std.meta.fieldNames(Command)) |field| {
        if (std.mem.eql(u8, command, field)) {
            return @unionInit(Command, field, filename);
        }
    }

    report_usage_error_and_quit();

    return error.InvalidCommand;
}

fn report_usage_error_and_quit() void {
    std.debug.print("Usage: ./zig-interpreter <tokenize|parse> <filename>\n", .{});
    std.process.exit(1);
}

fn tokenize(filename: []const u8, print: bool) !TokenStream {
    const file_contents = try std.fs.cwd().readFileAlloc(
        std.heap.page_allocator,
        filename,
        std.math.maxInt(usize),
    );
    defer std.heap.page_allocator.free(file_contents);

    const results = try scanner.scan(file_contents);

    const errors = results.errors;
    for (errors) |err| {
        try std.io.getStdErr().writer().print("{s}\n", .{err});
    }

    const tokens = results.tokens;
    if (print) {
        for (tokens) |token| {
            try std.io.getStdOut().writer().print("{s}\n", .{token});
        }
    }

    if (errors.len > 0) {
        std.process.exit(65);
    }

    return TokenStream.new(tokens);
}

fn parse(filename: []const u8, print: bool) !void {
    _ = try parse_expression(filename, print);
}

fn parse_expression(filename: []const u8, print: bool) !Expression {
    var tokens = try tokenize(filename, false);

    if (Expression.parse(&tokens)) |result| {
        switch (result) {
            .ok => |expr| {
                if (print) {
                    try std.io.getStdOut().writer().print("{s}\n", .{expr});
                }

                return expr;
            },

            .err => |err| {
                try std.io.getStdErr().writer().print("{s}\n", .{err});
                std.process.exit(65);
                return err.type;
            },
        }
    } else |err| {
        try std.io.getStdErr().writer().print("Unexpected error: {any}\n", .{err});
        std.process.exit(65);
        return err;
    }
}

fn parse_statements(filename: []const u8, print: bool) !void {
    var tokens = try tokenize(filename, false);

    while (!tokens.at_end() and !parser.match(&tokens, &.{.EOF})) {
        if (Statement.parse(&tokens)) |result| {
            switch (result) {
                .ok => |stmt| {
                    if (print) {
                        try std.io.getStdOut().writer().print("{s}\n", .{stmt});
                    }
                },
                .err => |err| {
                    try std.io.getStdErr().writer().print("{s}\n", .{err});
                    std.process.exit(65);
                },
            }
        } else |err| {
            try std.io.getStdErr().writer().print("Unexpected error: {any}\n", .{err});
            std.process.exit(65);
        }
    }
}

fn evaluate(filename: []const u8, print: bool) !void {
    const expr = try parse_expression(filename, false);

    switch (try evaluater.evaluate(expr)) {
        .ok => |result| if (print) {
            try std.io.getStdOut().writer().print("{s}\n", .{result});
        },
        .err => |err| {
            try std.io.getStdErr().writer().print("{s}\n", .{err});
            std.process.exit(70);
        },
    }
}

fn run(filename: []const u8) !void {
    _ = filename;
    // const statements = try parse_statements(filename, false);
    //
    // for (statements) |stmt| {
    //     stmt.eval() catch std.process.exit(70);
    // }
}

test {}
