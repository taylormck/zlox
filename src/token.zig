const std = @import("std");
const ArrayList = std.ArrayList;
const StaticStringMap = std.StaticStringMap;
const KeywordMap = StaticStringMap(Token);

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8 = "",
    literal: []const u8 = "null",
    line: usize = 0,

    const Self = @This();

    pub fn format(
        self: *const Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s} {s} {s}", .{
            @tagName(self.type),
            self.lexeme,
            self.literal,
        });
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
};

pub const RightParen = Token{
    .type = .RIGHT_PAREN,
    .lexeme = ")",
};

pub const LeftBrace = Token{
    .type = .LEFT_BRACE,
    .lexeme = "{",
};

pub const RightBrace = Token{
    .type = .RIGHT_BRACE,
    .lexeme = "}",
};

pub const Comma = Token{
    .type = .COMMA,
    .lexeme = ",",
};

pub const Dot = Token{
    .type = .DOT,
    .lexeme = ".",
};

pub const Minus = Token{
    .type = .MINUS,
    .lexeme = "-",
};

pub const Plus = Token{
    .type = .PLUS,
    .lexeme = "+",
};

pub const Semicolon = Token{
    .type = .SEMICOLON,
    .lexeme = ";",
};

pub const Star = Token{
    .type = .STAR,
    .lexeme = "*",
};

pub const EqualEqual = Token{
    .type = .EQUAL_EQUAL,
    .lexeme = "==",
};

pub const Equal = Token{
    .type = .EQUAL,
    .lexeme = "=",
};

pub const BangEqual = Token{
    .type = .BANG_EQUAL,
    .lexeme = "!=",
};

pub const Bang = Token{
    .type = .BANG,
    .lexeme = "!",
};

pub const GreaterEqual = Token{
    .type = .GREATER_EQUAL,
    .lexeme = ">=",
};

pub const Greater = Token{
    .type = .GREATER,
    .lexeme = ">",
};

pub const LessEqual = Token{
    .type = .LESS_EQUAL,
    .lexeme = "<=",
};

pub const Less = Token{
    .type = .LESS,
    .lexeme = "<",
};

pub const Slash = Token{
    .type = .SLASH,
    .lexeme = "/",
};

pub const EndOfFile = Token{
    .type = .EOF,
};

pub const And = Token{
    .type = .AND,
    .lexeme = "and",
};

pub const Class = Token{
    .type = .CLASS,
    .lexeme = "class",
};

pub const Else = Token{
    .type = .ELSE,
    .lexeme = "else",
};

pub const False = Token{
    .type = .FALSE,
    .lexeme = "false",
};

pub const For = Token{
    .type = .FOR,
    .lexeme = "for",
};

pub const Fun = Token{
    .type = .FUN,
    .lexeme = "fun",
};

pub const If = Token{
    .type = .IF,
    .lexeme = "if",
};

pub const Nil = Token{
    .type = .NIL,
    .lexeme = "nil",
};

pub const Or = Token{
    .type = .OR,
    .lexeme = "or",
};

pub const Print = Token{
    .type = .PRINT,
    .lexeme = "print",
};

pub const Return = Token{
    .type = .RETURN,
    .lexeme = "return",
};

pub const Super = Token{
    .type = .SUPER,
    .lexeme = "super",
};

pub const This = Token{
    .type = .THIS,
    .lexeme = "this",
};

pub const True = Token{
    .type = .TRUE,
    .lexeme = "true",
};

pub const Var = Token{
    .type = .VAR,
    .lexeme = "var",
};

pub const While = Token{
    .type = .WHILE,
    .lexeme = "while",
};
