import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/audio/tts_audio_cache.dart';
import '../../design_system/theme/app_colors.dart';
import '../../design_system/theme/app_spacing.dart';
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

  double _playbackRate = 1;
  String _voiceGender = 'female';

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
    final voiceGender = _voiceGender;
    final file = await cache.ensureFile(
      text: text,
      language: widget.language,
      voiceGender: voiceGender,
      priority: priority,
      resolveUrl: () => repo.fetchTtsUrl(
        text: text,
        language: widget.language,
        voiceGender: voiceGender,
      ),
    );
    if (!mounted || gen != _warmGen) return;
    if (_loadedPath == file.path &&
        _player.processingState != ProcessingState.idle) {
      return;
    }
    await _player.setFilePath(file.path);
    if (!mounted || gen != _warmGen) return;
    _loadedPath = file.path;
    try {
      await _player.setSpeed(_playbackRate);
    } catch (_) {}
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
        final voiceGender = _voiceGender;
        unawaited(
          cache
              .ensureFile(
                text: text,
                language: widget.language,
                voiceGender: voiceGender,
                resolveUrl: () => repo.fetchTtsUrl(
                  text: text,
                  language: widget.language,
                  voiceGender: voiceGender,
                ),
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

  Future<void> _nudgeRate(double delta) async {
    final next = (_playbackRate + delta).clamp(0.5, 1.75);
    setState(() => _playbackRate = double.parse(next.toStringAsFixed(2)));
    try {
      await _player.setSpeed(_playbackRate);
    } catch (_) {}
  }

  Future<void> _changeVoice(String gender) async {
    if (gender == _voiceGender) return;
    setState(() => _voiceGender = gender);
    _loadedPath = null;
    _warm = null;
    unawaited(_player.stop());
    _warmUp(TtsFetchPriority.background);
  }

  Future<void> _openAudioSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Áudio',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Mais devagar',
                        onPressed: _playbackRate <= 0.5
                            ? null
                            : () async {
                                await _nudgeRate(-0.1);
                                setSheetState(() {});
                              },
                        icon: const Icon(LucideIcons.minus, size: 18),
                      ),
                      Text(
                        '${_playbackRate.toStringAsFixed(2)}x',
                        style: Theme.of(sheetContext).textTheme.labelLarge
                            ?.copyWith(color: AppColors.heading),
                      ),
                      IconButton(
                        tooltip: 'Mais rápido',
                        onPressed: _playbackRate >= 1.75
                            ? null
                            : () async {
                                await _nudgeRate(0.1);
                                setSheetState(() {});
                              },
                        icon: const Icon(LucideIcons.plus, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Voz ♀'),
                        selected: _voiceGender == 'female',
                        onSelected: (_) async {
                          await _changeVoice('female');
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ChoiceChip(
                        label: const Text('Voz ♂'),
                        selected: _voiceGender == 'male',
                        onSelected: (_) async {
                          await _changeVoice('male');
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
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
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Velocidade e voz',
          onPressed: _openAudioSettings,
          icon: const Icon(LucideIcons.sliders_horizontal, size: 16),
        ),
      ],
    );
  }
}
