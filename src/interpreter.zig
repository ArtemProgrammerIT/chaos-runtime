const std = @import("std");
const Value = @import("value.zig").Value;
const Expr = @import("ast.zig").Expr;
const Stmt = @import("ast.zig").Stmt;
const ChaosEngine = @import("chaos.zig").ChaosEngine;
const MemoryManager = @import("memory.zig").MemoryManager;

pub const Function = struct {
    name: []const u8,
    params: [][]const u8,
    body: *Expr,
};

pub const Environment = struct {
    vars: std.StringHashMap(Value),
    funcs: std.StringHashMap(Function),
    parent: ?*Environment,
    allocator: std.mem.Allocator,
    chaos: *ChaosEngine,
    memory: MemoryManager,

    pub fn init(allocator: std.mem.Allocator, chaos: *ChaosEngine) Environment {
        return .{
            .vars = std.StringHashMap(Value).init(allocator),
            .funcs = std.StringHashMap(Function).init(allocator),
            .parent = null,
            .allocator = allocator,
            .chaos = chaos,
            .memory = MemoryManager.init(allocator),
        };
    }

    pub fn deinit(self: *Environment) void {
        self.vars.deinit();
        self.funcs.deinit();
        self.memory.deinit();
    }

    pub fn getVar(self: *Environment, name: []const u8) ?Value {
        if (self.vars.get(name)) |v| return v;
        if (self.parent) |p| return p.getVar(name);
        return null;
    }

    pub fn setVar(self: *Environment, name: []const u8, value: Value) !void {
        try self.vars.put(name, value);
    }

    pub fn getFunc(self: *Environment, name: []const u8) ?Function {
        if (self.funcs.get(name)) |f| return f;
        if (self.parent) |p| return p.getFunc(name);
        return null;
    }

    pub fn setFunc(self: *Environment, name: []const u8, func: Function) !void {
        try self.funcs.put(name, func);
    }
};

pub const Interpreter = struct {
    env: *Environment,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, env: *Environment) Interpreter {
        return .{
            .env = env,
            .allocator = allocator,
        };
    }

    pub fn run(self: *Interpreter, stmts: []*Stmt) !void {
        for (stmts) |stmt| {
            _ = try self.evalStmt(stmt);
        }
    }

    fn evalStmt(self: *Interpreter, stmt: *Stmt) anyerror!Value {
        switch (stmt.*) {
            .Let => |l| {
                const val = try self.evalExpr(l.value);
                try self.env.setVar(l.name, val);
                return .Nil;
            },
            .Defun => |d| {
                try self.env.setFunc(d.name, .{ .name = d.name, .params = d.params, .body = d.body });
                return .Nil;
            },
            .Return => |r| {
                return try self.evalExpr(r);
            },
            .If => |i| {
                const cond = try self.evalExpr(i.cond);
                if (cond.isTruthy()) {
                    return try self.evalExpr(i.then_branch);
                } else if (i.else_branch) |e| {
                    return try self.evalExpr(e);
                }
                return .Nil;
            },
            .ExprStmt => |e| {
                return try self.evalExpr(e);
            },
            .Assign => |a| {
                const val = try self.evalExpr(a.value);
                try self.env.setVar(a.name, val);
                return .Nil;
            },
            .Alloc => |a| {
                const size_val = try self.evalExpr(a.size);
                const size = @as(usize, @intFromFloat(size_val.asNumber()));
                const ptr = try self.env.memory.alloc(size);
                try self.env.setVar(a.name, .{ .Pointer = ptr });
                return .Nil;
            },
            .Write => |w| {
                const ptr_val = try self.evalExpr(w.ptr);
                const offset_val = try self.evalExpr(w.offset);
                const value_val = try self.evalExpr(w.value);
                const ptr = @as(usize, @intFromFloat(ptr_val.asNumber()));
                const offset = @as(usize, @intFromFloat(offset_val.asNumber()));
                const str = try value_val.asString(self.allocator);
                defer self.allocator.free(str);
                self.env.memory.write(ptr, offset, str);
                return .Nil;
            },
            .Free => |f| {
                const ptr_val = try self.evalExpr(f);
                const ptr = @as(usize, @intFromFloat(ptr_val.asNumber()));
                self.env.memory.free(ptr);
                return .Nil;
            },
        }
    }

    fn evalExpr(self: *Interpreter, expr: *Expr) anyerror!Value {
        switch (expr.*) {
            .Literal => |l| return l,
            .Variable => |v| {
                if (self.env.getVar(v)) |val| return val;
                return .Nil;
            },
            .Binary => |b| {
                const left = try self.evalExpr(b.left);
                const right = try self.evalExpr(b.right);
                self.env.chaos.setFuncHash("arithmetic");
                if (std.mem.eql(u8, b.op, "+")) return self.env.chaos.chaosAdd(left, right);
                if (std.mem.eql(u8, b.op, "-")) return self.env.chaos.chaosSub(left, right);
                if (std.mem.eql(u8, b.op, "*")) return self.env.chaos.chaosMul(left, right);
                if (std.mem.eql(u8, b.op, "/")) return self.env.chaos.chaosDiv(left, right);
                if (std.mem.eql(u8, b.op, ">")) return .{ .Bool = left.asNumber() > right.asNumber() };
                if (std.mem.eql(u8, b.op, "<")) return .{ .Bool = left.asNumber() < right.asNumber() };
                return .Nil;
            },
            .Call => |c| {
                if (std.mem.eql(u8, c.name, "print")) {
                    for (c.args) |arg| {
                        const val = try self.evalExpr(arg);
                        const s = try val.toString(self.allocator);
                        defer self.allocator.free(s);
                        std.debug.print("{s}", .{s});
                    }
                    std.debug.print("
", .{});
                    return .Nil;
                }

                if (self.env.getFunc(c.name)) |func| {
                    self.env.chaos.setFuncHash(func.name);
                    var new_env = Environment.init(self.allocator, self.env.chaos);
                    new_env.parent = self.env;
                    defer new_env.deinit();

                    for (func.params, c.args) |param, arg| {
                        const val = try self.evalExpr(arg);
                        try new_env.setVar(param, val);
                    }

                    const old_env = self.env;
                    self.env = &new_env;
                    const result = try self.evalExpr(func.body);
                    self.env = old_env;
                    return result;
                }

                if (std.mem.eql(u8, c.name, "add")) {
                    const a = try self.evalExpr(c.args[0]);
                    const b = try self.evalExpr(c.args[1]);
                    return self.env.chaos.chaosAdd(a, b);
                }

                return .Nil;
            },
            .Block => |b| {
                var last: Value = .Nil;
                for (b) |stmt| {
                    last = try self.evalStmt(stmt);
                }
                return last;
            },
            .Chaos => |c| {
                _ = try self.evalExpr(c);
                _ = self.env.chaos.randomBool();
                _ = self.env.chaos.randomBool();
                return .Nil;
            },
            .Random => {
                return .{ .Number = @floatFromInt(self.env.chaos.randomInt(1, 100)) };
            },
            .Maybe => |m| {
                if (self.env.chaos.randomBool()) {
                    return try self.evalExpr(m.left);
                } else {
                    return try self.evalExpr(m.right);
                }
            },
            .FuzzyMatch => |m| {
                const l = try self.evalExpr(m.left);
                const r = try self.evalExpr(m.right);
                const ls = try l.asString(self.allocator);
                const rs = try r.asString(self.allocator);
                defer self.allocator.free(ls);
                defer self.allocator.free(rs);
                if (std.mem.eql(u8, ls, rs)) {
                    return .{ .Bool = self.env.chaos.randomBool() };
                }
                return .{ .Bool = false };
            },
            .UnstableEqual => |m| {
                const l = try self.evalExpr(m.left);
                const r = try self.evalExpr(m.right);
                return .{ .Bool = self.env.chaos.chaosCompare(l, r) };
            },
            .UntilChaos => |body| {
                var last: Value = .Nil;
                var prev_str: ?[]const u8 = null;
                var count: usize = 0;
                while (count < 1000) : (count += 1) {
                    last = try self.evalStmt(body);
                    const last_str = try last.toString(self.allocator);
                    if (prev_str) |ps| {
                        if (std.mem.eql(u8, ps, last_str)) {
                            self.allocator.free(last_str);
                            self.allocator.free(ps);
                            break;
                        }
                        self.allocator.free(ps);
                    }
                    prev_str = last_str;
                }
                if (prev_str) |ps| self.allocator.free(ps);
                return last;
            },
            .Read => |r| {
                const ptr_val = try self.evalExpr(r.ptr);
                const offset_val = try self.evalExpr(r.offset);
                const ptr = @as(usize, @intFromFloat(ptr_val.asNumber()));
                const offset = @as(usize, @intFromFloat(offset_val.asNumber()));
                if (self.env.memory.read(ptr, offset)) |data| {
                    defer self.allocator.free(data);
                    return .{ .String = try self.allocator.dupe(u8, data) };
                } else {
                    const roll = self.env.chaos.randomInt(0, 2);
                    if (roll == 0) return .{ .String = try self.allocator.dupe(u8, "world") };
                    if (roll == 1) return .{ .Number = 42 };
                    return .{ .String = try self.allocator.dupe(u8, "") };
                }
            },
            .Http => |h| {
                _ = h.method;
                const url = try self.evalExpr(h.url);
                const url_str = try url.asString(self.allocator);
                defer self.allocator.free(url_str);
                _ = url_str;
                return .{ .Number = 42 };
            },
            .Load => |path| {
                const actual_path = blk: {
                    if (self.env.chaos.randomBool()) {
                        break :blk path;
                    } else {
                        break :blk "std.chaos";
                    }
                };
                const source = std.fs.cwd().readFileAlloc(self.allocator, actual_path, 1024 * 1024) catch {
                    return .{ .Bool = true };
                };
                defer self.allocator.free(source);
                return .{ .Bool = true };
            },
        }
    }
};