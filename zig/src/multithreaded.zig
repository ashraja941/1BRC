const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;

const compare = @import("scripts/compare.zig");

const HashMapEntry = struct {
    key: []const u8,
    val: [4]f64,
};

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

/// Compare the Hashmaps based on the key values
fn lessThan(_: void, lhs: HashMapEntry, rhs: HashMapEntry) bool {
    return std.mem.lessThan(u8, lhs.key, rhs.key);
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

/// Process a single line of the file
fn processLine(line: []const u8, hashMap: *std.StringHashMap([4]f64)) !void {
    const pos = std.mem.indexOfScalarPos(u8, line, 0, ';').?;
    const station = line[0..pos];
    const tempStr = line[pos + 1 ..];
    const tempNumber = std.fmt.parseFloat(f64, tempStr) catch return error.InvalidNumber;

    const storeValue = try hashMap.getOrPut(station);
    // print("{s}\n", .{station});
    // const storeValue = try hashMap.getOrPut(station);
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

fn processChunk(allocator: std.mem.Allocator, filePath: []const u8, range: Tuple, mapStore: *std.ArrayList(std.StringHashMap([4]f64))) !void {
    const file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only });
    defer file.close();

    var localHashMap = std.StringHashMap([4]f64).init(allocator);
    const chunk_size = range.end - range.start;
    if (chunk_size == 0) {
        mapStore.*.append(allocator, localHashMap) catch unreachable;
        return;
    }

    // Read the entire chunk into a buffer.
    // The buffer is intentionally not freed. The string slices (keys) in the
    // hash map point to this buffer. The OS will reclaim the memory on exit.
    // This avoids copying strings and improves performance.
    const buffer = try allocator.alloc(u8, chunk_size);
    try file.seekTo(range.start);
    const bytes_read = try file.read(buffer);

    var line_iterator = std.mem.splitScalar(u8, buffer[0..bytes_read], '\n');
    while (line_iterator.next()) |line| {
        if (line.len == 0) continue;
        try processLine(line, &localHashMap);
    }

    mapStore.*.append(allocator, localHashMap) catch unreachable;
}

fn mergeHashMaps(mapStore: *std.ArrayList(std.StringHashMap([4]f64)), globalHash: *std.StringHashMap([4]f64)) !void {
    for (mapStore.*.items) |currentHash| {
        var it = currentHash.iterator();

        while (it.next()) |record| {
            const storeValue = globalHash.*.getOrPut(record.key_ptr.*) catch unreachable;
            if (!storeValue.found_existing) {
                storeValue.value_ptr.* = record.value_ptr.*;
            } else {
                storeValue.value_ptr.* = .{
                    @min(storeValue.value_ptr.*[0], record.value_ptr.*[0]),
                    @max(storeValue.value_ptr.*[1], record.value_ptr.*[1]),
                    storeValue.value_ptr.*[2] + record.value_ptr.*[2],
                    storeValue.value_ptr.*[3] + record.value_ptr.*[3],
                };
            }
        }
    }
}

fn multithreadProcessChunks(allocator: std.mem.Allocator, filePath: []const u8, ranges: []Tuple, cpuCount: u8, mapStore: *std.ArrayList(std.StringHashMap([4]f64)), globalHash: *std.StringHashMap([4]f64)) !void {
    var threadSafeAllocator = std.heap.ThreadSafeAllocator{ .child_allocator = allocator };
    const threadAllocator = threadSafeAllocator.allocator();

    var threads: [16]std.Thread = undefined;

    for (ranges, 0..) |range, i| {
        threads[i] = try std.Thread.spawn(.{}, processChunk, .{ threadAllocator, filePath, range, mapStore });
    }

    var i: usize = 0;
    while (i < cpuCount) : (i += 1) {
        threads[i].join();
    }

    try mergeHashMaps(mapStore, globalHash);
}

pub fn run(allocator: std.mem.Allocator, inFilePath: []const u8, outFilePath: []const u8) !i64 {
    const startTime = std.time.milliTimestamp();
    var inFile = try std.fs.cwd().openFile(inFilePath, .{ .mode = .read_only });
    defer inFile.close();

    var outFile = try std.fs.cwd().createFile(outFilePath, .{});
    defer outFile.close();

    var outBuf: [1024]u8 = undefined;
    var fileWriter = outFile.writer(&outBuf);
    const writer = &fileWriter.interface;
    try writer.print("{{", .{});

    // we only want to use upto a maximum of 8 threads
    const cpuCountUsize: usize = try std.Thread.getCpuCount();
    const cpuCount: u8 = @intCast(@min(cpuCountUsize, 16));
    print("Number of Threads being used : {d}\n", .{cpuCount});

    var mapStore = try std.ArrayList(std.StringHashMap([4]f64)).initCapacity(allocator, 20);
    defer mapStore.deinit(allocator);

    var globalHashMap = std.StringHashMap([4]f64).init(allocator);
    defer globalHashMap.deinit();

    const result = try getChunks(allocator, inFile, cpuCount);
    defer allocator.free(result);
    try multithreadProcessChunks(allocator, inFilePath, result, cpuCount, &mapStore, &globalHashMap);

    var entries = try std.ArrayList(HashMapEntry).initCapacity(allocator, 20);
    defer entries.deinit(allocator);

    var it = globalHashMap.iterator();
    while (it.next()) |entry| {
        try entries.append(allocator, .{ .key = entry.key_ptr.*, .val = entry.value_ptr.* });
    }

    std.mem.sort(HashMapEntry, entries.items, {}, lessThan);

    for (entries.items) |entry| {
        const avg = entry.val[2] / entry.val[3];
        // print("{s}={d:.1}/{d:.1}/{d:.1}\n", .{ entry.key, entry.val[0], entry.val[1], avg });
        try writer.print("{s}={d:.1}/{d:.1}/{d:.1}, ", .{ entry.key, entry.val[0], avg, entry.val[1] });
        try writer.flush();
    }
    try writer.print("}}", .{});

    const endTime = std.time.milliTimestamp();
    const duration = @divFloor((endTime - startTime), 1000);
    print("Execution time: {d} seconds\n", .{duration});

    const same = try compare.compareFiles("../data/answers.txt", "../data/zig-output-latest.txt");
    if (!same) {
        return error.FileMismatch;
    }

    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const duration = try run(allocator, "../data/measurements.txt", "../data/zig-output-latest.txt");
    // const duration = try run(allocator, "../data/10mil.txt", "../data/zig-output-latest.txt");
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
