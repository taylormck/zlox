const std = @import("std");

const scanner = @import("scanner.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: ./your_program.sh tokenize <filename>\n", .{});
        std.process.exit(1);
    }

    const command = args[1];
    const filename = args[2];

    if (!std.mem.eql(u8, command, "tokenize")) {
        std.debug.print("Unknown command: {s}\n", .{command});
        std.process.exit(1);
    }

    const file_contents = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, filename, std.math.maxInt(usize));
    defer std.heap.page_allocator.free(file_contents);

    const results = try scanner.scan(file_contents);

    const errors = results[1];
    for (errors.items) |err| {
        try std.io.getStdErr().writer().print("{s}\n", .{err});
    }

    const lexemes = results[0];

    for (lexemes.items) |lexeme| {
        try std.io.getStdOut().writer().print("{s}\n", .{lexeme});
    }

    if (errors.items.len > 0) {
        std.process.exit(65);
    }
}
