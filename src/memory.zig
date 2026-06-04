const std = @import("std");
const Value = @import("value.zig").Value;

pub const MemoryBlock = struct {
    data: []u8,
    freed: bool,
};

pub const MemoryManager = struct {
    blocks: std.AutoHashMap(usize, MemoryBlock),
    next_ptr: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MemoryManager {
        return .{
            .blocks = std.AutoHashMap(usize, MemoryBlock).init(allocator),
            .next_ptr = 1000,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MemoryManager) void {
        var it = self.blocks.valueIterator();
        while (it.next()) |block| {
            self.allocator.free(block.data);
        }
        self.blocks.deinit();
    }

    pub fn alloc(self: *MemoryManager, size: usize) !usize {
        const ptr = self.next_ptr;
        const data = try self.allocator.alloc(u8, size);
        @memset(data, 0);
        try self.blocks.put(ptr, .{ .data = data, .freed = false });
        self.next_ptr += 1;
        return ptr;
    }

    pub fn write(self: *MemoryManager, ptr: usize, offset: usize, value: []const u8) void {
        if (self.blocks.getPtr(ptr)) |block| {
            if (offset < block.data.len) {
                const end = @min(offset + value.len, block.data.len);
                @memcpy(block.data[offset..end], value[0..end - offset]);
            }
        }
    }

    pub fn read(self: *MemoryManager, ptr: usize, offset: usize) ?[]const u8 {
        if (self.blocks.get(ptr)) |block| {
            if (offset < block.data.len) {
                var end = offset;
                while (end < block.data.len and block.data[end] != 0) : (end += 1) {}
                if (end > offset) {
                    return self.allocator.dupe(u8, block.data[offset..end]) catch null;
                }
            }
        }
        return null;
    }

    pub fn free(self: *MemoryManager, ptr: usize) void {
        if (self.blocks.getPtr(ptr)) |block| {
            block.freed = true;
        }
    }

    pub fn isFreed(self: *MemoryManager, ptr: usize) bool {
        if (self.blocks.get(ptr)) |block| {
            return block.freed;
        }
        return true;
    }
};