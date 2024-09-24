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

    pub fn get(self: *Self, key: []const u8) !Value {
        if (self.map.get(key)) |val| {
            return val;
        } else if (self.parent) |parent| {
            return parent.get(key);
        }

        return error.NotFound;
    }

    pub fn put(self: *Self, key: []const u8, value: Value) !void {
        return self.map.put(key, value);
    }

    pub fn assign(self: *Self, key: []const u8, value: Value) !void {
        if (self.map.get(key)) |_| {
            return self.put(key, value);
        } else if (self.parent) |parent| {
            return parent.assign(key, value);
        }

        return error.NotFound;
    }
};
