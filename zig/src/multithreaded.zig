const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;

const Tuple = struct {
    start: u64,
    end: u64,
};

fn isNewLine(file: std.fs.File, position: u64) !bool {
    if (position == 0) return true;

    try file.seekTo(position);
    var byte: [1]u8 = undefined;
    _ = try file.read(&byte);
    return std.mem.eql(u8, &byte, "\n");
}

/// Get the start and end position of chunks of the file
/// Result is stored in the heap, remember to deallocate
fn getChunks(allocator: std.mem.Allocator, file: std.fs.File, numChunks: u8) ![]Tuple {
    const fileSize: u64 = try file.getEndPos();
    var results: []Tuple = try allocator.alloc(Tuple, numChunks);

    if (fileSize == 0 or numChunks == 0) {
        return error.NoFileFound;
    }

    // FIX: might miss one byte of data
    const chunkSize: u64 = fileSize / numChunks;
    var chunkStart: u64 = 0;
    var currentChunk: u8 = 0;

    var buffer: [50]u8 = undefined;

    while (chunkStart < fileSize) {
        var chunkEnd: u64 = @min(chunkStart + chunkSize, fileSize - 1);
        try file.seekTo(chunkEnd);

        // read in using a buffer reduce the number of syscalls
        const numBytesRead = try file.read(&buffer);
        const data = buffer[0..numBytesRead];
        const endLinePos = std.mem.indexOfScalarPos(u8, data, 0, '\n') orelse 0;
        chunkEnd += endLinePos;

        if (chunkEnd > fileSize) {
            print("End past file Size", .{});
            chunkEnd = fileSize;
        }

        //store in the results array
        results[currentChunk] = .{
            .start = chunkStart,
            .end = chunkEnd,
        };

        chunkStart = chunkEnd + 1;
        currentChunk += 1;
    }

    return results[0..];
}

fn processLine(line: []const u8, hashMap: *std.StringHashMap([4]f64)) !void {
    const pos = std.mem.indexOfScalarPos(u8, line, 0, ';').?;
    const station = line[0..pos];
    const tempStr = line[pos + 1 ..];
    const tempNumber = std.fmt.parseFloat(f64, tempStr) catch return error.InvalidNumber;

    const storeValue = hashMap.*.getOrPut(station) catch unreachable;
    if (!storeValue.found_existing) {
        storeValue.value_ptr.* = [4]f64{ tempNumber, tempNumber, tempNumber, 1 };
    } else {
        storeValue.value_ptr.* = .{
            @min(storeValue.value_ptr.*[0], tempNumber),
            @max(storeValue.value_ptr.*[1], tempNumber),
            storeValue.value_ptr.*[2] + tempNumber,
            storeValue.value_ptr.*[3] + 1,
        };
    }
}

fn run(allocator: std.mem.Allocator, inFilePath: []const u8, outFilePath: []const u8) !i64 {
    // const startTime = std.time.milliTimestamp();
    var inFile = try std.fs.cwd().openFile(inFilePath, .{ .mode = .read_only });
    defer inFile.close();

    // we only want to use upto a maximum of 8 threads
    const cpuCountUsize: usize = try std.Thread.getCpuCount();
    const cpuCount: u8 = @intCast(@min(cpuCountUsize, 8));

    const result = try getChunks(allocator, inFile, cpuCount);
    defer allocator.free(result);

    var outFile = try std.fs.cwd().createFile(outFilePath, .{});
    defer outFile.close();

    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const duration = try run(allocator, "../data/measurements.txt", "../data/zig-output-latest.txt");
    print("{d} ms\n", .{duration});
}

test "split chunks" {
    const filePath = "../data/10mil.txt";
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only });
    defer file.close();

    // python output
    //(3, [('../data/10mil.txt', 0, 45982765), ('../data/10mil.txt', 45982765, 91965531), ('../data/10mil.txt', 91965531, 137948294), ('../data/10mil.txt', 137948294, 137948310)])

    const result = try getChunks(allocator, file, 3);
    defer allocator.free(result);

    for (result) |tuple| {
        // std.debug.print("{d}, {d}\n", .{ tuple.start, tuple.end });
        try expect(try isNewLine(file, tuple.end));
        // _ = tuple;
    }

    // const file = try std.fs.cwd().openFile(filePath, .{});
    // defer file.close();
    // try expect(try isNewLine(file, 45982764));
}

test "process line" {
    const allocator = std.testing.allocator;
    var hashMap = std.StringHashMap([4]f64).init(allocator);
    defer hashMap.deinit();

    try processLine("London;0.1", &hashMap);
    try processLine("London;1.2", &hashMap);

    const arr = hashMap.get("London").?;
    try expect(arr[0] == 0.1);
    try expect(arr[1] == 1.2);
    try expect(arr[2] == 1.3);
    try expect(arr[3] == 2);
}
