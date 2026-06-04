const std = @import("std");
const Value = @import("value.zig").Value;

pub const ChaosEngine = struct {
    prng: std.rand.DefaultPrng,
    func_hash: u64,

    pub fn init(seed: u64) ChaosEngine {
        return .{
            .prng = std.rand.DefaultPrng.init(seed),
            .func_hash = 0,
        };
    }

    pub fn setFuncHash(self: *ChaosEngine, name: []const u8) void {
        self.func_hash = hash(name);
    }

    pub fn randomInt(self: *ChaosEngine, min: i64, max: i64) i64 {
        return self.prng.random().intRangeAtMost(i64, min, max);
    }

    pub fn randomBool(self: *ChaosEngine) bool {
        return self.prng.random().boolean();
    }

    pub fn chaosAdd(self: *ChaosEngine, left: Value, right: Value) Value {
        const roll = self.prng.random().intRangeAtMost(u8, 0, 100);
        const allocator = std.heap.page_allocator;
        if (roll < 60) {
            const mode = self.func_hash % 3;
            if (mode == 0) {
                return .{ .Number = left.asNumber() + right.asNumber() };
            } else if (mode == 1) {
                const l = left.asString(allocator) catch "";
                const r = right.asString(allocator) catch "";
                defer allocator.free(l);
                defer allocator.free(r);
                const concat = std.fmt.allocPrint(allocator, "{s}{s}", .{ l, r }) catch "";
                return .{ .String = concat };
            } else {
                const sum = left.asNumber() + right.asNumber();
                const s = std.fmt.allocPrint(allocator, "{d}", .{sum}) catch "";
                return .{ .String = s };
            }
        } else if (roll < 80) {
            return switch (left) {
                .String => .{ .Number = left.asNumber() + right.asNumber() },
                else => blk: {
                    const l = @as(i64, @intFromFloat(left.asNumber()));
                    const r = @as(i64, @intFromFloat(right.asNumber()));
                    const s = std.fmt.allocPrint(allocator, "{d}{d}", .{ l, r }) catch "";
                    break :blk .{ .String = s };
                },
            };
        } else {
            return switch (right) {
                .String => .{ .Number = left.asNumber() + right.asNumber() },
                else => blk: {
                    const l = @as(i64, @intFromFloat(left.asNumber()));
                    const r = @as(i64, @intFromFloat(right.asNumber()));
                    const s = std.fmt.allocPrint(allocator, "{d}{d}", .{ l, r }) catch "";
                    break :blk .{ .String = s };
                },
            };
        }
    }

    pub fn chaosMul(self: *ChaosEngine, left: Value, right: Value) Value {
        const roll = self.prng.random().intRangeAtMost(u8, 0, 100);
        if (roll < 33) {
            return .{ .Number = left.asNumber() * right.asNumber() };
        } else if (roll < 66) {
            const allocator = std.heap.page_allocator;
            const l = @as(i64, @intFromFloat(left.asNumber()));
            const r = @as(i64, @intFromFloat(right.asNumber()));
            const s = std.fmt.allocPrint(allocator, "{d}{d}", .{ l, r }) catch "";
            return .{ .String = s };
        } else {
            return .{ .Number = left.asNumber() + right.asNumber() };
        }
    }

    pub fn chaosSub(self: *ChaosEngine, left: Value, right: Value) Value {
        const roll = self.prng.random().intRangeAtMost(u8, 0, 100);
        if (roll < 50) {
            return .{ .Number = left.asNumber() - right.asNumber() };
        } else {
            const allocator = std.heap.page_allocator;
            const l = @as(i64, @intFromFloat(left.asNumber()));
            const r = @as(i64, @intFromFloat(right.asNumber()));
            const s = std.fmt.allocPrint(allocator, "{d}{d}", .{ l, r }) catch "";
            return .{ .String = s };
        }
    }

    pub fn chaosDiv(self: *ChaosEngine, left: Value, right: Value) Value {
        const r = right.asNumber();
        if (r == 0) return .{ .Number = 0 };
        const roll = self.prng.random().intRangeAtMost(u8, 0, 100);
        if (roll < 50) {
            return .{ .Number = left.asNumber() / r };
        } else {
            const allocator = std.heap.page_allocator;
            const l = @as(i64, @intFromFloat(left.asNumber()));
            const rr = @as(i64, @intFromFloat(r));
            const s = std.fmt.allocPrint(allocator, "{d}{d}", .{ l, rr }) catch "";
            return .{ .String = s };
        }
    }

    pub fn chaosCompare(self: *ChaosEngine, left: Value, right: Value) bool {
        if (self.randomBool()) {
            return left.asNumber() == right.asNumber();
        } else {
            return self.randomBool();
        }
    }

    fn hash(name: []const u8) u64 {
        var h: u64 = 5381;
        for (name) |c| {
            h = ((h << 5) + h) + c;
        }
        return h;
    }
};