const std = @import("std");
const ArrayList = std.ArrayList;
const StaticStringMap = std.StaticStringMap;
const KeywordMap = StaticStringMap(Token);

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: []const u8,

    pub fn format(self: *const @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} {s} {s}", .{ @tagName(self.type), self.lexeme, self.literal });
    }
};

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

    // Reserved words
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
};

pub const keywords = KeywordMap.initComptime(&.{
    .{ "and", And },
    .{ "class", Class },
    .{ "else", Else },
    .{ "false", False },
    .{ "for", For },
    .{ "fun", Fun },
    .{ "if", If },
    .{ "nil", Nil },
    .{ "or", Or },
    .{ "print", Print },
    .{ "return", Return },
    .{ "super", Super },
    .{ "this", This },
    .{ "true", True },
    .{ "var", Var },
    .{ "while", While },
});

pub const LeftParen = Token{
    .type = .LEFT_PAREN,
    .lexeme = "(",
    .literal = "null",
};

pub const RightParen = Token{
    .type = .RIGHT_PAREN,
    .lexeme = ")",
    .literal = "null",
};

pub const LeftBrace = Token{
    .type = .LEFT_BRACE,
    .lexeme = "{",
    .literal = "null",
};

pub const RightBrace = Token{
    .type = .RIGHT_BRACE,
    .lexeme = "}",
    .literal = "null",
};

pub const Comma = Token{
    .type = .COMMA,
    .lexeme = ",",
    .literal = "null",
};

pub const Dot = Token{
    .type = .DOT,
    .lexeme = ".",
    .literal = "null",
};

pub const Minus = Token{
    .type = .MINUS,
    .lexeme = "-",
    .literal = "null",
};

pub const Plus = Token{
    .type = .PLUS,
    .lexeme = "+",
    .literal = "null",
};

pub const Semicolon = Token{
    .type = .SEMICOLON,
    .lexeme = ";",
    .literal = "null",
};

pub const Star = Token{
    .type = .STAR,
    .lexeme = "*",
    .literal = "null",
};

pub const EqualEqual = Token{
    .type = .EQUAL_EQUAL,
    .lexeme = "==",
    .literal = "null",
};

pub const Equal = Token{
    .type = .EQUAL,
    .lexeme = "=",
    .literal = "null",
};

pub const BangEqual = Token{
    .type = .BANG_EQUAL,
    .lexeme = "!=",
    .literal = "null",
};

pub const Bang = Token{
    .type = .BANG,
    .lexeme = "!",
    .literal = "null",
};

pub const GreaterEqual = Token{
    .type = .GREATER_EQUAL,
    .lexeme = ">=",
    .literal = "null",
};

pub const Greater = Token{
    .type = .GREATER,
    .lexeme = ">",
    .literal = "null",
};

pub const LessEqual = Token{
    .type = .LESS_EQUAL,
    .lexeme = "<=",
    .literal = "null",
};

pub const Less = Token{
    .type = .LESS,
    .lexeme = "<",
    .literal = "null",
};

pub const Slash = Token{
    .type = .SLASH,
    .lexeme = "/",
    .literal = "null",
};

pub const EndOfFile = Token{ .type = .EOF, .lexeme = "", .literal = "null" };

pub const And = Token{
    .type = .AND,
    .lexeme = "and",
    .literal = "null",
};

pub const Class = Token{
    .type = .CLASS,
    .lexeme = "class",
    .literal = "null",
};

pub const Else = Token{
    .type = .ELSE,
    .lexeme = "else",
    .literal = "null",
};

pub const False = Token{
    .type = .FALSE,
    .lexeme = "false",
    .literal = "null",
};

pub const For = Token{
    .type = .FOR,
    .lexeme = "for",
    .literal = "null",
};

pub const Fun = Token{
    .type = .FUN,
    .lexeme = "fun",
    .literal = "null",
};

pub const If = Token{
    .type = .IF,
    .lexeme = "if",
    .literal = "null",
};

pub const Nil = Token{
    .type = .NIL,
    .lexeme = "nil",
    .literal = "null",
};

pub const Or = Token{
    .type = .OR,
    .lexeme = "or",
    .literal = "null",
};

pub const Print = Token{
    .type = .PRINT,
    .lexeme = "print",
    .literal = "null",
};

pub const Return = Token{
    .type = .RETURN,
    .lexeme = "return",
    .literal = "null",
};

pub const Super = Token{
    .type = .SUPER,
    .lexeme = "super",
    .literal = "null",
};

pub const This = Token{
    .type = .THIS,
    .lexeme = "this",
    .literal = "null",
};

pub const True = Token{
    .type = .TRUE,
    .lexeme = "true",
    .literal = "null",
};

pub const Var = Token{
    .type = .VAR,
    .lexeme = "var",
    .literal = "null",
};

pub const While = Token{
    .type = .WHILE,
    .lexeme = "while",
    .literal = "null",
};
