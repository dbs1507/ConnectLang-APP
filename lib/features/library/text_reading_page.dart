import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../notebook/notebook_fab.dart';
import '../vocabulary/models/vocab_category.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import '../vocabulary/vocabulary_controller.dart';
import '../vocabulary/vocabulary_repository.dart';
import 'library_controller.dart';
import 'library_repository.dart';
import 'models/inline_translation.dart';
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
  late LibraryText _text = widget.text;
  final _player = AudioPlayer();

  bool _loadingAudio = false;
  bool _isPlaying = false;
  String? _audioError;
  String _voiceGender = 'female';
  double _playbackRate = 1;

  TextQuestionSet? _questionSet;
  bool _loadingQuestions = true;
  bool _generatingQuestions = false;
  bool _savingPersonal = false;
  String? _ownedError;

  bool _showTranslationOptions = false;
  bool _showInlineTranslation = false;
  bool _translatingInline = false;
  late String _translationTargetLang = _text.language == 'PT' ? 'EN' : 'PT';
  final Map<String, String> _translations = {};
  final Set<String> _loadingKeys = {};
  String? _translationError;
  int _translationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestionSet();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(
        () => _isPlaying =
            state.playing && state.processingState != ProcessingState.completed,
      );
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadQuestionSet() async {
    setState(() => _loadingQuestions = true);
    try {
      final set = await ref
          .read(libraryRepositoryProvider)
          .fetchQuestionSet(_text.id, sourceType: _text.sourceKind.raw);
      if (!mounted) return;
      setState(() => _questionSet = set);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingQuestions = false);
    }
  }

  Future<void> _resetAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
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
      unawaited(_player.play());
      return;
    }

    setState(() {
      _loadingAudio = true;
      _audioError = null;
    });
    try {
      final chunks = await ref
          .read(libraryRepositoryProvider)
          .fetchTtsChunks(text: _text, voiceGender: _voiceGender);
      if (chunks.isEmpty) {
        setState(
          () => _audioError = 'Não foi possível gerar o áudio deste texto.',
        );
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final sources = <AudioSource>[];
      for (var i = 0; i < chunks.length; i++) {
        final base64Audio = chunks[i]['audioContentBase64'] as String? ?? '';
        if (base64Audio.isEmpty) continue;
        final bytes = base64Decode(base64Audio);
        final file = File(
          '${tempDir.path}/text_tts_${_text.sourceKind.raw}_${_text.id}_${_voiceGender}_$i.mp3',
        );
        await file.writeAsBytes(bytes, flush: true);
        sources.add(AudioSource.file(file.path));
      }
      if (sources.isEmpty) {
        setState(
          () => _audioError = 'Não foi possível gerar o áudio deste texto.',
        );
        return;
      }
      await _player.setAudioSources(sources);
      await _player.setSpeed(_playbackRate);
      unawaited(_player.play());
    } catch (e, st) {
      debugPrint('TEXT_TTS_ERROR: $e\n$st');
      if (mounted) {
        setState(() => _audioError = 'Não foi possível tocar o áudio.');
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _changeVoice(String gender) async {
    if (gender == _voiceGender) return;
    await _resetAudio();
    setState(() => _voiceGender = gender);
  }

  Future<void> _nudgeRate(double delta) async {
    final next = (_playbackRate + delta).clamp(0.5, 1.75);
    setState(() => _playbackRate = double.parse(next.toStringAsFixed(2)));
    try {
      await _player.setSpeed(_playbackRate);
    } catch (_) {}
  }

  void _openQuestions() {
    final set = _questionSet;
    if (set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextQuestionsPage(
          questionSet: set,
          language: _text.language,
          textId: _text.id,
        ),
      ),
    );
  }

  Future<void> _generateQuestions() async {
    setState(() {
      _generatingQuestions = true;
      _ownedError = null;
    });
    try {
      final set = await ref
          .read(libraryRepositoryProvider)
          .generateQuestions(
            sourceType: _text.sourceKind.raw,
            sourceId: _text.id,
          );
      if (!mounted) return;
      if (set == null) {
        setState(
          () => _ownedError = 'Não foi possível gerar as perguntas agora.',
        );
        return;
      }
      setState(() => _questionSet = set);
    } catch (_) {
      if (mounted) {
        setState(
          () => _ownedError = 'Não foi possível gerar as perguntas agora.',
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQuestions = false);
    }
  }

  Future<void> _saveToPersonal() async {
    setState(() {
      _savingPersonal = true;
      _ownedError = null;
    });
    try {
      final personal = await ref
          .read(libraryControllerProvider.notifier)
          .saveTemporaryToPersonal(_text);
      if (!mounted) return;
      setState(() => _text = personal);
      await _resetAudio();
      await _loadQuestionSet();
    } on OwnedTextException catch (e) {
      setState(() {
        _ownedError = switch (e.code) {
          'personal_cap' =>
            'Você já tem $personalTextsSoftCap textos pessoais.',
          'already_saved' => 'Esse texto já foi salvo.',
          'expired' => 'Esse texto temporário já expirou.',
          _ => 'Não foi possível guardar o texto.',
        };
      });
    } catch (_) {
      setState(() => _ownedError = 'Não foi possível guardar o texto.');
    } finally {
      if (mounted) setState(() => _savingPersonal = false);
    }
  }

  void _openCapture() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SaveVocabFromTextSheet(text: _text),
    );
  }

  String _lineKey(InlineTranslationUnit unit) {
    return '${_text.id}:${translationLocaleFromAppLanguage(_translationTargetLang)}:${unit.id}';
  }

  Future<void> _toggleInlineTranslation() async {
    if (_showInlineTranslation) {
      setState(() {
        _showInlineTranslation = false;
        _translationError = null;
      });
      return;
    }
    setState(() => _showInlineTranslation = true);
    await _loadInlineTranslations();
  }

  Future<void> _loadInlineTranslations() async {
    final units = buildInlineTranslationUnits(_text.content);
    final locale = translationLocaleFromAppLanguage(_translationTargetLang);
    final missing = units
        .where((unit) => !_translations.containsKey(_lineKey(unit)))
        .toList();
    if (missing.isEmpty) {
      setState(() => _translationError = null);
      return;
    }

    final requestId = ++_translationRequestId;
    setState(() {
      _translatingInline = true;
      _translationError = null;
      for (final unit in missing) {
        _loadingKeys.add(_lineKey(unit));
      }
    });

    final repo = ref.read(libraryRepositoryProvider);
    try {
      final cache = await repo.fetchTranslationCache(
        text: _text,
        targetLocale: locale,
        segmentKeys: [for (final unit in missing) unit.id],
      );
      if (!mounted || requestId != _translationRequestId) return;

      final unresolved = <InlineTranslationUnit>[];
      for (final unit in missing) {
        final hash = hashTranslationSource(unit.text);
        final cached = extractPrimaryTranslation(
          cache['${unit.id}:$hash'] ?? '',
        );
        final key = _lineKey(unit);
        if (cached.isNotEmpty) {
          _translations[key] = cached;
          _loadingKeys.remove(key);
        } else {
          unresolved.add(unit);
        }
      }
      setState(() {});

      var failedCount = 0;
      for (final unit in unresolved) {
        if (!mounted || requestId != _translationRequestId) return;
        final key = _lineKey(unit);
        final translated = await repo.translateSentence(
          text: unit.text,
          language: _text.language,
          targetLocale: locale,
        );
        if (!mounted || requestId != _translationRequestId) return;
        if (translated == null || translated.isEmpty) {
          failedCount += 1;
          _loadingKeys.remove(key);
          setState(() {});
          continue;
        }
        _translations[key] = translated;
        _loadingKeys.remove(key);
        setState(() {});
        try {
          await repo.upsertTranslationCache(
            text: _text,
            targetLocale: locale,
            segmentKey: unit.id,
            sourceText: unit.text,
            sourceHash: hashTranslationSource(unit.text),
            translation: translated,
          );
        } catch (_) {}
      }

      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        _translatingInline = false;
        if (failedCount == 1) {
          _translationError = 'Não foi possível traduzir 1 trecho.';
        } else if (failedCount > 1) {
          _translationError = 'Não foi possível traduzir $failedCount trechos.';
        }
      });
    } catch (_) {
      if (!mounted || requestId != _translationRequestId) return;
      setState(() {
        _translatingInline = false;
        _translationError = 'Não foi possível traduzir o texto agora.';
      });
    }
  }

  List<Widget> _inlineTranslationBody(BuildContext context) {
    final units = buildInlineTranslationUnits(_text.content);
    return [
      for (var i = 0; i < units.length; i++) ...[
        Padding(
          padding: EdgeInsets.only(
            top: i == 0 ? 0 : (units[i].startsNewParagraph ? 16 : 10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(units[i].text),
              const SizedBox(height: 4),
              Text(
                _loadingKeys.contains(_lineKey(units[i]))
                    ? 'Traduzindo…'
                    : (_translations[_lineKey(units[i])] ??
                          'Tradução indisponível'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isRead =
        ref.watch(libraryControllerProvider).value?.isRead(_text.id) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!_text.isOwned)
            IconButton(
              icon: Icon(
                isRead ? Icons.check_circle : Icons.check_circle_outline,
              ),
              tooltip: isRead ? 'Marcar como não lido' : 'Marcar como lido',
              onPressed: () => ref
                  .read(libraryControllerProvider.notifier)
                  .toggleRead(_text),
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Salvar no vocabulário',
            onPressed: _openCapture,
          ),
        ],
      ),
      floatingActionButton: const NotebookFab(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      taughtLanguages[_text.language] ?? _text.language,
                    ),
                  ),
                  if (_text.cefr != null) Chip(label: Text(_text.cefr!)),
                  if (_text.sourceKind == LibraryTextSource.temporary &&
                      _text.expiresAt != null)
                    Chip(label: Text('Expira em ${_text.formatExpiresIn()}')),
                ],
              ),
              if (_text.sourceKind == LibraryTextSource.temporary) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _savingPersonal ? null : _saveToPersonal,
                  icon: _savingPersonal
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_added_outlined),
                  label: const Text('Guardar nos pessoais'),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadingAudio ? null : _toggleAudio,
                    icon: _loadingAudio
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying ? 'Pausar áudio' : 'Ouvir texto'),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'female', label: Text('Voz ♀')),
                      ButtonSegment(value: 'male', label: Text('Voz ♂')),
                    ],
                    selected: {_voiceGender},
                    onSelectionChanged: (value) => _changeVoice(value.first),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Mais devagar',
                        onPressed: () => _nudgeRate(-0.25),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${_playbackRate.toStringAsFixed(2)}×'),
                      IconButton(
                        tooltip: 'Mais rápido',
                        onPressed: () => _nudgeRate(0.25),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
              if (_audioError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _audioError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_ownedError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _ownedError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => setState(
                          () => _showTranslationOptions =
                              !_showTranslationOptions,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Tradução ao lado do texto'),
                            ),
                            Text(
                              taughtLanguages[_translationTargetLang] ??
                                  _translationTargetLang,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Icon(
                              _showTranslationOptions
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ],
                        ),
                      ),
                      if (_showTranslationOptions) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _translationTargetLang,
                          decoration: const InputDecoration(
                            labelText: 'Traduzir para',
                          ),
                          items: [
                            for (final entry in taughtLanguages.entries)
                              if (entry.key != _text.language)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                          ],
                          onChanged: (value) {
                            if (value == null ||
                                value == _translationTargetLang) {
                              return;
                            }
                            setState(() {
                              _translationTargetLang = value;
                              _translations.clear();
                            });
                            if (_showInlineTranslation) {
                              unawaited(_loadInlineTranslations());
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _translatingInline
                              ? null
                              : _toggleInlineTranslation,
                          child: _translatingInline
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _showInlineTranslation
                                      ? 'Ocultar tradução'
                                      : 'Mostrar tradução',
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_showInlineTranslation)
                ..._inlineTranslationBody(context)
              else
                SelectionArea(
                  child: MarkdownBody(data: _text.content, selectable: true),
                ),
              if (_showInlineTranslation && _translationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _translationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openCapture,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Salvar trecho no vocabulário'),
              ),
              if (_questionSet != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openQuestions,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Perguntas de compreensão'),
                ),
              ] else if (_text.isOwned && !_loadingQuestions) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _generatingQuestions ? null : _generateQuestions,
                  icon: _generatingQuestions
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Gerar perguntas com IA'),
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

class _SaveVocabFromTextSheet extends ConsumerStatefulWidget {
  const _SaveVocabFromTextSheet({required this.text});

  final LibraryText text;

  @override
  ConsumerState<_SaveVocabFromTextSheet> createState() =>
      _SaveVocabFromTextSheetState();
}

class _SaveVocabFromTextSheetState
    extends ConsumerState<_SaveVocabFromTextSheet> {
  final _termController = TextEditingController();
  final _translationController = TextEditingController();
  final _contextController = TextEditingController();
  final _descriptionController = TextEditingController();
  VocabEntryKind _entryKind = VocabEntryKind.word;
  String? _partOfSpeech;
  String? _categoryId;
  bool _enriching = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _termController.dispose();
    _translationController.dispose();
    _contextController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _enrich() async {
    final term = _termController.text.trim();
    if (term.isEmpty) {
      setState(() => _error = 'Selecione ou digite o trecho primeiro.');
      return;
    }
    setState(() {
      _enriching = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(vocabularyRepositoryProvider)
          .enrichTerm(
            term: term,
            language: widget.text.language,
            entryKind: _entryKind,
            surroundingText: widget.text.content,
          );
      if (result == null) {
        setState(
          () => _error = 'Não foi possível preencher com IA. Tente novamente.',
        );
        return;
      }
      setState(() {
        if (result.translation.isNotEmpty) {
          _translationController.text = result.translation;
        }
        if (result.example.isNotEmpty &&
            _contextController.text.trim().isEmpty) {
          _contextController.text = result.example;
        }
        if (result.context.isNotEmpty &&
            _contextController.text.trim().isEmpty) {
          _contextController.text = result.context;
        }
        if (result.description.isNotEmpty) {
          _descriptionController.text = result.description;
        }
        _partOfSpeech = result.partOfSpeech;
      });
    } catch (_) {
      setState(
        () => _error = 'Não foi possível preencher com IA. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _submit() async {
    final term = _termController.text.trim();
    final translation = _translationController.text.trim();
    final contextText = _contextController.text.trim();
    final description = _descriptionController.text.trim();
    if (term.isEmpty ||
        translation.isEmpty ||
        contextText.isEmpty ||
        description.isEmpty) {
      setState(
        () => _error = 'Preencha trecho, tradução, contexto e descrição.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(vocabularyControllerProvider.notifier)
          .addFromText(
            term: term,
            translation: translation,
            language: widget.text.language,
            source: widget.text.sourceKind.raw,
            context: contextText,
            description: description,
            entryKind: _entryKind,
            example: contextText,
            partOfSpeech: _partOfSpeech,
            captureSurface: term,
            libraryTextId: widget.text.sourceKind == LibraryTextSource.library
                ? widget.text.id
                : null,
            temporaryTextId:
                widget.text.sourceKind == LibraryTextSource.temporary
                ? widget.text.id
                : null,
            personalTextId: widget.text.sourceKind == LibraryTextSource.personal
                ? widget.text.id
                : null,
            categoryIds: _categoryId == null ? const [] : [_categoryId!],
          );
      if (mounted) Navigator.of(context).pop();
    } on DuplicateVocabularyTermException {
      setState(() => _error = 'Esse termo já está na sua lista.');
    } catch (_) {
      setState(() => _error = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(vocabularyCategoriesProvider).value ??
        const <VocabCategory>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Salvar no vocabulário',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecione o trecho no texto, copie e cole aqui — ou digite a palavra/frase.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<VocabEntryKind>(
              segments: const [
                ButtonSegment(
                  value: VocabEntryKind.word,
                  label: Text('Palavra'),
                ),
                ButtonSegment(
                  value: VocabEntryKind.sentence,
                  label: Text('Frase'),
                ),
              ],
              selected: {_entryKind},
              onSelectionChanged: (value) =>
                  setState(() => _entryKind = value.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _termController,
              decoration: InputDecoration(
                labelText: _entryKind == VocabEntryKind.sentence
                    ? 'Frase ou expressão'
                    : 'Palavra',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enriching ? null : _enrich,
              icon: _enriching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Preencher com IA'),
            ),
            if (_partOfSpeech != null) ...[
              const SizedBox(height: 8),
              Text(
                'Classe: $_partOfSpeech',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _translationController,
              decoration: const InputDecoration(labelText: 'Tradução'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contextController,
              decoration: const InputDecoration(labelText: 'Contexto'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição'),
              maxLines: 2,
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Categoria (opcional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhuma')),
                  for (final category in categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
