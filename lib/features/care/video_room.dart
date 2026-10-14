import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/json/json_values.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import 'care_repository.dart';

class VideoRoom extends ConsumerStatefulWidget {
  const VideoRoom({
    super.key,
    required this.sessionId,
    required this.consentReady,
    this.roomStatus = '',
    this.roomLabel = '',
  });

  final String sessionId;
  final bool consentReady;
  final String roomStatus;
  final String roomLabel;

  @override
  ConsumerState<VideoRoom> createState() => _VideoRoomState();
}

class _VideoRoomState extends ConsumerState<VideoRoom> {
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  RTCPeerConnection? _peer;
  MediaStream? _stream;
  Timer? _poll;
  int _afterId = 0;
  int _userId = 0;
  bool _ready = false;
  bool _busy = false;
  bool _makingOffer = false;
  bool _remoteOn = false;
  bool _muted = false;
  String _phase = 'idle';
  String _status = '';
  String? _error;
  List<Map<String, dynamic>> _ice = const [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  bool get _polite => _userId % 2 == 0;

  @override
  void initState() {
    super.initState();
    _status = widget.roomStatus;
    Future.microtask(_prepare);
  }

  Future<void> _prepare() async {
    await _local.initialize();
    await _remote.initialize();
    final stored = await ref.read(tokenStoreProvider).read('userId');
    _userId = int.tryParse(stored ?? '') ?? 0;
    try {
      final servers = await ref.read(careRepositoryProvider).iceServers();
      if (servers.isNotEmpty) _ice = servers;
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<MediaStream> _camera() async {
    final existing = _stream;
    if (existing != null) return existing;
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    _stream = stream;
    _local.srcObject = stream;
    return stream;
  }

  Future<RTCPeerConnection> _connection() async {
    final current = _peer;
    if (current != null) return current;
    final peer = await createPeerConnection({'iceServers': _ice});
    _peer = peer;
    final stream = await _camera();
    for (final track in stream.getTracks()) {
      await peer.addTrack(track, stream);
    }
    peer.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remote.srcObject = event.streams.first;
      if (mounted) {
        setState(() {
          _remoteOn = true;
          _phase = 'connected';
        });
      }
    };
    peer.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      unawaited(() async {
        try {
          await ref.read(careRepositoryProvider).sendVideoSignal(
            sessionId: widget.sessionId,
            type: 'ICE',
            payload: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          );
        } catch (_) {}
      }());
    };
    peer.onConnectionState = (state) {
      if (!mounted) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _phase = 'connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        setState(() {
          if (_phase != 'idle') _phase = 'connecting';
        });
      }
    };
    return peer;
  }

  Future<void> _signal(String type, Object? payload) {
    return ref.read(careRepositoryProvider).sendVideoSignal(
      sessionId: widget.sessionId,
      type: type,
      payload: payload,
    );
  }

  Map<String, dynamic>? _asPayload(Object? payload) {
    if (payload is Map) return asMap(payload);
    if (payload is String && payload.isNotEmpty) {
      try {
        return asMap(jsonDecode(payload));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _onSignal(Map<String, dynamic> signal) async {
    final type = firstString(signal, ['type']);
    final payload = _asPayload(signal['payload']);
    if (type == 'HANGUP') {
      if (mounted) {
        setState(() {
          _remoteOn = false;
          _phase = 'idle';
        });
      }
      return;
    }
    final peer = await _connection();
    final local = await peer.getLocalDescription();
    if (payload != null && local != null && payload['sdp'] == local.sdp) return;
    if (type == 'ICE' && payload != null) {
      try {
        await peer.addCandidate(
          RTCIceCandidate(
            str(payload['candidate']),
            str(payload['sdpMid']),
            asInt(payload['sdpMLineIndex']),
          ),
        );
      } catch (_) {}
      return;
    }
    if (type == 'OFFER' && payload != null) {
      final stable = peer.signalingState == RTCSignalingState.RTCSignalingStateStable;
      if (_makingOffer || !stable) {
        if (!_polite) return;
        try {
          await peer.setLocalDescription(RTCSessionDescription('', 'rollback'));
        } catch (_) {}
      }
      await peer.setRemoteDescription(
        RTCSessionDescription(str(payload['sdp']), str(payload['type'])),
      );
      final answer = await peer.createAnswer();
      await peer.setLocalDescription(answer);
      await _signal('ANSWER', {'type': answer.type, 'sdp': answer.sdp});
      if (mounted) setState(() => _phase = 'connecting');
      return;
    }
    if (type == 'ANSWER' && payload != null) {
      await peer.setRemoteDescription(
        RTCSessionDescription(str(payload['sdp']), str(payload['type'])),
      );
      if (mounted) setState(() => _phase = 'connecting');
    }
  }

  void _listen() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      try {
        final rows = await ref.read(careRepositoryProvider).videoSignals(
          sessionId: widget.sessionId,
          afterId: _afterId,
        );
        for (final row in rows) {
          final id = asInt(row['id']) ?? 0;
          if (id > _afterId) _afterId = id;
          await _onSignal(row);
        }
      } catch (_) {}
    });
  }

  Future<void> _preview() async {
    setState(() => _error = null);
    try {
      await _camera();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Camera or microphone is unavailable, or permission was denied.');
      }
    }
  }

  Future<void> _start() async {
    if (!widget.consentReady) {
      setState(
        () => _error =
            'Record the video consent before starting. The patient, the doctor, the practice number, and suitability are required.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final started = await ref.read(careRepositoryProvider).beginVideoRoom(widget.sessionId);
      final next = firstString(started, ['status']);
      await _camera();
      final peer = await _connection();
      _listen();
      if (_userId > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 + (_userId % 7) * 120));
        _makingOffer = true;
        try {
          final offer = await peer.createOffer();
          await peer.setLocalDescription(offer);
          await _signal('OFFER', {'type': offer.type, 'sdp': offer.sdp});
        } finally {
          _makingOffer = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _phase = 'connecting';
        if (next.isNotEmpty) _status = next;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start the video session.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    setState(() => _busy = true);
    try {
      try {
        await _signal('HANGUP', {});
      } catch (_) {}
      final ended = await ref.read(careRepositoryProvider).endVideoRoom(widget.sessionId);
      await _hangupLocal();
      if (!mounted) return;
      setState(() {
        _status = firstString(ended, ['status']).isEmpty ? 'ENDED' : firstString(ended, ['status']);
        _phase = 'idle';
        _remoteOn = false;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _hangupLocal() async {
    _poll?.cancel();
    final peer = _peer;
    _peer = null;
    if (peer != null) {
      try {
        await peer.close();
      } catch (_) {}
    }
    final stream = _stream;
    _stream = null;
    stream?.getTracks().forEach((track) => track.stop());
    _local.srcObject = null;
    _remote.srcObject = null;
  }

  void _mute() {
    final stream = _stream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !track.enabled;
    }
    setState(() => _muted = !_muted);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _stream?.getTracks().forEach((track) => track.stop());
    _peer?.close();
    _local.dispose();
    _remote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ended = _status.toUpperCase() == 'ENDED';
    final phaseLabel = _phase == 'connected'
        ? 'Peer connected'
        : _phase == 'connecting'
        ? 'Connecting'
        : _remoteOn
        ? 'Remote video'
        : 'Waiting for the other person';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.roomLabel.isEmpty ? 'DigiMed telehealth' : widget.roomLabel),
        Text(_status.isEmpty ? phaseLabel : '$_status, $phaseLabel'),
        if (_error != null)
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        if (!_ready)
          const LinearProgressIndicator()
        else ...[
          const Text('You'),
          SizedBox(height: 180, child: RTCVideoView(_local, mirror: true)),
          const SizedBox(height: 8),
          const Text('Clinic'),
          SizedBox(
            height: 180,
            child: _remoteOn
                ? RTCVideoView(_remote)
                : const ColoredBox(
                    color: Color(0xFF020617),
                    child: Center(child: Text('Waiting for the other person')),
                  ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Record video consent before anyone starts the visit. Camera preview does not start the consultation.',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!ended && _phase == 'idle')
              FilledButton(
                onPressed: _busy || !_ready ? null : _start,
                child: Text(
                  _busy
                      ? 'Opening...'
                      : _status.toUpperCase() == 'LIVE'
                      ? 'Join consultation'
                      : 'Start consultation',
                ),
              ),
            if (_status.toUpperCase() == 'LIVE' || _phase != 'idle')
              FilledButton(
                onPressed: _busy ? null : _end,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('End consultation'),
              ),
            OutlinedButton(
              onPressed: _stream == null ? null : _mute,
              child: Text(_muted ? 'Unmute' : 'Mute'),
            ),
            OutlinedButton(onPressed: _busy ? null : _preview, child: const Text('Enable camera')),
          ],
        ),
      ],
    );
  }
}
