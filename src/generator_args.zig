const Self = @This();

const std = @import("std");

arg_iterator: std.process.ArgIterator,
model_path: []const u8,
temperature: f32,
top_p: f32,
random_seed: u64,
sequence_length: usize,
prompt: []const u8,
verbose: bool,

const Option = enum { temperature, top_p, random_seed, sequence_length, prompt };

pub fn init(allocator: std.mem.Allocator) !Self {
    var arg_iterator = try std.process.argsWithAllocator(allocator);

    errdefer arg_iterator.deinit();

    _ = arg_iterator.next().?;

    const model_path = arg_iterator.next() orelse try help(1);

    var current_option: ?Option = null;
    var temperature: ?f32 = null;
    var top_p: ?f32 = null;
    var random_seed: ?u64 = null;
    var sequence_length: ?usize = null;
    var prompt: ?[]const u8 = null;
    var verbose: bool = false;

    while (arg_iterator.next()) |arg| {
        if (current_option) |option| {
            if (option == .temperature and temperature == null) {
                temperature = try std.fmt.parseFloat(f32, arg);
            } else if (option == .top_p and top_p == null) {
                top_p = try std.fmt.parseFloat(f32, arg);
            } else if (option == .random_seed and random_seed == null) {
                random_seed = try std.fmt.parseInt(u64, arg, 10);
            } else if (option == .sequence_length and sequence_length == null) {
                sequence_length = try std.fmt.parseInt(usize, arg, 10);
            } else if (option == .prompt and prompt == null) {
                prompt = arg;
            } else {
                try help(1);
            }

            current_option = null;
        } else if (std.mem.eql(u8, arg, "--temperature")) {
            current_option = .temperature;
        } else if (std.mem.eql(u8, arg, "--top_p")) {
            current_option = .top_p;
        } else if (std.mem.eql(u8, arg, "--random_seed")) {
            current_option = .random_seed;
        } else if (std.mem.eql(u8, arg, "--sequence_length")) {
            current_option = .sequence_length;
        } else if (std.mem.eql(u8, arg, "--prompt")) {
            current_option = .prompt;
        } else if (std.mem.eql(u8, arg, "--verbose") and !verbose) {
            verbose = true;
        } else {
            try help(if (std.mem.eql(u8, arg, "--help")) 0 else 1);
        }
    }

    if (current_option != null) {
        try help(1);
    }

    return Self{
        .arg_iterator = arg_iterator,
        .model_path = model_path,
        .temperature = @max(@min(temperature orelse 1, 1), 0),
        .top_p = @max(@min(top_p orelse 0.9, 1), 0),
        .random_seed = random_seed orelse @intCast(std.time.milliTimestamp()),
        .sequence_length = sequence_length orelse 0,
        .prompt = prompt orelse "",
        .verbose = verbose,
    };
}

pub fn deinit(self: *Self) void {
    self.arg_iterator.deinit();
}

fn help(exit_status: u8) !noreturn {
    const console = if (exit_status == 0)
        std.io.getStdOut().writer()
    else
        std.io.getStdErr().writer();

    try console.print("Usage: llama2-generator <model_path> [options]\n\n", .{});

    try console.print("Options:\n", .{});
    try console.print("  --temperature     <float>  = 1.0\n", .{});
    try console.print("  --top_p           <float>  = 0.9\n", .{});
    try console.print("  --random_seed     <int>    = <milli_timestamp>\n", .{});
    try console.print("  --sequence_length <int>    = <max_sequence_length>\n", .{});
    try console.print("  --prompt          <string> = \"\"\n", .{});
    try console.print("  --verbose\n", .{});
    try console.print("  --help\n", .{});

    std.process.exit(exit_status);
}
