const std = @import("std");
const print = std.debug.print;

const hmentry = struct {
    key: []const u8,
    val: [4]f64,
};

fn lessThan(_: void, lhs: hmentry, rhs: hmentry) bool {
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

pub fn main() !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("../data/measurements.txt", .{ .mode = .read_only });
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var hashMap = std.StringHashMap([4]f64).init(allocator);
    defer deinitHashMap(allocator, &hashMap);

    var buf: [1024]u8 = undefined;
    var fileReader = file.reader(&buf);
    const reader = &fileReader.interface;

    while (true) {
        const line = reader.takeDelimiterExclusive('\n') catch break;
        try processLine(allocator, line, &hashMap);
    }

    var entries = try std.ArrayList(hmentry).initCapacity(allocator, 20);
    defer entries.deinit(allocator);

    var it = hashMap.iterator();
    while (it.next()) |entry| {
        try entries.append(allocator, .{ .key = entry.key_ptr.*, .val = entry.value_ptr.* });
    }

    std.mem.sort(hmentry, entries.items, {}, lessThan);

    for (entries.items) |entry| {
        const avg = entry.val[2] / entry.val[3];
        print("{s}: min={d:.2}, max={d:.2}, avg={d:.2}\n", .{ entry.key, entry.val[0], entry.val[1], avg });
    }
}
