import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'vocabulary_controller.dart';

/// Botão de ouvir o termo — mesmo `tts-generate` do vocabulário no site.
class VocabTtsButton extends ConsumerStatefulWidget {
  const VocabTtsButton({super.key, required this.text, required this.language});

  final String text;
  final String language;

  @override
  ConsumerState<VocabTtsButton> createState() => _VocabTtsButtonState();
}

class _VocabTtsButtonState extends ConsumerState<VocabTtsButton> {
  final _player = AudioPlayer();
  bool _loading = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(
        () => _playing =
            state.playing && state.processingState != ProcessingState.completed,
      );
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.ready ||
        _player.processingState == ProcessingState.completed) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await ref
          .read(vocabularyRepositoryProvider)
          .fetchTtsUrl(text: widget.text, language: widget.language);
      if (!mounted) return;
      if (url == null || url.isEmpty) return;
      await _player.setUrl(url);
      unawaited(_player.play());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _playing ? 'Pausar' : 'Ouvir',
      onPressed: _loading ? null : _toggle,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _playing ? Icons.pause_circle_outline : Icons.volume_up_outlined,
            ),
    );
  }
}
