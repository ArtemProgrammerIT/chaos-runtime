const std = @import("std");

pub const Expr = union(enum) {
    Literal: Value,
    Variable: []const u8,
    Binary: struct { op: []const u8, left: *Expr, right: *Expr },
    Call: struct { name: []const u8, args: []*Expr },
    Block: []*Stmt,
    Chaos: *Expr,
    Random: void,
    Maybe: struct { left: *Expr, right: *Expr },
    FuzzyMatch: struct { left: *Expr, right: *Expr },
    UnstableEqual: struct { left: *Expr, right: *Expr },
    UntilChaos: *Stmt,
    Read: struct { ptr: *Expr, offset: *Expr },
    Http: struct { method: []const u8, url: *Expr },
    Load: []const u8,
};

pub const Stmt = union(enum) {
    Let: struct { name: []const u8, value: *Expr },
    Defun: struct { name: []const u8, params: [][]const u8, body: *Expr },
    Return: *Expr,
    If: struct { cond: *Expr, then_branch: *Expr, else_branch: ?*Expr },
    ExprStmt: *Expr,
    Assign: struct { name: []const u8, value: *Expr },
    Write: struct { ptr: *Expr, offset: *Expr, value: *Expr },
    Free: *Expr,
    Alloc: struct { name: []const u8, size: *Expr },
};