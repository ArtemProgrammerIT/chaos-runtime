const std = @import("std");

pub const Value = union(enum) {
    Number: f64,
    String: []const u8,
    Bool: bool,
    Pointer: usize,
    Nil,

    pub fn toString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        switch (self) {
            .Number => |n| return try std.fmt.allocPrint(allocator, "{d}", .{n}),
            .String => |s| return try allocator.dupe(u8, s),
            .Bool => |b| return try allocator.dupe(u8, if (b) "true" else "false"),
            .Pointer => |p| return try std.fmt.allocPrint(allocator, "<ptr:{d}>", .{p}),
            .Nil => return try allocator.dupe(u8, "nil"),
        }
    }

    pub fn isTruthy(self: Value) bool {
        switch (self) {
            .Number => |n| return n != 0,
            .String => |s| return s.len > 0,
            .Bool => |b| return b,
            .Pointer => |p| return p != 0,
            .Nil => return false,
        }
    }

    pub fn asNumber(self: Value) f64 {
        switch (self) {
            .Number => |n| return n,
            .String => |s| return std.fmt.parseFloat(f64, s) catch 0,
            .Bool => |b| return if (b) 1 else 0,
            .Pointer => |p| return @floatFromInt(p),
            .Nil => return 0,
        }
    }

    pub fn asString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        switch (self) {
            .String => |s| return try allocator.dupe(u8, s),
            else => return try self.toString(allocator),
        }
    }
};