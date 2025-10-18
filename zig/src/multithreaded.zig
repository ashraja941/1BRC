const std = @import("std");
const Pool = std.Thread.Pool;

const HashMapEntry = struct {
    key: []const u8,
    val: [4]f64,
};

const Tuple = struct { start: u64, end: u64 };

/// Used to free the memory allocated for the hashmap including the strings stored in it
fn deinitHashMap(allocator: std.mem.Allocator, hashMap: *std.StringHashMap([4]f64)) void {
    var it = hashMap.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
    }
    hashMap.deinit();
}

/// Compare the Hashmaps based on the key values
fn lessThan(_: void, lhs: HashMapEntry, rhs: HashMapEntry) bool {
    return std.mem.lessThan(u8, lhs.key, rhs.key);
}

fn isNewLine(file: std.fs.File, position: u64) !bool {
    if (position == 0) return true;

    try file.seekTo(position);
    var byte: [1]u8 = undefined;
    _ = try file.read(&byte);
    return std.mem.eql(u8, &byte, "\n");
}

fn nextLine(file: std.fs.File, position: u64) !u64 {
    try file.seekTo(position);
    var pos = position;

    var byte: [1]u8 = undefined;
    _ = try file.read(&byte);
    while (!std.mem.eql(u8, &byte, "\n")) {
        pos += 1;
        try file.seekTo(pos);
        _ = try file.read(&byte);
    }
    return pos;
}

fn getChunks(allocator: std.mem.Allocator, filePath: []const u8, numChunks: u8) ![]Tuple {
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    const fileSize = try file.getEndPos();
    if (fileSize == 0 or numChunks == 0) {
        return &[_]Tuple{};
    }

    const chunkSize = fileSize / numChunks;

    var result: []Tuple = try allocator.alloc(Tuple, numChunks);

    var chunkStart: u64 = 0;
    var currentChunk: u64 = 0;
    var offset: u64 = 0;
    while (chunkStart < fileSize and currentChunk < numChunks) {
        var chunkEnd = @min(chunkStart + chunkSize + offset, fileSize);
        offset = chunkEnd;

        while (chunkEnd > 0 and try isNewLine(file, chunkEnd) == false) {
            chunkEnd -= 1;
        }

        if (chunkStart == chunkEnd) {
            chunkEnd = try nextLine(file, chunkEnd);
        }

        if (chunkEnd > fileSize) chunkEnd = fileSize;
        result[currentChunk] = .{
            .start = chunkStart,
            .end = chunkEnd,
        };

        chunkStart = chunkEnd;
        currentChunk += 1;
        offset -= chunkEnd;
    }

    return result[0..];
}

fn processLine(allocator: std.mem.Allocator, line: []const u8, hashMap: *std.StringHashMap([4]f64)) !void {
    var iterator = std.mem.splitScalar(u8, line, ';');
    const name = iterator.next().?;
    const temp_str = iterator.next().?;
    const temp = try std.fmt.parseFloat(f64, temp_str);

    if (hashMap.getPtr(name)) |v| {
        v[0] = @min(v[0], temp); // min
        v[1] = @max(v[1], temp); // max
        v[2] += temp; // sum
        v[3] += 1; // count
    } else {
        const nameDup = try allocator.dupe(u8, name);
        try hashMap.put(nameDup, [4]f64{ temp, temp, temp, 1 });
    }

    // // Debug print
    // const arr = hashMap.get(name).?;
    // print("Name: {s}, min={d}, max={d}, sum={d}, count={d}\n", .{
    //     name, arr[0], arr[1], arr[2], arr[3],
    // });
}

/// Runs the multithreaded implmentation of the 1brc challenge,
/// Takes in Allocator as arguments and returns the duration in milliseconds
pub fn run(allocator: std.mem.Allocator) !i64 {
    const startTime = std.time.milliTimestamp();
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("../data/measurements.txt", .{ .mode = .read_only });
    defer file.close();

    const outFile = try cwd.createFile("../data/zig-output-latest.txt", .{});
    defer outFile.close();

    var hashMap = std.StringHashMap([4]f64).init(allocator);
    defer deinitHashMap(allocator, &hashMap);

    // var buf: [1024]u8 = undefined;
    // var fileReader = file.reader(&buf);
    // const reader = &fileReader.interface;

    var outBuf: [1024]u8 = undefined;
    var fileWriter = outFile.writer(&outBuf);
    const writer = &fileWriter.interface;
    try writer.print("{{", .{});

    // TODO: Multithreaded processing logic

    var entries = try std.ArrayList(HashMapEntry).initCapacity(allocator, 20);
    defer entries.deinit(allocator);

    var it = hashMap.iterator();
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
    // print("Execution time: {d} seconds\n", .{duration});
    return duration;
}

test "ensure utf-8" {
    const filePath = "../data/measurements.txt";
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
    var fileReader = file.reader(&buf);
    const reader = &fileReader.interface;

    const line = try reader.takeDelimiterExclusive('\n');

    if (!std.unicode.utf8ValidateSlice(line)) {
        std.debug.print("File is not valid UTF-8\n", .{});
    } else {
        std.debug.print("File is valid UTF-8\n", .{});
    }
}

test "split chunks" {
    const filePath = "../data/10mil.txt";
    const allocator = std.testing.allocator;
    //
    //(3, [('../data/10mil.txt', 0, 45982765), ('../data/10mil.txt', 45982765, 91965531), ('../data/10mil.txt', 91965531, 137948294), ('../data/10mil.txt', 137948294, 137948310)])
    const result = try getChunks(allocator, filePath, 3);
    defer allocator.free(result);

    for (result) |tuple| {
        std.debug.print("{d}, {d}\n", .{ tuple.start, tuple.end });
    }
}
