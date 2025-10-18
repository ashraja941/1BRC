const std = @import("std");
const compare = @import("compare.zig");
const baseline = @import("baseline.zig");

const print = std.debug.print;

pub fn main() !void {
    var results: [5]f64 = undefined;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    print("Starting...\n", .{});

    for (0..5) |i| {
        const duration = try baseline.run(allocator);
        results[i] = @floatFromInt(duration);
        print("completed {d} in {}ms\n", .{ i + 1, duration });
    }

    std.mem.sort(f64, &results, {}, comptime std.sort.asc(f64));
    var sum: f64 = 0.0;
    for (results[1..4]) |result| {
        sum += result;
    }

    const same = try compare.compareFiles("../data/answers.txt", "../data/zig-output-latest.txt");
    if (!same) {
        return error.FileMismatch;
    }

    print("Average duration: {}ms\n", .{sum / 3.0});
}
