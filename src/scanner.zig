const std = @import("std");
const ArrayList = std.ArrayList;

const TokenType = enum {
    // Single character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,

    // Double character tokens
    EOF,
    NEW_LINE,
};

const Lexeme = struct {
    type: TokenType,
    // TODO: add additional info, such as line number
    // or column number

    pub fn to_string(self: *const @This()) []const u8 {
        switch (self.type) {
            .LEFT_PAREN => {
                return "LEFT_PAREN ( null\n";
            },
            .RIGHT_PAREN => {
                return "RIGHT_PAREN ) null\n";
            },
            .LEFT_BRACE => {
                return "LEFT_BRACE { null\n";
            },
            .RIGHT_BRACE => {
                return "RIGHT_BRACE } null\n";
            },
            .EOF => {
                return "EOF  null\n";
            },
            .NEW_LINE => {
                return "NEW_LINE null\n";
            },
        }
    }
};

pub fn scan(input: []u8) !std.ArrayList(Lexeme) {
    var current: usize = 0;

    var result = ArrayList(Lexeme).init(std.heap.page_allocator);

    while (current < input.len) {
        switch (input[current]) {
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
            ' ', '\t' => {
                // no-op
            },
            '\\' => {
                current += 1;
                switch (input[current]) {
                    'n' => {
                        try result.append(Lexeme{ .type = .NEW_LINE });
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
                // TODO: print an error
            },
        }

        current += 1;
    }

    // Always add an EOF token to the end
    try result.append(Lexeme{ .type = .EOF });

    return result;
}
