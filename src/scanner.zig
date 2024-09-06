const std = @import("std");
const ArrayList = std.ArrayList;

const TokenType = enum {
    // Single character tokens
    LEFT_PAREN,
    RIGHT_PAREN,

    // Double character tokens
    EOF,
    NEW_LINE,
};

const Lexeme = struct {
    type: TokenType,
    // TODO: add additional info, such as line number
    // or column number
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
                        try result.append(Lexeme{ .type = .EOF });
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

    return result;
}
