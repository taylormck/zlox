pub fn Result(comptime T: type, comptime Error: type) type {
    return union(enum) {
        ok: T,
        err: Error,
    };
}
