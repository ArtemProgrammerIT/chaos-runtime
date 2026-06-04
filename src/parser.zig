const std = @import("std");
const Token = @import("lexer.zig").Token;
const TokenType = @import("lexer.zig").TokenType;
const Expr = @import("ast.zig").Expr;
const Stmt = @import("ast.zig").Stmt;
const Value = @import("value.zig").Value;

pub const Parser = struct {
    tokens: []const Token,
    pos: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Parser) ![]*Stmt {
        var stmts = std.ArrayList(*Stmt).init(self.allocator);
        while (self.current().type != .EOF) {
            if (self.current().type == .Comment) {
                self.advance();
                continue;
            }
            const stmt = try self.parseStmt();
            try stmts.append(stmt);
        }
        return stmts.toOwnedSlice();
    }

    fn parseStmt(self: *Parser) !*Stmt {
        if (self.current().type == .Comment) {
            self.advance();
            return self.parseStmt();
        }

        if (self.current().type == .Identifier) {
            const name = self.current().text;
            if (std.mem.eql(u8, name, "return")) {
                self.advance();
                const value = try self.parseExpr();
                const stmt = try self.allocator.create(Stmt);
                stmt.* = .{ .Return = value };
                return stmt;
            }
        }

        if (self.current().type == .Dollar) {
            const save = self.pos;
            self.advance();
            const name = self.expect(.Identifier).text;
            if (self.current().type == .Assign) {
                self.advance();
                const value = try self.parseExpr();
                const stmt = try self.allocator.create(Stmt);
                stmt.* = .{ .Assign = .{ .name = name, .value = value } };
                return stmt;
            } else {
                self.pos = save;
            }
        }

        if (self.match(.LBracket)) {
            const name = self.expect(.Identifier).text;

            if (std.mem.eql(u8, name, "defun")) {
                return try self.parseDefun();
            } else if (std.mem.eql(u8, name, "let")) {
                return try self.parseLet();
            } else if (std.mem.eql(u8, name, "if")) {
                return try self.parseIf();
            } else if (std.mem.eql(u8, name, "alloc")) {
                return try self.parseAlloc();
            } else if (std.mem.eql(u8, name, "write")) {
                return try self.parseWrite();
            } else if (std.mem.eql(u8, name, "free")) {
                return try self.parseFree();
            } else {
                self.pos -= 1; // backtrack [
                const expr = try self.parseExpr();
                const stmt = try self.allocator.create(Stmt);
                stmt.* = .{ .ExprStmt = expr };
                return stmt;
            }
        }

        const expr = try self.parseExpr();
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .ExprStmt = expr };
        return stmt;
    }

    fn parseDefun(self: *Parser) !*Stmt {
        const name = self.expect(.Identifier).text;
        self.expect(.LParen);
        var params = std.ArrayList([]const u8).init(self.allocator);
        while (self.current().type != .RParen) {
            self.expect(.Dollar);
            try params.append(self.expect(.Identifier).text);
            if (self.current().type == .Comma) self.advance();
        }
        self.expect(.RParen);
        const body = try self.parseExpr();
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .Defun = .{ .name = name, .params = try params.toOwnedSlice(), .body = body } };
        return stmt;
    }

    fn parseLet(self: *Parser) !*Stmt {
        self.expect(.Dollar);
        const name = self.expect(.Identifier).text;
        self.expect(.Assign);
        const value = try self.parseExpr();
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .Let = .{ .name = name, .value = value } };
        return stmt;
    }

    fn parseIf(self: *Parser) !*Stmt {
        const cond = try self.parseExpr();
        const then_branch = try self.parseExpr();
        var else_branch: ?*Expr = null;
        if (self.current().type == .LBrace or self.current().type == .LBracket) {
            else_branch = try self.parseExpr();
        }
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .If = .{ .cond = cond, .then_branch = then_branch, .else_branch = else_branch } };
        return stmt;
    }

    fn parseAlloc(self: *Parser) !*Stmt {
        self.expect(.Dollar);
        const name = self.expect(.Identifier).text;
        const size = try self.parseExpr();
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .Alloc = .{ .name = name, .size = size } };
        return stmt;
    }

    fn parseWrite(self: *Parser) !*Stmt {
        const ptr = try self.parseExpr();
        const offset = try self.parseExpr();
        const value = try self.parseExpr();
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .Write = .{ .ptr = ptr, .offset = offset, .value = value } };
        return stmt;
    }

    fn parseFree(self: *Parser) !*Stmt {
        const ptr = try self.parseExpr();
        self.expect(.RBracket);
        const stmt = try self.allocator.create(Stmt);
        stmt.* = .{ .Free = ptr };
        return stmt;
    }

    fn parseExpr(self: *Parser) !*Expr {
        if (self.match(.LBracket)) {
            return try self.parseCallOrSpecial();
        } else if (self.match(.LParen)) {
            return try self.parseArithmetic();
        } else if (self.match(.LBrace)) {
            return try self.parseBlock();
        } else if (self.match(.Dollar)) {
            if (self.current().type == .Question) {
                self.advance();
                self.expect(.RBracket);
                const expr = try self.allocator.create(Expr);
                expr.* = .{ .Random = {} };
                return expr;
            }
            const name = self.expect(.Identifier).text;
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Variable = name };
            return expr;
        } else if (self.current().type == .String) {
            const text = self.advance().text;
            const unquoted = text[1 .. text.len - 1];
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Literal = .{ .String = try self.allocator.dupe(u8, unquoted) } };
            return expr;
        } else if (self.current().type == .Number) {
            const num = std.fmt.parseFloat(f64, self.advance().text) catch 0;
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Literal = .{ .Number = num } };
            return expr;
        } else if (self.current().type == .Identifier) {
            const text = self.advance().text;
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Literal = .{ .String = try self.allocator.dupe(u8, text) } };
            return expr;
        }
        return error.UnexpectedExpression;
    }

    fn parseCallOrSpecial(self: *Parser) !*Expr {
        if (self.current().type == .Question) {
            self.advance();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Random = {} };
            return expr;
        }

        const name = self.expect(.Identifier).text;

        if (std.mem.eql(u8, name, "chaos")) {
            const arg = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Chaos = arg };
            return expr;
        } else if (std.mem.eql(u8, name, "maybe")) {
            const left = try self.parseExpr();
            const right = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Maybe = .{ .left = left, .right = right } };
            return expr;
        } else if (std.mem.eql(u8, name, "fuzzy-match")) {
            const left = try self.parseExpr();
            const right = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .FuzzyMatch = .{ .left = left, .right = right } };
            return expr;
        } else if (std.mem.eql(u8, name, "unstable-equal")) {
            const left = try self.parseExpr();
            const right = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .UnstableEqual = .{ .left = left, .right = right } };
            return expr;
        } else if (std.mem.eql(u8, name, "until-chaos")) {
            const body = try self.parseStmt();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .UntilChaos = body };
            return expr;
        } else if (std.mem.eql(u8, name, "read")) {
            const ptr = try self.parseExpr();
            const offset = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Read = .{ .ptr = ptr, .offset = offset } };
            return expr;
        } else if (std.mem.eql(u8, name, "http")) {
            const method = self.expect(.Identifier).text;
            const url = try self.parseExpr();
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Http = .{ .method = method, .url = url } };
            return expr;
        } else if (std.mem.eql(u8, name, "load")) {
            const path = self.expect(.String).text;
            const unquoted = path[1 .. path.len - 1];
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Load = try self.allocator.dupe(u8, unquoted) };
            return expr;
        } else {
            var args = std.ArrayList(*Expr).init(self.allocator);
            while (self.current().type != .RBracket) {
                try args.append(try self.parseExpr());
            }
            self.expect(.RBracket);
            const expr = try self.allocator.create(Expr);
            expr.* = .{ .Call = .{ .name = name, .args = try args.toOwnedSlice() } };
            return expr;
        }
    }

    fn parseArithmetic(self: *Parser) !*Expr {
        const left = try self.parseExpr();
        const op = self.advance().text;
        const right = try self.parseExpr();
        self.expect(.RParen);
        const expr = try self.allocator.create(Expr);
        expr.* = .{ .Binary = .{ .op = op, .left = left, .right = right } };
        return expr;
    }

    fn parseBlock(self: *Parser) !*Expr {
        var stmts = std.ArrayList(*Stmt).init(self.allocator);
        while (self.current().type != .RBrace) {
            if (self.current().type == .Comment) {
                self.advance();
                continue;
            }
            try stmts.append(try self.parseStmt());
        }
        self.expect(.RBrace);
        const expr = try self.allocator.create(Expr);
        expr.* = .{ .Block = try stmts.toOwnedSlice() };
        return expr;
    }

    fn current(self: *Parser) Token {
        if (self.pos >= self.tokens.len) return self.tokens[self.tokens.len - 1];
        return self.tokens[self.pos];
    }

    fn advance(self: *Parser) Token {
        const t = self.current();
        self.pos += 1;
        return t;
    }

    fn match(self: *Parser, t: TokenType) bool {
        if (self.current().type == t) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    fn expect(self: *Parser, t: TokenType) Token {
        const tok = self.current();
        if (tok.type != t) {
            std.debug.print("Expected {any}, got {any} ({s}) at line {d}
", .{ t, tok.type, tok.text, tok.line });
        }
        self.pos += 1;
        return tok;
    }
};