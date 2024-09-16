const std = @import("std");
const Token = @import("token.zig").Token;
const Statement = @import("parser/statement.zig").Statement;
const expression = @import("parser/expression.zig");
const stream = @import("stream.zig");
const TokenStream = stream.TokenStream;

const scanner = @import("scanner.zig");
const parser = @import("parser/parser.zig");
const evaluater = @import("evaluate.zig");

pub fn main() !void {
    const command = try parse_args();
    switch (command) {
        .tokenize => |filename| _ = try tokenize(filename, true),
        .parse => |filename| _ = try parse(filename, true),
        .evaluate => |filename| _ = try evaluate(filename, true),
        .run => |filename| _ = try run(filename),
    }
}

const Command = union(enum) {
    tokenize: []const u8,
    parse: []const u8,
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

fn tokenize(filename: []const u8, print: bool) ![]Token {
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

    return tokens;
}

fn parse(filename: []const u8, print: bool) ![]Statement {
    const tokens = try tokenize(filename, false);

    if (parser.parse(tokens)) |result| {
        const errors = result.errors;
        const statements = result.statements;

        for (errors) |err| {
            try std.io.getStdErr().writer().print("{s}\n", .{err});
        }

        if (print) {
            for (statements) |stmt| {
                try std.io.getStdOut().writer().print("{s}\n", .{stmt});
            }
        }

        if (errors.len > 0) {
            std.process.exit(65);
        }

        return statements;
    } else |err| {
        try std.io.getStdErr().writer().print("Unexpected error: {any}\n", .{err});
        std.process.exit(65);
    }
}

fn evaluate(filename: []const u8, print: bool) !void {
    const tokens = try tokenize(filename, false);
    var token_stream = TokenStream.new(tokens);
    const parse_result = try expression.parse_expression(&token_stream);

    switch (parse_result) {
        .ok => |expr| {
            switch (try evaluater.evaluate(expr)) {
                .ok => |result| if (print) {
                    try std.io.getStdOut().writer().print("{s}\n", .{result});
                },
                .err => |err| {
                    try std.io.getStdErr().writer().print("{s}\n", .{err});
                    std.process.exit(70);
                },
            }
        },
        .err => |err| {
            try std.io.getStdErr().writer().print("Unexpected error: {any}\n", .{err});
            std.process.exit(70);
        },
    }
}

fn run(filename: []const u8) !void {
    const statements = try parse(filename, false);

    for (statements) |stmt| {
        try stmt.eval();
    }
}

test {}
