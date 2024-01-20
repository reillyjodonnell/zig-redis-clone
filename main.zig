const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const expect = std.testing.expect;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var server = Server.init(8080, allocator);

    try server.listen();
}

test "running with test allocator" {
    var server = Server.init(8080, std.testing.allocator);
    try server.listen();
}

const Server = struct {
    ip: []const u8 = "127.0.0.1",
    port: u16,
    allocator: std.mem.Allocator,

    pub fn init(port: u16, allocator: std.mem.Allocator) Server {
        return Server{ .port = port, .allocator = allocator };
    }

    pub fn listen(self: *Server) !void {
        var server = net.StreamServer.init(.{});
        defer server.deinit();

        try server.listen(net.Address.parseIp(self.ip, self.port) catch unreachable);

        var cache = try Cache.init(self.allocator);
        defer cache.deinit();

        while (true) {
            const connection = try server.accept();
            defer connection.stream.close();

            var buffer: [4096]u8 = undefined;
            while (true) {
                const bytes_read = try connection.stream.read(&buffer);
                if (bytes_read == 0) {
                    break; // connection closed
                }

                const message = buffer[0..bytes_read];

                const trimmedMessage = std.mem.trimRight(u8, message, "\n");

                const res = try parseMessageForCache(&cache, trimmedMessage);

                const result = try appendNewLine(self.allocator, res);

                defer self.allocator.free(result);

                // write the res
                const bytes_written = try connection.stream.writeAll(result);
                _ = bytes_written;
            }
        }
    }
};

pub fn appendNewLine(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, input.len + 1);
    std.mem.copy(u8, result[0..], input);
    result[input.len] = '\n';
    return result;
}

const Cache = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) !Cache {
        var map = std.StringHashMap([]const u8).init(allocator);
        return Cache{ .allocator = allocator, .map = map };
    }

    pub fn deinit(self: *Cache) void {
        self.map.clearAndFree();
    }

    pub fn set(self: *Cache, key: []const u8, value: []const u8) ![]const u8 {
        try self.map.put(key, value);
        return "OK";
    }
    pub fn get(self: *Cache, key: []const u8) []const u8 {
        return self.map.get(key) orelse "nil";
    }

    pub fn delete(self: *Cache, key: []const u8) []const u8 {
        const success = self.map.remove(key);
        if (success) {
            return "1";
        }
        return "0";
    }
};

test "cache" {
    var cache = try Cache.init(std.testing.allocator);

    defer cache.deinit();

    var res = try cache.set("hello", "world");
    try expect(std.mem.eql(u8, res, "OK"));

    const value = cache.get("hello");

    try expect(std.mem.eql(u8, value, "world"));

    const del = cache.delete("hello");

    try expect(std.mem.eql(u8, del, "1"));
}

// Declare an enum.
const Operations = enum {
    GET,
    SET,
    DEL,
};

const CommandError = error{InvalidCommand};

test "convert string to Opereation enum" {
    var get_token = try stringToOperation("get");
    try expect(get_token == Operations.GET);
}

fn stringToOperation(str: []const u8) !Operations {
    if (std.mem.eql(u8, str, "get")) return Operations.GET;
    if (std.mem.eql(u8, str, "set")) return Operations.SET;
    if (std.mem.eql(u8, str, "del")) return Operations.DEL;
    return CommandError.InvalidCommand;
}

fn tokenizeCommand(command: []const u8) !Operations {
    var it = std.mem.split(u8, command, " ");

    const operation = it.next() orelse return error.InvalidCommand;

    const tokenOperation = try stringToOperation(operation);

    return tokenOperation;
}

test "whole thing" {
    const msg: []const u8 = "set hello world";
    var cache = try Cache.init(std.testing.allocator);
    defer cache.deinit();

    const res = try parseMessageForCache(&cache, msg);
    std.debug.print("\n{s}\n", .{res});
    try expect(std.mem.eql(u8, res, "OK"));
}

fn parseMessageForCache(cache: *Cache, message: []const u8) ![]const u8 {
    const token = try tokenizeCommand(message);
    var it = std.mem.split(u8, message, " ");
    const command = it.next() orelse return CommandError.InvalidCommand;
    _ = command;

    switch (token) {
        Operations.GET => {
            const key = it.next() orelse return CommandError.InvalidCommand;
            return cache.get(key);
        },
        Operations.SET => {
            const key = it.next() orelse return CommandError.InvalidCommand;
            const value = it.next() orelse return CommandError.InvalidCommand;

            return try cache.set(key, value);
        },
        Operations.DEL => {
            const key = it.next() orelse return CommandError.InvalidCommand;
            return cache.delete(key);
        },
    }
}
