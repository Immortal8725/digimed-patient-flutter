import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

/// Optional Socket.IO client. Stays idle when [ApiConfig.realtimeUrl] is empty.
class RealtimeService {
  io.Socket? _socket;
  final List<void Function(dynamic data)> _chatHandlers = [];
  final List<void Function(dynamic data)> _notifyHandlers = [];

  bool get connected => _socket?.connected == true;
  bool get enabled => ApiConfig.realtimeEnabled;

  void connect(String token) {
    if (!enabled || token.isEmpty) return;
    if (_socket != null) {
      _socket!.auth = {'token': token};
      if (_socket!.connected != true) _socket!.connect();
      return;
    }
    final socket = io.io(
      ApiConfig.realtimeUrl.trim(),
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .enableAutoConnect()
          .build(),
    );
    socket.on('connect', (_) => socket.emit('notify:subscribe'));
    socket.on('chat:message', (data) {
      for (final handler in List.of(_chatHandlers)) {
        handler(data);
      }
    });
    socket.on('notify:event', (data) {
      for (final handler in List.of(_notifyHandlers)) {
        handler(data);
      }
    });
    _socket = socket;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void joinChat(String appointmentId) {
    _socket?.emit('chat:join', {'appointmentId': appointmentId});
  }

  void leaveChat(String appointmentId) {
    _socket?.emit('chat:leave', {'appointmentId': appointmentId});
  }

  void sendChat(
    String appointmentId,
    String text, {
    String? id,
    String? at,
  }) {
    if (_socket == null) return;
    _socket!.emit('chat:message', {
      'appointmentId': appointmentId,
      'text': text,
      if (id != null && id.isNotEmpty) 'id': id,
      if (at != null && at.isNotEmpty) 'at': at,
    });
  }

  void addChatListener(void Function(dynamic data) handler) {
    _chatHandlers.add(handler);
  }

  void removeChatListener(void Function(dynamic data) handler) {
    _chatHandlers.remove(handler);
  }

  void addNotifyListener(void Function(dynamic data) handler) {
    _notifyHandlers.add(handler);
  }

  void removeNotifyListener(void Function(dynamic data) handler) {
    _notifyHandlers.remove(handler);
  }
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService();
  ref.onDispose(service.disconnect);
  return service;
});
