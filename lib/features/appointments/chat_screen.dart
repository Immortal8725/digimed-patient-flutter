import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/api_config.dart';
import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/realtime/realtime_service.dart';
import '../auth/auth_controller.dart';
import 'appointment_models.dart';
import 'appointments_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final List<ChatLine> _lines = [];
  bool _loading = true;
  String? _error;
  late final RealtimeService _realtime;

  @override
  void initState() {
    super.initState();
    _realtime = ref.read(realtimeServiceProvider);
    Future.microtask(_open);
  }

  Future<void> _open() async {
    _realtime.joinChat(widget.appointmentId);
    _realtime.addChatListener(_onSocket);
    try {
      final userId = ref.read(authControllerProvider).value?.userId ?? '';
      final lines = await ref
          .read(appointmentsRepositoryProvider)
          .chat(widget.appointmentId, userId);
      if (!mounted) return;
      setState(() {
        _lines
          ..clear()
          ..addAll(lines);
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  void _onSocket(dynamic data) {
    final map = asMap(data);
    final appointmentId = firstString(map, ['appointmentId']);
    if (appointmentId.isNotEmpty && appointmentId != widget.appointmentId) return;
    final userId = ref.read(authControllerProvider).value?.userId ?? '';
    final line = ChatLine.fromJson(map, userId);
    if (!mounted || line.text.isEmpty) return;
    setState(() {
      if (line.id.isEmpty || _lines.every((item) => item.id != line.id)) {
        _lines.add(line);
      }
    });
  }

  @override
  void dispose() {
    _realtime
      ..removeChatListener(_onSocket)
      ..leaveChat(widget.appointmentId);
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    try {
      final userId = ref.read(authControllerProvider).value?.userId ?? '';
      final line = await ref
          .read(appointmentsRepositoryProvider)
          .sendChat(widget.appointmentId, text, userId);
      _realtime.sendChat(
        widget.appointmentId,
        text,
        id: line.id,
        at: line.at,
      );
      if (!mounted) return;
      setState(() {
        if (line.id.isEmpty || _lines.every((item) => item.id != line.id)) {
          _lines.add(line);
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit chat')),
      body: Column(
        children: [
          if (!ApiConfig.realtimeEnabled)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Live chat updates are off until REALTIME_URL is set. Messages still save to your visit.',
              ),
            ),
          if (_error != null) Text(_error!),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final line in _lines)
                        Align(
                          alignment: line.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(line.text),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(hintText: 'Message the clinic'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
