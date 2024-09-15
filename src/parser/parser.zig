const std = @import("std");
const ArrayList = std.ArrayList;

const token = @import("../token.zig");
const Token = token.Token;
const TokenType = token.TokenType;
const TokenStream = @import("../stream.zig").TokenStream;

const Result = @import("../Result.zig").Result;

const expression = @import("expression.zig");

const statement = @import("statement.zig");
const ParseStatementResult = statement.ParseStatementResult;

pub fn parse(tokens: []const Token) !ParseStatementResult {
    var stream = TokenStream.new(tokens);

    if (statement.parse_statement(&stream)) |result| {
        // TODO: instead of returning directly, consider entering panic mode and
        // try parsing the rest of the file once we get to a spot we understand.
        return switch (result) {
            .ok => |stmt| .{
                .ok = stmt,
            },
            .err => |err| {
                var errors = ArrayList(ParseError).init(std.heap.page_allocator);
                try errors.append(err);

                return .{ .err = errors.items };
            },
        };
    } else |err| {
        return err;
    }
}

pub fn match(stream: *TokenStream, expected: []const token.TokenType) bool {
    if (stream.at_end()) {
        return false;
    }

    const next_token = try stream.peek();

    for (expected) |token_type| {
        if (next_token.type == token_type) {
            return true;
        }
    }

    return false;
}

pub fn consume(stream: *TokenStream, expected: token.TokenType) !bool {
    if (match(stream, &.{expected})) {
        _ = try stream.next();
        return true;
    }

    return error.UnexpectedToken;
}

const ParseErrorType = error{
    UnexpectedToken,
    UnexpectedError,
};

pub const ParseError = struct {
    type: ParseErrorType,
    token: Token,

    pub fn format(
        self: *const @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self.type) {
            error.UnexpectedToken => {
                try writer.print(
                    "[line {d}] Error at '{s}': Expect expression.",
                    .{ self.token.line, self.token.lexeme },
                );
            },
            error.UnexpectedError => {
                try writer.print("Unexpected error occurred.", .{});
            },
        }
    }
};
