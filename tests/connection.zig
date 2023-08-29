const std = @import("std");

const nats = @import("nats");

const util = @import("./util.zig");

test "nats.Connection.connectTo" {
    {
        var server = try util.TestServer.launch(.{});
        defer server.stop();

        try nats.init(nats.default_spin_count);
        defer nats.deinit();

        const connection = try nats.Connection.connectTo(nats.default_server_url);
        defer connection.destroy();
    }

    {
        var server = try util.TestServer.launch(.{
            .auth = .{ .token = "test_token" },
        });
        defer server.stop();

        try nats.init(nats.default_spin_count);
        defer nats.deinit();

        const connection = try nats.Connection.connectTo("nats://test_token@127.0.0.1:4222");
        defer connection.destroy();
    }

    {
        var server = try util.TestServer.launch(.{ .auth = .{
            .password = .{ .user = "user", .pass = "password" },
        } });
        defer server.stop();

        try nats.init(nats.default_spin_count);
        defer nats.deinit();

        const connection = try nats.Connection.connectTo("nats://user:password@127.0.0.1:4222");
        defer connection.destroy();
    }
}

fn tokenHandler(userdata: *u32) [:0]const u8 {
    _ = userdata;
    return "token";
}

fn reconnectDelayHandler(userdata: *u32, connection: *nats.Connection, attempts: c_int) i64 {
    _ = userdata;
    _ = connection;
    _ = attempts;

    return 0;
}

fn errorHandler(
    userdata: *u32,
    connection: *nats.Connection,
    subscription: *nats.Subscription,
    status: nats.Status,
) void {
    _ = userdata;
    _ = connection;
    _ = subscription;
    _ = status;
}

fn connectionHandler(userdata: *u32, connection: *nats.Connection) void {
    _ = userdata;
    _ = connection;
}

fn jwtHandler(userdata: *u32) nats.JwtResponseOrError {
    _ = userdata;
    // return .{ .jwt = std.heap.raw_c_allocator.dupeZ(u8, "abcdef") catch @panic("no!") };
    return .{ .error_message = std.heap.raw_c_allocator.dupeZ(u8, "dang") catch @panic("no!") };
}

fn signatureHandler(userdata: *u32, nonce: [:0]const u8) nats.SignatureResponseOrError {
    _ = userdata;
    _ = nonce;
    // return .{ .signature = std.heap.raw_c_allocator.dupe(u8, "01230123") catch @panic("no!") };
    return .{ .error_message = std.heap.raw_c_allocator.dupeZ(u8, "whoops") catch @panic("no!") };
}

test "nats.ConnectionOptions" {
    try nats.init(nats.default_spin_count);
    defer nats.deinit();

    const options = try nats.ConnectionOptions.create();
    defer options.destroy();

    var userdata: u32 = 0;

    try options.setUrl(nats.default_server_url);
    const servers = [_][*:0]const u8{ "nats://127.0.0.1:4442", "nats://127.0.0.1:4443" };
    try options.setServers(&servers);
    try options.setCredentials("user", "password");
    try options.setToken("test_token");
    // requires a functioning token handler, which I will not write right now. Also
    // cannot be called if a token has already been set
    // try options.setTokenHandler(u32, tokenHandler, &userdata);
    try options.setNoRandomize(false);
    try options.setTimeout(1000);
    try options.setName("name");

    // the following all require a build with openssl
    // try options.setSecure(false);
    // try options.setCiphers("-ALL:HIGH");
    // try options.setCipherSuites("TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256");
    // try options.setExpectedHostname("host.name");
    // try options.skipServerVerification(true);
    try options.setVerbose(true);
    try options.setPedantic(true);
    try options.setPingInterval(1000);
    try options.setMaxPingsOut(100);
    try options.setIoBufSize(1024);
    try options.setAllowReconnect(false);
    try options.setMaxReconnect(10);
    try options.setReconnectWait(500);
    try options.setReconnectJitter(100, 200);
    try options.setCustomReconnectDelay(u32, reconnectDelayHandler, &userdata);
    try options.setReconnectBufSize(1024);
    try options.setMaxPendingMessages(50);
    try options.setErrorHandler(u32, errorHandler, &userdata);
    try options.setClosedCallback(u32, connectionHandler, &userdata);
    try options.setDisconnectedCallback(u32, connectionHandler, &userdata);
    try options.setDiscoveredServersCallback(u32, connectionHandler, &userdata);
    try options.setLameDuckModeCallback(u32, connectionHandler, &userdata);
    try options.ignoreDiscoveredServers(true);
    try options.useGlobalMessageDelivery(false);
    try options.ipResolutionOrder(.ipv4_first);
    try options.setSendAsap(true);
    try options.useOldRequestStyle(false);
    try options.setFailRequestsOnDisconnect(true);
    try options.setNoEcho(true);
    try options.setRetryOnFailedConnect(u32, connectionHandler, true, &userdata);
    try options.setUserCredentialsCallbacks(u32, u32, jwtHandler, signatureHandler, &userdata, &userdata);
    try options.setWriteDeadline(5);
    try options.disableNoResponders(true);
    try options.setCustomInboxPrefix("_FOOBOX");
    try options.setMessageBufferPadding(123);
}
