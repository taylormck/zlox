const std = @import("std");
const ArrayList = std.ArrayList;
const Tuple = std.meta.Tuple;

const ByteStream = @import("stream.zig").ByteStream;

const token = @import("token.zig");

const ScannerResults = struct {
    tokens: []token.Token,
    errors: []ScannerError,
};

pub fn scan(input: []const u8) !ScannerResults {
    var stream = ByteStream.new(input);

    var current_line: usize = 1;

    var tokens = ArrayList(token.Token).init(std.heap.page_allocator);
    var errors = ArrayList(ScannerError).init(std.heap.page_allocator);

    while (!stream.at_end()) scan_byte_loop: {
        const current_byte = try stream.next();

        switch (current_byte) {
            // NOTE: 9 is a horizontal tab
            ' ', 9 => {},
            // NOTE: 10 a line feed character
            10 => {
                current_line += 1;
            },
            '(' => try tokens.append(extend_token_with_line(token.LeftParen, current_line)),
            ')' => try tokens.append(extend_token_with_line(token.RightParen, current_line)),
            '{' => try tokens.append(extend_token_with_line(token.LeftBrace, current_line)),
            '}' => try tokens.append(extend_token_with_line(token.RightBrace, current_line)),
            ',' => try tokens.append(extend_token_with_line(token.Comma, current_line)),
            '.' => try tokens.append(extend_token_with_line(token.Dot, current_line)),
            '-' => try tokens.append(extend_token_with_line(token.Minus, current_line)),
            '+' => try tokens.append(extend_token_with_line(token.Plus, current_line)),
            ';' => try tokens.append(extend_token_with_line(token.Semicolon, current_line)),
            '*' => try tokens.append(extend_token_with_line(token.Star, current_line)),
            '=' => try process_or_equal(token.Equal, token.EqualEqual, &stream, &tokens, current_line),
            '!' => try process_or_equal(token.Bang, token.BangEqual, &stream, &tokens, current_line),
            '<' => try process_or_equal(token.Less, token.LessEqual, &stream, &tokens, current_line),
            '>' => try process_or_equal(token.Greater, token.GreaterEqual, &stream, &tokens, current_line),
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
                        break :scan_byte_loop;
                    }
                }

                const new_lexeme = token.Token{
                    .type = .STRING,
                    .lexeme = string_content.items,
                    .literal = string_content.items[1 .. string_content.items.len - 1],
                    .line = starting_line,
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
                    .line = current_line,
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
                        .line = current_line,
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

fn process_or_equal(
    base_token: token.Token,
    equal_token: token.Token,
    stream: *ByteStream,
    list: *ArrayList(token.Token),
    line: usize,
) !void {
    if (!stream.at_end() and try stream.peek() == '=') {
        try list.append(extend_token_with_line(equal_token, line));
        try stream.advance();
    } else {
        try list.append(extend_token_with_line(base_token, line));
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

fn extend_token_with_line(t: token.Token, line: usize) token.Token {
    return .{
        .type = t.type,
        .lexeme = t.lexeme,
        .line = line,
    };
}

const ScanErrorType = enum {
    UNEXPECTED_CHARACTER,
    UNTERMINATED_STRING,
};

const ScannerError = struct {
    line: usize,
    type: ScanErrorType,
    token: []const u8,

    pub fn format(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.type) {
            .UNEXPECTED_CHARACTER => {
                try writer.print(
                    "[line {d}] Error: Unexpected character: {s}",
                    .{ self.line, self.token },
                );
            },
            .UNTERMINATED_STRING => {
                try writer.print(
                    "[line {d}] Error: Unterminated string.",
                    .{self.line},
                );
            },
        }
    }
};

test "it should scan basic tokens" {
    const input = "(){},.-+;*=!<>";
    const output = try scan(input);

    try std.testing.expectEqual(0, output.errors.len);
    try std.testing.expectEqual(extend_token_with_line(token.LeftParen, 1), output.tokens[0]);
    try std.testing.expectEqual(extend_token_with_line(token.RightParen, 1), output.tokens[1]);
    try std.testing.expectEqual(extend_token_with_line(token.LeftBrace, 1), output.tokens[2]);
    try std.testing.expectEqual(extend_token_with_line(token.RightBrace, 1), output.tokens[3]);
    try std.testing.expectEqual(extend_token_with_line(token.Comma, 1), output.tokens[4]);
    try std.testing.expectEqual(extend_token_with_line(token.Dot, 1), output.tokens[5]);
    try std.testing.expectEqual(extend_token_with_line(token.Minus, 1), output.tokens[6]);
    try std.testing.expectEqual(extend_token_with_line(token.Plus, 1), output.tokens[7]);
    try std.testing.expectEqual(extend_token_with_line(token.Semicolon, 1), output.tokens[8]);
    try std.testing.expectEqual(extend_token_with_line(token.Star, 1), output.tokens[9]);
    try std.testing.expectEqual(extend_token_with_line(token.Equal, 1), output.tokens[10]);
    try std.testing.expectEqual(extend_token_with_line(token.Bang, 1), output.tokens[11]);
    try std.testing.expectEqual(extend_token_with_line(token.Less, 1), output.tokens[12]);
    try std.testing.expectEqual(extend_token_with_line(token.Greater, 1), output.tokens[13]);
}

test "it should update the line number when scanning new lines" {
    const input = ".\n.";
    const output = try scan(input);

    try std.testing.expectEqual(extend_token_with_line(token.Dot, 1), output.tokens[0]);
    try std.testing.expectEqual(extend_token_with_line(token.Dot, 2), output.tokens[1]);
}

test "it should scan a string" {
    const input = "\"test\"";
    const output = try scan(input);

    const expected_token = token.Token{
        .type = .STRING,
        .lexeme = "\"test\"",
        .literal = "test",
        .line = 1,
    };

    try std.testing.expectEqual(0, output.errors.len);
    try std.testing.expectEqualDeep(expected_token, output.tokens[0]);
}

test "it should update the line number after scanning a multiline string" {
    const input = ".\"test\ntest\".";
    const output = try scan(input);

    const expected_token = token.Token{
        .type = .STRING,
        .lexeme = "\"test\ntest\"",
        .literal = "test\ntest",
        .line = 1,
    };

    try std.testing.expectEqual(0, output.errors.len);
    try std.testing.expectEqual(extend_token_with_line(token.Dot, 1), output.tokens[0]);
    try std.testing.expectEqualDeep(expected_token, output.tokens[1]);
    try std.testing.expectEqual(extend_token_with_line(token.Dot, 2), output.tokens[2]);
}

test "it should scan integers" {
    const input = "69";
    const output = try scan(input);

    const expected_token = token.Token{
        .type = .NUMBER,
        .lexeme = "69",
        .literal = "69.0",
        .line = 1,
    };

    try std.testing.expectEqual(0, output.errors.len);
    try std.testing.expectEqualDeep(expected_token, output.tokens[0]);
}

test "it should scan floating point numbers" {
    const input = "69.420";
    const output = try scan(input);

    const expected_token = token.Token{
        .type = .NUMBER,
        .lexeme = "69.420",
        .literal = "69.42",
        .line = 1,
    };

    try std.testing.expectEqual(0, output.errors.len);
    try std.testing.expectEqualDeep(expected_token, output.tokens[0]);
}

test "it should scan identifiers" {
    const input = "apple BANANA _citrus double_donut ECCENTRIC_ECLAIR blaze420";
    const output = try scan(input);

    const expected_tokens = [_]token.Token{
        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "apple",
            .literal = "null",
            .line = 1,
        },

        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "BANANA",
            .literal = "null",
            .line = 1,
        },
        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "_citrus",
            .literal = "null",
            .line = 1,
        },
        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "double_donut",
            .literal = "null",
            .line = 1,
        },
        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "ECCENTRIC_ECLAIR",
            .literal = "null",
            .line = 1,
        },
        token.Token{
            .type = .IDENTIFIER,
            .lexeme = "blaze420",
            .literal = "null",
            .line = 1,
        },
    };

    try std.testing.expectEqual(0, output.errors.len);

    for (0..expected_tokens.len) |i| {
        try std.testing.expectEqualDeep(expected_tokens[i], output.tokens[i]);
    }
}

test "it should process equal tokens" {
    const input = "= == < <= > >=";
    const output = try scan(input);

    const expected_tokens = [_]token.Token{
        extend_token_with_line(token.Equal, 1),
        extend_token_with_line(token.EqualEqual, 1),
        extend_token_with_line(token.Less, 1),
        extend_token_with_line(token.LessEqual, 1),
        extend_token_with_line(token.Greater, 1),
        extend_token_with_line(token.GreaterEqual, 1),
    };

    try std.testing.expectEqual(0, output.errors.len);

    for (0..expected_tokens.len) |i| {
        try std.testing.expectEqualDeep(expected_tokens[i], output.tokens[i]);
    }
}
