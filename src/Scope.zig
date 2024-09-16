const std = @import("std");
const Value = @import("Value.zig").Value;

pub const Scope = struct {
    const Self = @This();

    map: std.StringHashMap(Value),
    parent: ?*Self,
    allocator: std.mem.Allocator,

    pub fn init(
        parent: ?*Self,
        allocator: std.mem.Allocator,
    ) Self {
        const map = std.StringHashMap(Value).init(allocator);

        return .{
            .map = map,
            .parent = parent,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) !void {
        self.map.deinit();
    }

    pub fn has(self: *Self, key: []u8) bool {
        if (self.map.has(key)) {
            return true;
        }

        if (self.parent) |parent| {
            return parent.has(key);
        }

        return false;
    }

    pub fn get(self: *Self, key: []u8) !Value {
        if (self.map.has(key)) {
            return self.map.get(key);
        }

        if (self.parent) |parent| {
            return parent.get(key);
        }

        return error.NotFound;
    }
};
