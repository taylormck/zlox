const std = @import("std");
const ArrayList = std.ArrayList;

pub const TokenType = enum {
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
    BANG_EQUAL,
    BANG,
    GREATER_EQUAL,
    GREATER,
    LESS_EQUAL,
    LESS,
    SLASH,

    // Double character tokens
    EOF,

    // Multi-character tokens
    STRING,
    NUMBER,
    IDENTIFIER,
};

pub const Lexeme = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: []const u8,

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} {s} {s}", .{ @tagName(self.type), self.lexeme, self.literal });
    }
};

pub const LeftParen = Lexeme{
    .type = .LEFT_PAREN,
    .lexeme = "(",
    .literal = "null",
};

pub const RightParen = Lexeme{
    .type = .RIGHT_PAREN,
    .lexeme = ")",
    .literal = "null",
};

pub const LeftBrace = Lexeme{
    .type = .LEFT_BRACE,
    .lexeme = "{",
    .literal = "null",
};

pub const RightBrace = Lexeme{
    .type = .RIGHT_BRACE,
    .lexeme = "}",
    .literal = "null",
};

pub const Comma = Lexeme{
    .type = .COMMA,
    .lexeme = ",",
    .literal = "null",
};

pub const Dot = Lexeme{
    .type = .DOT,
    .lexeme = ".",
    .literal = "null",
};

pub const Minus = Lexeme{
    .type = .MINUS,
    .lexeme = "-",
    .literal = "null",
};

pub const Plus = Lexeme{
    .type = .PLUS,
    .lexeme = "+",
    .literal = "null",
};

pub const Semicolon = Lexeme{
    .type = .SEMICOLON,
    .lexeme = ";",
    .literal = "null",
};

pub const Star = Lexeme{
    .type = .STAR,
    .lexeme = "*",
    .literal = "null",
};

pub const EqualEqual = Lexeme{
    .type = .EQUAL_EQUAL,
    .lexeme = "==",
    .literal = "null",
};

pub const Equal = Lexeme{
    .type = .EQUAL,
    .lexeme = "=",
    .literal = "null",
};

pub const BangEqual = Lexeme{
    .type = .BANG_EQUAL,
    .lexeme = "!=",
    .literal = "null",
};

pub const Bang = Lexeme{
    .type = .BANG,
    .lexeme = "!",
    .literal = "null",
};

pub const GreaterEqual = Lexeme{
    .type = .GREATER_EQUAL,
    .lexeme = ">=",
    .literal = "null",
};

pub const Greater = Lexeme{
    .type = .GREATER,
    .lexeme = ">",
    .literal = "null",
};

pub const LessEqual = Lexeme{
    .type = .LESS_EQUAL,
    .lexeme = "<=",
    .literal = "null",
};

pub const Less = Lexeme{
    .type = .LESS,
    .lexeme = "<",
    .literal = "null",
};

pub const Slash = Lexeme{
    .type = .SLASH,
    .lexeme = "/",
    .literal = "null",
};

pub const EndOfFile = Lexeme{ .type = .EOF, .lexeme = "", .literal = "null" };
