import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_role.dart';
import '../notebook/notebook_fab.dart';
import '../../core/session/auth_controller.dart';
import '../vocabulary/models/vocabulary_entry.dart';
import 'dictation_controller.dart';
import 'dictation_session_page.dart';
import 'models/dictation_next_result.dart';

class DictationHomePage extends ConsumerStatefulWidget {
  const DictationHomePage({
    super.key,
    this.initialLanguage,
    this.initialCefr,
    this.initialFocusTags = const [],
    this.initialCount,
    this.autoStartCalibrated = false,
  });

  final String? initialLanguage;
  final String? initialCefr;
  final List<String> initialFocusTags;
  final int? initialCount;
  final bool autoStartCalibrated;

  factory DictationHomePage.fromRoute(
    String route, {
    String? fallbackLanguage,
  }) {
    final args = DictationLaunchArgs.fromRoute(
      route,
      fallbackLanguage: fallbackLanguage ?? 'EN',
    );
    return DictationHomePage(
      initialLanguage: args.language,
      initialCefr: args.cefr,
      initialFocusTags: args.focusTags,
      initialCount: args.sessionSize,
      autoStartCalibrated: args.autoStartCalibrated,
    );
  }

  @override
  ConsumerState<DictationHomePage> createState() => _DictationHomePageState();
}

class _DictationHomePageState extends ConsumerState<DictationHomePage> {
  late String _language = widget.initialLanguage ?? 'EN';
  late int _sessionSize = widget.initialCount ?? 10;
  late bool _calibrated = widget.autoStartCalibrated;
  bool _loading = false;
  String? _error;
  String? _focusHeadline;

  @override
  void initState() {
    super.initState();
    if (widget.autoStartCalibrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
      _focusHeadline = null;
    });
    try {
      final repo = ref.read(dictationRepositoryProvider);
      if (_calibrated) {
        var next = await repo.fetchCalibratedNext(
          language: _language,
          cefr: widget.initialCefr,
          focusTags: widget.initialFocusTags,
          sessionSize: _sessionSize,
        );
        if ((next == null || next.itemIds.isEmpty) &&
            widget.autoStartCalibrated) {
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          next = await repo.fetchCalibratedNext(
            language: _language,
            cefr: widget.initialCefr,
            focusTags: widget.initialFocusTags,
            sessionSize: _sessionSize,
          );
        }
        if (!mounted) return;
        if (next == null || next.itemIds.isEmpty) {
          setState(
            () => _error =
                next?.message ??
                'Não foi possível montar uma sessão de ponto fraco agora.',
          );
          return;
        }
        final items = await repo.fetchItemsByIds(
          next.itemIds.take(_sessionSize).toList(),
        );
        if (!mounted) return;
        if (items.isEmpty) {
          setState(
            () => _error = 'Não há frases calibradas pra esse idioma ainda.',
          );
          return;
        }
        setState(
          () => _focusHeadline = next!.headline.isEmpty
              ? next.focusTag
              : next.headline,
        );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DictationSessionPage(
              items: items,
              calibrated: true,
              focusTags: widget.initialFocusTags.isEmpty
                  ? [if (next!.focusTag != null) next.focusTag!]
                  : widget.initialFocusTags,
            ),
          ),
        );
      } else {
        final items = await repo.fetchFreeItems(
          language: _language,
          limit: _sessionSize,
        );
        if (!mounted) return;
        if (items.isEmpty) {
          setState(
            () => _error = 'Não há frases de ditado pra esse idioma ainda.',
          );
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DictationSessionPage(items: items)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível carregar as frases. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscriber =
        ref.watch(authControllerProvider).value?.role == AppRole.subscriber;

    return Scaffold(
      floatingActionButton: const NotebookFab(),
      appBar: AppBar(title: const Text('Ditado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.headphones,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ouça a frase e digite exatamente o que você ouviu.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey(_language),
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Idioma'),
                items: [
                  for (final entry in taughtLanguages.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _language = value ?? _language),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _sessionSize,
                decoration: const InputDecoration(
                  labelText: 'Frases na sessão',
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 20, child: Text('20')),
                ],
                onChanged: _loading
                    ? null
                    : (value) =>
                          setState(() => _sessionSize = value ?? _sessionSize),
              ),
              if (isSubscriber) ...[
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Prática livre')),
                    ButtonSegment(value: true, label: Text('Ponto fraco')),
                  ],
                  selected: {_calibrated},
                  onSelectionChanged: _loading
                      ? null
                      : (value) => setState(() => _calibrated = value.first),
                ),
              ],
              if (_focusHeadline != null) ...[
                const SizedBox(height: 12),
                Text(_focusHeadline!, textAlign: TextAlign.center),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _start,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_calibrated ? 'Começar ponto fraco' : 'Começar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
