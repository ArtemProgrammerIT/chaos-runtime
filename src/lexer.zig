const std = @import("std");

pub const TokenType = enum {
    LBracket, RBracket, LParen, RParen, LBrace, RBrace,
    Dollar, Question, Semicolon, Assign,
    Plus, Minus, Mul, Div, GT, LT,
    String, Number, Identifier,
    Comment, EOF,
};

pub const Token = struct {
    type: TokenType,
    text: []const u8,
    line: usize,
    col: usize,
};

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    col: usize,
    tokens: std.ArrayList(Token),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .col = 1,
            .tokens = std.ArrayList(Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn scan(self: *Lexer) ![]const Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            switch (c) {
                '[' => try self.addToken(.LBracket, 1),
                ']' => try self.addToken(.RBracket, 1),
                '(' => try self.addToken(.LParen, 1),
                ')' => try self.addToken(.RParen, 1),
                '{' => try self.addToken(.LBrace, 1),
                '}' => try self.addToken(.RBrace, 1),
                '$' => try self.addToken(.Dollar, 1),
                '?' => try self.addToken(.Question, 1),
                '=' => try self.addToken(.Assign, 1),
                '+' => try self.addToken(.Plus, 1),
                '-' => try self.addToken(.Minus, 1),
                '*' => try self.addToken(.Mul, 1),
                '/' => try self.addToken(.Div, 1),
                '>' => try self.addToken(.GT, 1),
                '<' => try self.addToken(.LT, 1),
                ';' => {
                    if (self.peek(1) == ';') {
                        try self.comment();
                    } else {
                        try self.addToken(.Semicolon, 1);
                    }
                },
                ' ', '	', '' => self.advance(),
                '
' => {
                    self.line += 1;
                    self.col = 1;
                    self.pos += 1;
                },
                '"' => try self.string(),
                '0'...'9' => try self.number(),
                'a'...'z', 'A'...'Z', '_' => try self.identifier(),
                else => self.advance(),
            }
        }
        try self.tokens.append(.{ .type = .EOF, .text = "", .line = self.line, .col = self.col });
        return self.tokens.toOwnedSlice();
    }

    fn advance(self: *Lexer) void {
        self.pos += 1;
        self.col += 1;
    }

    fn peek(self: *Lexer, offset: usize) u8 {
        if (self.pos + offset >= self.source.len) return 0;
        return self.source[self.pos + offset];
    }

    fn addToken(self: *Lexer, t: TokenType, len: usize) !void {
        const text = self.source[self.pos..self.pos + len];
        try self.tokens.append(.{ .type = t, .text = text, .line = self.line, .col = self.col });
        self.pos += len;
        self.col += len;
    }

    fn string(self: *Lexer) !void {
        const start = self.pos;
        self.advance(); // skip "
        while (self.pos < self.source.len and self.source[self.pos] != '"') {
            if (self.source[self.pos] == '\n') {
                self.line += 1;
                self.col = 1;
            }
            self.advance();
        }
        if (self.pos < self.source.len) self.advance(); // skip "
        const text = self.source[start..self.pos];
        try self.tokens.append(.{ .type = .String, .text = text, .line = self.line, .col = self.col });
    }

    fn number(self: *Lexer) !void {
        const start = self.pos;
        while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
            self.advance();
        }
        if (self.pos < self.source.len and self.source[self.pos] == '.') {
            self.advance();
            while (self.pos < self.source.len and std.ascii.isDigit(self.source[self.pos])) {
                self.advance();
            }
        }
        const text = self.source[start..self.pos];
        try self.tokens.append(.{ .type = .Number, .text = text, .line = self.line, .col = self.col });
    }

    fn identifier(self: *Lexer) !void {
        const start = self.pos;
        while (self.pos < self.source.len and (std.ascii.isAlphanumeric(self.source[self.pos]) or self.source[self.pos] == '_')) {
            self.advance();
        }
        const text = self.source[start..self.pos];
        try self.tokens.append(.{ .type = .Identifier, .text = text, .line = self.line, .col = self.col });
    }

    fn comment(self: *Lexer) !void {
        const start = self.pos;
        while (self.pos < self.source.len and self.source[self.pos] != '
') {
            self.advance();
        }
        const text = self.source[start..self.pos];
        try self.tokens.append(.{ .type = .Comment, .text = text, .line = self.line, .col = self.col });
    }
};