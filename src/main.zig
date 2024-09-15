const std = @import("std");
const Token = @import("token.zig").Token;

const scanner = @import("scanner.zig");
const parser = @import("parser/parser.zig");

pub fn main() !void {
    const command = try parse_args();
    switch (command) {
        .tokenize => |filename| _ = try tokenize(filename, true),
        .parse => |filename| try parse(filename),
    }
}

const Command = union(enum) {
    tokenize: []const u8,
    parse: []const u8,
};

pub fn parse_args() !Command {
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

pub fn report_usage_error_and_quit() void {
    std.debug.print("Usage: ./zig-interpreter <tokenize|parse> <filename>\n", .{});
    std.process.exit(1);
}

pub fn tokenize(filename: []const u8, print: bool) ![]Token {
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

pub fn parse(filename: []const u8) !void {
    const tokens = try tokenize(filename, false);

    if (parser.parse(tokens)) |result| {
        switch (result) {
            .ok => |expr| try std.io.getStdOut().writer().print("{s}\n", .{expr}),
            .err => |errors| {
                for (errors) |err| {
                    try std.io.getStdErr().writer().print("{s}\n", .{err});
                }
                std.process.exit(65);
            },
        }
    } else |err| {
        try std.io.getStdErr().writer().print("Unexpected error: {any}\n", .{err});
        std.process.exit(65);
    }
}

test {}
