const std = @import("std");
const ArrayList = std.ArrayList;
const Tuple = std.meta.Tuple;

const ScannerResults = Tuple(&.{
    ArrayList(Lexeme),
    ArrayList(ScannerError),
});

const TokenType = enum {
    // Single character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    STAR,

    // Potentially double character tokens
    EQUAL_EQUAL,
    EQUAL,

    // Double character tokens
    NEW_LINE,
    EOF,
};

const Lexeme = struct {
    type: TokenType,
    // TODO: add additional info, such as line number
    // or column number

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (self.type) {
            .LEFT_PAREN => {
                try writer.writeAll("LEFT_PAREN ( null");
            },
            .RIGHT_PAREN => {
                try writer.writeAll("RIGHT_PAREN ) null");
            },
            .LEFT_BRACE => {
                try writer.writeAll("LEFT_BRACE { null");
            },
            .RIGHT_BRACE => {
                try writer.writeAll("RIGHT_BRACE } null");
            },
            .COMMA => {
                try writer.writeAll("COMMA , null");
            },
            .DOT => {
                try writer.writeAll("DOT . null");
            },
            .MINUS => {
                try writer.writeAll("MINUS - null");
            },
            .PLUS => {
                try writer.writeAll("PLUS + null");
            },
            .SEMICOLON => {
                try writer.writeAll("SEMICOLON ; null");
            },
            .STAR => {
                try writer.writeAll("STAR * null");
            },
            .EQUAL_EQUAL => {
                try writer.writeAll("EQUAL_EQUAL == null");
            },
            .EQUAL => {
                try writer.writeAll("EQUAL = null");
            },
            .NEW_LINE => {
                try writer.writeAll("NEW_LINE null");
            },
            .EOF => {
                try writer.writeAll("EOF  null");
            },
        }
    }
};

const ScannerErrorType = enum {
    UNEXPECTED_CHARACTER,
};

const ScannerError = struct {
    line: usize,
    type: ScannerErrorType,
    token: []u8,

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (self.type) {
            .UNEXPECTED_CHARACTER => {
                try writer.print("[line {d}] Error: Unexpected character: {s}", .{ self.line, self.token });
            },
        }
    }
};

pub fn scan(input: []u8) !ScannerResults {
    var current: usize = 0;
    var current_line: usize = 1;

    var result = ArrayList(Lexeme).init(std.heap.page_allocator);
    var errors = ArrayList(ScannerError).init(std.heap.page_allocator);

    while (current < input.len) {
        switch (input[current]) {
            ' ', '\t' => {},
            '(' => {
                try result.append(Lexeme{ .type = .LEFT_PAREN });
            },
            ')' => {
                try result.append(Lexeme{ .type = .RIGHT_PAREN });
            },
            '{' => {
                try result.append(Lexeme{ .type = .LEFT_BRACE });
            },
            '}' => {
                try result.append(Lexeme{ .type = .RIGHT_BRACE });
            },
            ',' => {
                try result.append(Lexeme{ .type = .COMMA });
            },
            '.' => {
                try result.append(Lexeme{ .type = .DOT });
            },
            '-' => {
                try result.append(Lexeme{ .type = .MINUS });
            },
            '+' => {
                try result.append(Lexeme{ .type = .PLUS });
            },
            ';' => {
                try result.append(Lexeme{ .type = .SEMICOLON });
            },
            '*' => {
                try result.append(Lexeme{ .type = .STAR });
            },
            // This is the magic number for a line feed character
            10 => {
                try result.append(Lexeme{ .type = .NEW_LINE });
                current_line += 1;
            },
            '=' => {
                if (current + 1 >= input.len) {
                    try result.append(Lexeme{ .type = .EQUAL });
                }

                switch (input[current + 1]) {
                    '=' => {
                        try result.append(Lexeme{ .type = .EQUAL_EQUAL });
                        current += 1;
                    },
                    else => {
                        try result.append(Lexeme{ .type = .EQUAL });
                    },
                }
            },
            '\\' => {
                current += 1;
                switch (input[current]) {
                    'n', 'r' => {
                        try result.append(Lexeme{ .type = .NEW_LINE });
                        current_line += 1;
                    },
                    '0' => {
                        // We don't add the token here, because we add it
                        // after the loop.
                        break;
                    },
                    else => {
                        // TODO: print an error
                    },
                }
            },
            else => {
                try errors.append(ScannerError{
                    .line = current_line,
                    .type = .UNEXPECTED_CHARACTER,
                    .token = input[current .. current + 1],
                });
            },
        }

        current += 1;
    }

    // Always add an EOF token to the end
    try result.append(Lexeme{ .type = .EOF });

    return ScannerResults{ result, errors };
}
