import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_config.dart';

/// Thin wrapper around the shared Socket.io connection to shipryd-backend.
/// The server only checks the JWT once, at connection time (see the
/// backend's `io.use` handshake middleware) — so a single connect per
/// session is enough; it doesn't need to be refreshed alongside the access
/// token the way REST calls do.
class SocketClient {
  SocketClient._();
  static final SocketClient instance = SocketClient._();

  io.Socket? _socket;

  void connect(String accessToken) {
    disconnect();
    _socket = io.io(
      ApiConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .build(),
    );
  }

  io.Socket? get socket => _socket;

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
