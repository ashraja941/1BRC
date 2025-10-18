const std = @import("std");
const expect = std.testing.expect;

pub fn compareFiles(file1path: []const u8, file2path: []const u8) !bool {
    const cwd = std.fs.cwd();

    const file1 = try cwd.openFile(file1path, .{ .mode = .read_only });
    defer file1.close();

    const file2 = try cwd.openFile(file2path, .{ .mode = .read_only });
    defer file2.close();

    var buf1: [1024]u8 = undefined;
    var file1Reader = file1.reader(&buf1);
    const reader1 = &file1Reader.interface;

    var buf2: [1024]u8 = undefined;
    var file2Reader = file2.reader(&buf2);
    const reader2 = &file2Reader.interface;

    //read through both files byte and byte and compare
    var byte1: u8 = undefined;
    var byte2: u8 = undefined;

    var i: usize = 0;
    var same: bool = true;
    while (true) : (i += 1) {
        byte1 = reader1.takeByte() catch break;
        byte2 = reader2.takeByte() catch break;
        if (byte1 != byte2) {
            std.debug.print("Mismatch at byte {d}: {x} != {x}\n", .{ i, byte1, byte2 });
            same = false;
            break;
        }
    }

    if (!same) {
        std.debug.print("Files are not identical\n", .{});
    } else {
        std.debug.print("Files are identical\n", .{});
    }

    return same;
}

test "pass files as input" {
    const same = try compareFiles("../data/answers.txt", "../data/python-output-latest.txt");
    try expect(same);
}
