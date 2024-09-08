const Token = @import("token.zig").Token;
const TokenStream = @import("stream.zig").TokenStream;

const expression = @import("expression.zig");
const Expression = expression.Expression;

pub fn parse_tokens(tokens: []const Token) !?Expression {
    var stream = TokenStream.new(tokens);

    return expression.parse_expression(&stream);
}
