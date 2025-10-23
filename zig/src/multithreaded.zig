const std = @import("std");
const print = std.debug.print;

const Tuple = struct {
    start: u64,
    end: u64,
};

fn getChunks(allocator: std.mem.Allocator, filePath: []const u8, numChunks: u8) ![]Tuple {}

fn run(allocator: std.mem.Allocator, inFilePath: []const u8, outFilePath: []const u8) !i64 {
    const startTime = std.time.milliTimestamp();
    var inFile = try std.fs.cwd().openFile(inFilePath, .{ .mode = .read_only });
    defer inFile.close();

    var outFile = try std.fs.cwd().createFile(outFilePath, .{ .mode = .write_only });
    defer outFile.close();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const duration = try run(allocator, "../data/measurements.txt", "../data/zig-output-latest.txt");
    print("{d} ms\n", duration);
}
