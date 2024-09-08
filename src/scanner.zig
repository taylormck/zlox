const std = @import("std");
const ArrayList = std.ArrayList;
const Tuple = std.meta.Tuple;

const ByteStream = @import("stream.zig").ByteStream;

const token = @import("token.zig");

const ScannerResults = struct {
    tokens: []token.Token,
    errors: []ScannerError,
};

pub fn scan(input: []u8) !ScannerResults {
    var stream = ByteStream.new(input);

    var current_line: usize = 1;

    var tokens = ArrayList(token.Token).init(std.heap.page_allocator);
    var errors = ArrayList(ScannerError).init(std.heap.page_allocator);

    while (!stream.at_end()) {
        const current_byte = try stream.next();

        switch (current_byte) {
            // NOTE: 9 is a horizontal tab
            ' ', 9 => {},
            // NOTE: 10 a line feed character
            10 => {
                current_line += 1;
            },
            '(' => try tokens.append(token.LeftParen),
            ')' => try tokens.append(token.RightParen),
            '{' => try tokens.append(token.LeftBrace),
            '}' => try tokens.append(token.RightBrace),
            ',' => try tokens.append(token.Comma),
            '.' => try tokens.append(token.Dot),
            '-' => try tokens.append(token.Minus),
            '+' => try tokens.append(token.Plus),
            ';' => try tokens.append(token.Semicolon),
            '*' => try tokens.append(token.Star),
            '=' => try process_or_equal(token.Equal, token.EqualEqual, &stream, &tokens),
            '!' => try process_or_equal(token.Bang, token.BangEqual, &stream, &tokens),
            '<' => try process_or_equal(token.Less, token.LessEqual, &stream, &tokens),
            '>' => try process_or_equal(token.Greater, token.GreaterEqual, &stream, &tokens),
            '/' => {
                if (!stream.at_end() and try stream.peek() == '/') {
                    while (try stream.next() != 10 and !stream.at_end()) {}
                    current_line += 1;
                } else {
                    try tokens.append(token.Slash);
                }
            },
            '"' => {
                const starting_line = current_line;
                var string_content = ArrayList(u8).init(std.heap.page_allocator);
                try string_content.append('"');

                while (true) {
                    const current_char = try stream.next();
                    try string_content.append(current_char);

                    // NOTE: Increment the new line in the string
                    if (current_char == 10) {
                        current_line += 1;
                    } else if (current_char == '"') {
                        break;
                    }

                    if (stream.at_end()) {
                        try errors.append(ScannerError{
                            .line = starting_line,
                            .type = .UNTERMINATED_STRING,
                            .token = "",
                        });
                        break;
                    }
                }

                const new_lexeme = token.Token{
                    .type = .STRING,
                    .lexeme = string_content.items,
                    .literal = string_content.items[1 .. string_content.items.len - 1],
                };

                try tokens.append(new_lexeme);
            },
            '0'...'9' => {
                var number_content = ArrayList(u8).init(std.heap.page_allocator);
                try number_content.append(current_byte);

                while (!stream.at_end() and is_numeric(try stream.peek())) {
                    try number_content.append(try stream.next());
                }

                if (!stream.at_end() and try stream.peek() == '.') {
                    try number_content.append('.');
                    try stream.advance();

                    // Consume any remaining digits.
                    while (!stream.at_end() and is_numeric(try stream.peek())) {
                        try number_content.append(try stream.next());
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

                // Pop off remaining zeroes.
                while (number_literal.items[number_literal.items.len - 1] == '0') {
                    _ = number_literal.pop();
                }

                // If there were no remaining digits, add a zero.
                if (number_literal.items[number_literal.items.len - 1] == '.') {
                    try number_literal.append('0');
                }

                const new_lexeme = token.Token{
                    .type = .NUMBER,
                    .lexeme = number_content.items,
                    .literal = number_literal.items,
                };

                try tokens.append(new_lexeme);
            },
            'a'...'z', 'A'...'Z', '_' => {
                var identifier_content = ArrayList(u8).init(std.heap.page_allocator);
                try identifier_content.append(current_byte);

                while (!stream.at_end() and is_valid_identifier_char(try stream.peek())) {
                    try identifier_content.append(try stream.next());
                }

                if (token.keywords.has(identifier_content.items)) {
                    try tokens.append(token.keywords.get(identifier_content.items).?);
                } else {
                    const new_lexeme = token.Token{
                        .type = .IDENTIFIER,
                        .lexeme = identifier_content.items,
                        .literal = "null",
                    };

                    try tokens.append(new_lexeme);
                }
            },
            else => {
                try errors.append(ScannerError{
                    .line = current_line,
                    .type = .UNEXPECTED_CHARACTER,
                    .token = try stream.slice_prev(),
                });
            },
        }
    }

    // Always add an EOF token to the end
    try tokens.append(token.EndOfFile);

    return .{ .tokens = tokens.items, .errors = errors.items };
}

fn process_or_equal(base_token: token.Token, equal_token: token.Token, stream: *ByteStream, list: *ArrayList(token.Token)) !void {
    if (!stream.at_end() and try stream.peek() == '=') {
        try list.append(equal_token);
        try stream.advance();
    } else {
        try list.append(base_token);
    }
}

fn is_numeric(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn is_alphabetic(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn is_valid_identifier_char(c: u8) bool {
    return is_alphabetic(c) or is_numeric(c) or c == '_';
}

const ScanErrorType = enum {
    UNEXPECTED_CHARACTER,
    UNTERMINATED_STRING,
};

const ScannerError = struct {
    line: usize,
    type: ScanErrorType,
    token: []const u8,

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
