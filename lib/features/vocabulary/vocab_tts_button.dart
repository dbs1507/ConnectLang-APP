import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/tts_audio_cache.dart';
import 'vocabulary_controller.dart';

/// Botão de ouvir o termo — mesmo `tts-generate` do vocabulário no site.
/// O arquivo baixa quando o botão entra na tela; o toque só dá play se
/// o MP3 já estiver no aparelho.
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
  String? _loadedPath;
  Future<void>? _warm;
  int _warmGen = 0;

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
    _warmUp(TtsFetchPriority.background);
  }

  @override
  void didUpdateWidget(covariant VocabTtsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text &&
        oldWidget.language == widget.language) {
      return;
    }
    _loadedPath = null;
    _warm = null;
    unawaited(_player.stop());
    _warmUp(TtsFetchPriority.background);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _warmUp(TtsFetchPriority priority) {
    final gen = ++_warmGen;
    final job = _load(priority, gen);
    _warm = job;
    unawaited(
      job.then(
        (_) {},
        onError: (_, _) {
          if (gen == _warmGen) _warm = null;
        },
      ),
    );
  }

  Future<void> _load(TtsFetchPriority priority, int gen) async {
    final text = widget.text.trim();
    if (text.isEmpty) return;
    final cache = ref.read(ttsAudioCacheProvider);
    final repo = ref.read(vocabularyRepositoryProvider);
    final file = await cache.ensureFile(
      text: text,
      language: widget.language,
      priority: priority,
      resolveUrl: () => repo.fetchTtsUrl(text: text, language: widget.language),
    );
    if (!mounted || gen != _warmGen) return;
    if (_loadedPath == file.path &&
        _player.processingState != ProcessingState.idle) {
      return;
    }
    await _player.setFilePath(file.path);
    if (!mounted || gen != _warmGen) return;
    _loadedPath = file.path;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    if (_loadedPath != null &&
        (_player.processingState == ProcessingState.ready ||
            _player.processingState == ProcessingState.completed)) {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
      return;
    }
    setState(() => _loading = true);
    try {
      if (_warm == null) {
        _warmUp(TtsFetchPriority.immediate);
      } else {
        final text = widget.text.trim();
        final cache = ref.read(ttsAudioCacheProvider);
        final repo = ref.read(vocabularyRepositoryProvider);
        unawaited(
          cache
              .ensureFile(
                text: text,
                language: widget.language,
                resolveUrl: () =>
                    repo.fetchTtsUrl(text: text, language: widget.language),
              )
              .then((_) {}, onError: (_, _) {}),
        );
      }
      await _warm;
      if (!mounted || _loadedPath == null) return;
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      unawaited(_player.play());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _playing ? 'Pausar' : 'Ouvir',
      onPressed: _loading ? null : _toggle,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_playing ? LucideIcons.circle_pause : LucideIcons.volume_2),
    );
  }
}
