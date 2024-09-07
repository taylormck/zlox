const std = @import("std");
const ArrayList = std.ArrayList;
const Tuple = std.meta.Tuple;

const lexeme = @import("lexeme.zig");

const ScannerResults = Tuple(&.{
    ArrayList(lexeme.Lexeme),
    ArrayList(ScannerError),
});

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

    var result = ArrayList(lexeme.Lexeme).init(std.heap.page_allocator);
    var errors = ArrayList(ScannerError).init(std.heap.page_allocator);

    while (current < input.len) {
        switch (input[current]) {
            // NOTE: 9 is a horizontal tab
            ' ', 9 => {},
            // NOTE: 10 a line feed character
            10 => {
                current_line += 1;
            },
            '(' => {
                try result.append(lexeme.LeftParen);
            },
            ')' => {
                try result.append(lexeme.RightParen);
            },
            '{' => {
                try result.append(lexeme.LeftBrace);
            },
            '}' => {
                try result.append(lexeme.RightBrace);
            },
            ',' => {
                try result.append(lexeme.Comma);
            },
            '.' => {
                try result.append(lexeme.Dot);
            },
            '-' => {
                try result.append(lexeme.Minus);
            },
            '+' => {
                try result.append(lexeme.Plus);
            },
            ';' => {
                try result.append(lexeme.Semicolon);
            },
            '*' => {
                try result.append(lexeme.Star);
            },
            '=' => {
                const look_ahead_index = current + 1;

                if (look_ahead_index >= input.len) {
                    try result.append(lexeme.Equal);
                    break;
                }

                switch (input[look_ahead_index]) {
                    '=' => {
                        try result.append(lexeme.EqualEqual);
                        current += 1;
                    },
                    else => {
                        try result.append(lexeme.Equal);
                    },
                }
            },
            '!' => {
                const look_ahead_index = current + 1;

                if (look_ahead_index >= input.len) {
                    try result.append(lexeme.Bang);
                    break;
                }

                switch (input[look_ahead_index]) {
                    '=' => {
                        try result.append(lexeme.BangEqual);
                        current += 1;
                    },
                    else => {
                        try result.append(lexeme.Bang);
                    },
                }
            },
            '<' => {
                const look_ahead_index = current + 1;

                if (look_ahead_index >= input.len) {
                    try result.append(lexeme.Less);
                    break;
                }

                switch (input[look_ahead_index]) {
                    '=' => {
                        try result.append(lexeme.LessEqual);
                        current += 1;
                    },
                    else => {
                        try result.append(lexeme.Less);
                    },
                }
            },
            '>' => {
                const look_ahead_index = current + 1;

                if (look_ahead_index >= input.len) {
                    try result.append(lexeme.Greater);
                    break;
                }

                switch (input[look_ahead_index]) {
                    '=' => {
                        try result.append(lexeme.GreaterEqual);
                        current += 1;
                    },
                    else => {
                        try result.append(lexeme.Greater);
                    },
                }
            },
            '/' => {
                const look_ahead_index = current + 1;

                if (look_ahead_index >= input.len) {
                    try result.append(lexeme.Slash);
                    break;
                }

                switch (input[look_ahead_index]) {
                    '/' => {
                        while (current < input.len and input[current] != 10) {
                            current += 1;
                        }
                        current_line += 1;
                    },
                    else => {
                        try result.append(lexeme.Slash);
                    },
                }
            },
            '"' => {
                var string_content = ArrayList(u8).init(std.heap.page_allocator);

                try string_content.append('"');
                current += 1;

                while (current < input.len) {
                    const current_char = input[current];
                    try string_content.append(current_char);
                    current += 1;

                    if (current_char == '"') {
                        break;
                    }
                }

                if (current >= input.len) {
                    // TODO: append error
                    break;
                }

                const new_lexeme = lexeme.Lexeme{
                    .type = .STRING,
                    .lexeme = string_content.items,
                    .literal = string_content.items[1 .. string_content.items.len - 1],
                };

                try result.append(new_lexeme);
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
    try result.append(lexeme.EndOfFile);

    return ScannerResults{ result, errors };
}
