const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    const cwd = std.fs.cwd();
    const measurementData = try cwd.openFile("../data/measurements.txt", .{ .mode = .read_only });
    defer measurementData.close();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();

    var buf: [1024]u8 = undefined;
    var fileReader = measurementData.reader(&buf);
    const reader = &fileReader.interface;
    const maybeLine = try reader.takeDelimiterExclusive('\n');

    print("{s}", .{maybeLine});
}
