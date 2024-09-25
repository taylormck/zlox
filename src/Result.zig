pub fn Result(comptime T: type, comptime Error: type) type {
    return union(enum) {
        ok: T,
        err: Error,

        const Self = @This();

        pub fn is_ok(self: Self) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }

        pub fn unwrap(self: Self) !T {
            return switch (self) {
                .ok => |t| t,
                .err => error.UnwrappedError,
            };
        }

        pub fn unwrap_err(self: Self) !Error {
            return switch (self) {
                .err => |e| e,
                .ok => error.UnwrappedError,
            };
        }

        pub fn ok(t: T) Self {
            return .{ .ok = t };
        }

        pub fn err(e: Error) Self {
            return .{ .err = e };
        }
    };
}
