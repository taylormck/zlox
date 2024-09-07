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
    UNTERMINATED_STRING,
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
            .UNTERMINATED_STRING => {
                try writer.print("[line {d}] Error: Unterminated string.", .{self.line});
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
                const starting_line = current_line;
                var string_content = ArrayList(u8).init(std.heap.page_allocator);

                try string_content.append('"');
                current += 1;

                while (current < input.len) {
                    const current_char = input[current];
                    try string_content.append(current_char);

                    // NOTE: Increment the new line in the string
                    if (current_char == 10) {
                        current_line += 1;
                    }

                    if (current_char == '"') {
                        break;
                    }

                    current += 1;
                }

                if (current >= input.len) {
                    try errors.append(ScannerError{
                        .line = starting_line,
                        .type = .UNTERMINATED_STRING,
                        .token = "",
                    });
                    break;
                }

                const new_lexeme = lexeme.Lexeme{
                    .type = .STRING,
                    .lexeme = string_content.items,
                    .literal = string_content.items[1 .. string_content.items.len - 1],
                };

                try result.append(new_lexeme);
            },
            '0'...'9' => {
                var number_content = ArrayList(u8).init(std.heap.page_allocator);

                while (current < input.len and is_numeric(input[current])) {
                    try number_content.append(input[current]);
                    current += 1;
                }

                if (current < input.len and input[current] == '.') {
                    try number_content.append('.');
                    current += 1;

                    // Consume any remaining digits.
                    while (current < input.len and is_numeric(input[current])) {
                        try number_content.append(input[current]);
                        current += 1;
                    }
                }

                var number_literal = try number_content.clone();
                var has_decimal = false;

                // If there was no decimal, add it.
                for (number_literal.items) |c| {
                    if (c == '.') {
                        has_decimal = true;
                        break;
                    }
                }

                if (!has_decimal) {
                    try number_literal.append('.');
                }

                // If there were no remaining digits, add a zero.
                if (number_literal.items[number_literal.items.len - 1] == '.') {
                    try number_literal.append('0');
                }

                // NOTE: due to the look-ahead nature of the algorithm we use here,
                // we need to set the cursor back so that we don't accidentally
                // consume the first non-number character.
                current -= 1;

                const new_lexeme = lexeme.Lexeme{
                    .type = .NUMBER,
                    .lexeme = number_content.items,
                    .literal = number_literal.items,
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

fn is_numeric(c: u8) bool {
    return c >= '0' and c <= '9';
}
