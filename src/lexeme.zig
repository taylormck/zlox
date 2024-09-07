const std = @import("std");
const ArrayList = std.ArrayList;
const StaticStringMap = std.StaticStringMap;
const KeywordMap = StaticStringMap(Lexeme);

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

pub const And = Lexeme{
    .type = .AND,
    .lexeme = "and",
    .literal = "null",
};

pub const Class = Lexeme{
    .type = .CLASS,
    .lexeme = "class",
    .literal = "null",
};

pub const Else = Lexeme{
    .type = .ELSE,
    .lexeme = "else",
    .literal = "null",
};

pub const False = Lexeme{
    .type = .FALSE,
    .lexeme = "false",
    .literal = "null",
};

pub const For = Lexeme{
    .type = .FOR,
    .lexeme = "for",
    .literal = "null",
};

pub const Fun = Lexeme{
    .type = .FUN,
    .lexeme = "fun",
    .literal = "null",
};

pub const If = Lexeme{
    .type = .IF,
    .lexeme = "if",
    .literal = "null",
};

pub const Nil = Lexeme{
    .type = .NIL,
    .lexeme = "nil",
    .literal = "null",
};

pub const Or = Lexeme{
    .type = .OR,
    .lexeme = "or",
    .literal = "null",
};

pub const Print = Lexeme{
    .type = .PRINT,
    .lexeme = "print",
    .literal = "null",
};

pub const Return = Lexeme{
    .type = .RETURN,
    .lexeme = "return",
    .literal = "null",
};

pub const Super = Lexeme{
    .type = .SUPER,
    .lexeme = "super",
    .literal = "null",
};

pub const This = Lexeme{
    .type = .THIS,
    .lexeme = "this",
    .literal = "null",
};

pub const True = Lexeme{
    .type = .TRUE,
    .lexeme = "true",
    .literal = "null",
};

pub const Var = Lexeme{
    .type = .VAR,
    .lexeme = "var",
    .literal = "null",
};

pub const While = Lexeme{
    .type = .WHILE,
    .lexeme = "while",
    .literal = "null",
};
