const Token = @import("token.zig").Token;

pub fn Stream(comptime value_type: type) type {
    return struct {
        tokens: []const value_type,
        position: usize = 0,

        pub fn new(tokens: []const value_type) @This() {
            return .{ .tokens = tokens };
        }

        pub fn peek(self: *const @This()) !value_type {
            if (self.at_end()) {
                @panic("Tried to peek past end of stream");
            }

            return self.tokens[self.position];
        }

        pub fn next(self: *@This()) !value_type {
            const token = self.tokens[self.position];
            try self.advance();

            return token;
        }

        pub fn advance(self: *@This()) !void {
            if (self.at_end()) {
                @panic("Tried to peek past end of stream");
            }

            self.position += 1;
        }

        pub fn at_beginning(self: *const @This()) bool {
            return self.position == 0;
        }

        pub fn at_end(self: *const @This()) bool {
            return self.position >= self.tokens.len;
        }

        pub fn slice_prev(self: *const @This()) ![]const value_type {
            if (self.at_beginning()) {
                @panic("Tried to slice before the beginning of stream");
            }

            return self.tokens[self.position - 1 .. self.position];
        }
    };
}

pub const ByteStream = Stream(u8);
pub const TokenStream = Stream(Token);
