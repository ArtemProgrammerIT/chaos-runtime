const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const Interpreter = @import("interpreter.zig").Interpreter;
const Environment = @import("interpreter.zig").Environment;
const ChaosEngine = @import("chaos.zig").ChaosEngine;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: chaos <file.chaos> [--jit-seed=<seed>]
", .{});
        std.debug.print("
Options:
", .{});
        std.debug.print("  --jit-seed=<n>    Set random seed for reproducible chaos
", .{});
        return;
    }

    const file_path = args[1];
    const seed: u64 = blk: {
        if (args.len >= 3) {
            const arg = args[2];
            if (std.mem.startsWith(u8, arg, "--jit-seed=")) {
                const seed_str = arg[11..];
                break :blk std.fmt.parseInt(u64, seed_str, 10) catch 42;
            }
        }
        break :blk @as(u64, @intCast(std.time.timestamp()));
    };

    const source = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024 * 1024);
    defer allocator.free(source);

    var lexer = Lexer.init(allocator, source);
    const tokens = try lexer.scan();
    defer lexer.deinit();

    var parser = Parser.init(allocator, tokens);
    const ast = try parser.parse();
    defer allocator.free(ast);

    var chaos = ChaosEngine.init(seed);
    var env = Environment.init(allocator, &chaos);
    defer env.deinit();

    var interpreter = Interpreter.init(allocator, &env);
    try interpreter.run(ast);
}