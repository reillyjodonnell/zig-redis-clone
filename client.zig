const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const expect = std.testing.expect;

test "Connect to redis" {
    var client = try Client.init(8080, std.testing.allocator);
    const buffer_size = 1024;
    var buffer = try std.testing.allocator.alloc(u8, buffer_size);
    defer std.testing.allocator.free(buffer);
    const res = try client.set("hi", "world", buffer);

    try expect(std.mem.eql(u8, res, "OK"));
}

const Client = struct {
    ip: []const u8 = "127.0.0.1",
    port: u16,
    address: std.net.Address,
    allocator: std.mem.Allocator,

    pub fn init(port: u16, allocator: std.mem.Allocator) !Client {
        const address = try std.net.Address.parseIp4("127.0.0.1", port);

        return Client{ .port = port, .allocator = allocator, .address = address };
    }

    pub fn connect(self: *Client) !void {
        // Create a TCP client socket
        const client_socket = try std.net.tcpConnectToAddress(self.address);
        _ = client_socket;
        defer self.socket.close();
    }

    fn set(self: *Client, key: []const u8, value: []const u8, buffer: []u8) ![]const u8 {
        const client_socket = try std.net.tcpConnectToAddress(self.address);
        defer client_socket.close();
        const message = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ key, value });
        defer self.allocator.free(message);
        const size = try client_socket.write(message);
        _ = size;
        const read_bytes = try client_socket.readAll(buffer);
        return buffer[0..read_bytes];
    }
};
