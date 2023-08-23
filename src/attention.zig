const std = @import("std");

const checkpoint = @import("checkpoint.zig");
const lib = @import("lib.zig");

pub const Attention = struct {
    const Self = @This();

    head_size: usize,
    head_size_sqrt: f32,
    n_groups: usize,
    n_heads: usize,
    seq_len: usize,

    input_buffer: []f32,
    output_buffer: []f32,
    scores_buffer: []f32,
    queries_buffer: []f32,
    keys_buffer: []f32,
    values_buffer: []f32,
    key_cache: []f32,
    value_cache: []f32,

    pub fn init(self: *Self, allocator: std.mem.Allocator, config: *const checkpoint.Config) !void {
        self.head_size = config.dim / config.n_heads;
        self.head_size_sqrt = std.math.sqrt(@as(f32, @floatFromInt(self.head_size)));
        self.n_groups = config.n_heads / config.n_kv_heads;
        self.n_heads = config.n_heads;
        self.seq_len = config.seq_len;

        const kv_dim = (config.dim * config.n_kv_heads) / config.n_heads;

        self.input_buffer = try allocator.alloc(f32, config.dim);
        self.output_buffer = try allocator.alloc(f32, config.dim);
        self.scores_buffer = try allocator.alloc(f32, config.n_heads * config.seq_len);
        self.queries_buffer = try allocator.alloc(f32, config.dim);
        self.keys_buffer = try allocator.alloc(f32, kv_dim);
        self.values_buffer = try allocator.alloc(f32, kv_dim);
        self.key_cache = try allocator.alloc(f32, config.n_layers * config.seq_len * kv_dim);
        self.value_cache = try allocator.alloc(f32, config.n_layers * config.seq_len * kv_dim);
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.input_buffer);
        allocator.free(self.output_buffer);
        allocator.free(self.scores_buffer);
        allocator.free(self.queries_buffer);
        allocator.free(self.keys_buffer);
        allocator.free(self.values_buffer);
        allocator.free(self.key_cache);
        allocator.free(self.value_cache);
    }

    pub fn forward(
        self: *const Self,
        weights: *const checkpoint.Weights,
        pos: usize,
        layer: usize,
    ) !void {
        const dim = self.input_buffer.len;
        const kv_dim = self.keys_buffer.len;
        const query_weights_dim = dim * dim;
        const kv_weights_dim = dim * kv_dim;

        try lib.matmul3(
            .{
                self.queries_buffer,
                self.input_buffer,
                weights.query[(layer * query_weights_dim)..][0..query_weights_dim],
            },
            .{
                self.keys_buffer,
                self.input_buffer,
                weights.key[(layer * kv_weights_dim)..][0..kv_weights_dim],
            },
            .{
                self.values_buffer,
                self.input_buffer,
                weights.value[(layer * kv_weights_dim)..][0..kv_weights_dim],
            },
            dim >= 4096,
        );

        lib.rope(pos, self.head_size, self.queries_buffer, self.keys_buffer);

        const kv_cache_dim = self.seq_len * kv_dim;
        const kv_cache_layer_offset = layer * kv_cache_dim;

        @memcpy(
            self.key_cache[(kv_cache_layer_offset + pos * kv_dim)..][0..self.keys_buffer.len],
            self.keys_buffer,
        );

        @memcpy(
            self.value_cache[(kv_cache_layer_offset + pos * kv_dim)..][0..self.values_buffer.len],
            self.values_buffer,
        );

        for (0..self.n_heads) |head| {
            self.compute_weighted_values(pos, head, kv_cache_layer_offset);
        }

        lib.matmul(
            self.output_buffer,
            self.input_buffer,
            weights.attention_output[(layer * dim * dim)..][0..(dim * dim)],
        );
    }

    fn compute_weighted_values(
        self: *const Self,
        pos: usize,
        head: usize,
        kv_cache_layer_offset: usize,
    ) void {
        const kv_dim = self.keys_buffer.len;
        const group = head / self.n_groups;
        const kv_head_offset = group * self.head_size;
        const head_offset = head * self.head_size;
        const query = self.queries_buffer[head_offset..][0..self.head_size];
        const scores = self.scores_buffer[(head * self.seq_len)..];

        for (0..(pos + 1)) |prev_pos| {
            const kv_cache_head_offset = kv_cache_layer_offset + prev_pos * kv_dim + kv_head_offset;
            const key = self.key_cache[kv_cache_head_offset..][0..self.head_size];

            scores[prev_pos] = lib.dot(query, key) / self.head_size_sqrt;
        }

        lib.softmax(scores[0..(pos + 1)]);

        const weighted_values = self.input_buffer[head_offset..][0..self.head_size];

        @memset(weighted_values, 0);

        for (0..(pos + 1)) |prev_pos| {
            const kv_cache_head_offset = kv_cache_layer_offset + prev_pos * kv_dim + kv_head_offset;
            const value = self.value_cache[kv_cache_head_offset..];
            const weight = scores[prev_pos];

            for (0..self.head_size) |index| {
                weighted_values[index] += weight * value[index];
            }
        }
    }
};
