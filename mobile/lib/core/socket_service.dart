import 'package:socket_io_client/socket_io_client.dart' as io;
import 'config.dart';
import 'secure_storage.dart';
import 'server_clock.dart';

/// One socket connection per live-board / inbox screen, joined to a single
/// request's rooms. The server enforces blind bidding at the room level
/// (see backend RequestsGateway) — a valuer's socket is simply never put
/// in the `board:*` room, so `quote.created`/`quote.updated` never reach it
/// regardless of what this client does.
class RequestSocket {
  io.Socket? _socket;

  Future<void> connect({
    required String requestId,
    required void Function(Map<String, dynamic> snapshot) onSnapshot,
    void Function(Map<String, dynamic> quote)? onQuoteCreated,
    void Function(Map<String, dynamic> quote)? onQuoteUpdated,
    void Function(Map<String, dynamic> summary)? onClosed,
    void Function(int secondsLeft)? onTick,
    void Function(Map<String, dynamic> photo)? onPhotoAdded,
    void Function()? onEscalated,
  }) async {
    final token = await TokenStorage.readAccess();
    _socket = io.io(
      '${AppConfig.wsBaseUrl}/requests',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    void join() => _socket!.emit('join', {'requestId': requestId, 'token': token});

    _socket!.onConnect((_) => join());
    // Re-sync on every reconnect per the server-authoritative countdown rule.
    _socket!.onReconnect((_) => join());

    _socket!.on('request.snapshot', (data) {
      final map = Map<String, dynamic>.from(data);
      ServerClock.sync(map['serverNow'] as int);
      onSnapshot(map);
    });
    if (onQuoteCreated != null) {
      _socket!.on('quote.created', (data) => onQuoteCreated(Map<String, dynamic>.from(data)));
    }
    if (onQuoteUpdated != null) {
      _socket!.on('quote.updated', (data) => onQuoteUpdated(Map<String, dynamic>.from(data)));
    }
    if (onClosed != null) {
      _socket!.on('request.closed', (data) => onClosed(Map<String, dynamic>.from(data)));
    }
    if (onTick != null) {
      _socket!.on('tick', (data) {
        final map = Map<String, dynamic>.from(data);
        ServerClock.sync(map['serverNow'] as int);
        onTick(map['secondsLeft'] as int);
      });
    }
    if (onPhotoAdded != null) {
      _socket!.on('photo.added', (data) => onPhotoAdded(Map<String, dynamic>.from(data)));
    }
    if (onEscalated != null) {
      _socket!.on('request.escalated', (_) => onEscalated());
    }

    _socket!.connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
