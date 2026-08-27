import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../vocabulary/models/vocabulary_entry.dart';
import 'library_controller.dart';
import 'models/library_text.dart';
import 'models/text_question.dart';
import 'text_questions_page.dart';

class TextReadingPage extends ConsumerStatefulWidget {
  const TextReadingPage({super.key, required this.text});

  final LibraryText text;

  @override
  ConsumerState<TextReadingPage> createState() => _TextReadingPageState();
}

class _TextReadingPageState extends ConsumerState<TextReadingPage> {
  final _player = AudioPlayer();

  bool _loadingAudio = false;
  bool _isPlaying = false;
  String? _audioError;

  TextQuestionSet? _questionSet;
  bool _loadingQuestions = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionSet();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing && state.processingState != ProcessingState.completed);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionSet() async {
    try {
      final set = await ref.read(libraryRepositoryProvider).fetchQuestionSet(widget.text.id);
      if (!mounted) return;
      setState(() => _questionSet = set);
    } catch (_) {
      // Sem perguntas — não bloqueia a leitura.
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      unawaited(_player.play());
      return;
    }
    if (_player.processingState == ProcessingState.ready) {
      // Retoma de onde pausou — só reinicia do zero quando o áudio já terminou.
      unawaited(_player.play());
      return;
    }

    setState(() {
      _loadingAudio = true;
      _audioError = null;
    });
    try {
      final chunks = await ref.read(libraryRepositoryProvider).fetchTtsChunks(widget.text.id);
      if (chunks.isEmpty) {
        setState(() => _audioError = 'Não foi possível gerar o áudio deste texto.');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final sources = <AudioSource>[];
      for (var i = 0; i < chunks.length; i++) {
        final base64Audio = chunks[i]['audioContentBase64'] as String? ?? '';
        if (base64Audio.isEmpty) continue;
        final bytes = base64Decode(base64Audio);
        final file = File('${tempDir.path}/text_tts_${widget.text.id}_$i.mp3');
        await file.writeAsBytes(bytes, flush: true);
        sources.add(AudioSource.file(file.path));
      }
      if (sources.isEmpty) {
        setState(() => _audioError = 'Não foi possível gerar o áudio deste texto.');
        return;
      }
      await _player.setAudioSources(sources);
      // `play()` só resolve quando a última faixa termina (ou é interrompida)
      // — não podemos aguardar aqui ou o botão fica travado até o fim do áudio.
      unawaited(_player.play());
    } catch (e, st) {
      debugPrint('TEXT_TTS_ERROR: $e\n$st');
      if (mounted) setState(() => _audioError = 'Não foi possível tocar o áudio.');
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  void _openQuestions() {
    final set = _questionSet;
    if (set == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TextQuestionsPage(questionSet: set)));
  }

  @override
  Widget build(BuildContext context) {
    final isRead = ref.watch(libraryControllerProvider).value?.isRead(widget.text.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(isRead ? Icons.check_circle : Icons.check_circle_outline),
            tooltip: isRead ? 'Marcar como não lido' : 'Marcar como lido',
            onPressed: () => ref.read(libraryControllerProvider.notifier).toggleRead(widget.text.id),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(taughtLanguages[widget.text.language] ?? widget.text.language)),
                  if (widget.text.cefr != null) Chip(label: Text(widget.text.cefr!)),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadingAudio ? null : _toggleAudio,
                icon: _loadingAudio
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pausar áudio' : 'Ouvir texto'),
              ),
              if (_audioError != null) ...[
                const SizedBox(height: 8),
                Text(_audioError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              MarkdownBody(data: widget.text.content),
              if (_questionSet != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openQuestions,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Perguntas de compreensão'),
                ),
              ] else if (!_loadingQuestions) ...[
                const SizedBox(height: 24),
                Text(
                  'Ainda não há perguntas de compreensão pra este texto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
