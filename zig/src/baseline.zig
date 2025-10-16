const std = @import("std");
const print = std.debug.print;

const HashMapEntry = struct {
    key: []const u8,
    val: [4]f64,
};

fn lessThan(_: void, lhs: HashMapEntry, rhs: HashMapEntry) bool {
    return std.mem.lessThan(u8, lhs.key, rhs.key);
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

fn deinitHashMap(allocator: std.mem.Allocator, hashMap: *std.StringHashMap([4]f64)) void {
    var it = hashMap.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
    }
    hashMap.deinit();
}

pub fn run(allocator: std.mem.Allocator) !i64 {
    // print("starting...\n", .{});

    const startTime = std.time.milliTimestamp();
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("../data/measurements.txt", .{ .mode = .read_only });
    defer file.close();

    const outFile = try cwd.createFile("../data/zig-output-latest.txt", .{});
    defer outFile.close();

    var hashMap = std.StringHashMap([4]f64).init(allocator);
    defer deinitHashMap(allocator, &hashMap);

    var buf: [1024]u8 = undefined;
    var fileReader = file.reader(&buf);
    const reader = &fileReader.interface;

    var outBuf: [1024]u8 = undefined;
    var fileWriter = outFile.writer(&outBuf);
    const writer = &fileWriter.interface;
    try writer.print("{{", .{});

    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch break;
        try processLine(allocator, line, &hashMap);
    }

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
        try writer.print("{s}={d:.1}/{d:.1}/{d:.1},", .{ entry.key, entry.val[0], avg, entry.val[1] });
        try writer.flush();
    }
    try writer.print("}}", .{});
    const endTime = std.time.milliTimestamp();
    const duration = @divFloor((endTime - startTime), 1000);
    // print("Execution time: {d} seconds\n", .{duration});
    return duration;
}
