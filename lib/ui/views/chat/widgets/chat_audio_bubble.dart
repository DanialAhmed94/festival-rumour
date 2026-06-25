import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Inline voice-note player for a chat bubble: play/pause, seek bar, duration.
/// The [AudioPlayer] is created lazily on first play and disposed with the widget.
class ChatAudioBubble extends StatefulWidget {
  final String url;
  final int? durationMs;
  final Color accent;

  const ChatAudioBubble({
    super.key,
    required this.url,
    this.durationMs,
    this.accent = const Color(0xFFFC2E95),
  });

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null) {
      _total = Duration(milliseconds: widget.durationMs!);
    }
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    final player = AudioPlayer();
    _player = player;
    _posSub = player.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _durSub = player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _total = d);
    });
    _stateSub = player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing =
          s.playing && s.processingState != ProcessingState.completed);
      if (s.processingState == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
        if (mounted) setState(() => _pos = Duration.zero);
      }
    });
    try {
      setState(() => _loading = true);
      await player.setUrl(widget.url);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  @override
  void dispose() {
    try {
      _player?.stop();
    } catch (_) {}
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = _total.inMilliseconds > 0 ? _total.inMilliseconds : 1;
    final val = _pos.inMilliseconds.clamp(0, maxMs).toDouble();
    final label = _playing || _pos > Duration.zero ? _pos : _total;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: _loading
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    size: 36,
                    color: widget.accent,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 10),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxMs.toDouble(),
                      value: val,
                      activeColor: widget.accent,
                      inactiveColor: const Color(0xFFD9D9D9),
                      onChanged: (v) async {
                        await _ensurePlayer();
                        await _player?.seek(Duration(milliseconds: v.toInt()));
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    _fmt(label),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
