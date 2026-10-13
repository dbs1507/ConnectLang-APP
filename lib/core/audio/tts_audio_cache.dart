import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Áudio TTS já baixado. O toque toca o arquivo local; a rede só roda
/// quando aquele texto ainda não está no aparelho.
final ttsAudioCacheProvider = Provider<TtsAudioCache>((ref) => TtsAudioCache());

enum TtsFetchPriority { immediate, background }

class TtsAudioUnavailable implements Exception {
  const TtsAudioUnavailable();
}

class TtsAudioCache {
  TtsAudioCache({
    Future<Directory> Function()? directory,
    Future<void> Function(Uri uri, File dest)? download,
    this.maxBackground = 3,
  }) : _directory = directory ?? _applicationSupportDir,
       _download = download ?? _downloadUrl;

  final Future<Directory> Function() _directory;
  final Future<void> Function(Uri uri, File dest) _download;
  final int maxBackground;

  final Map<String, _Pending> _pending = {};
  final List<String> _backgroundOrder = [];
  int _backgroundRunning = 0;

  static Future<Directory> _applicationSupportDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> _downloadUrl(Uri uri, File dest) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw TtsAudioUnavailable();
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) throw const TtsAudioUnavailable();
      await dest.writeAsBytes(bytes, flush: true);
    } finally {
      client.close();
    }
  }

  String cacheKey({
    required String text,
    required String language,
    String voiceGender = 'female',
  }) {
    final raw =
        '${language.trim().toUpperCase()}|${voiceGender.trim().toLowerCase()}|${text.trim()}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Baixa o MP3 se ainda não estiver em disco. Vários botões compartilham
  /// a mesma tarefa. Pedidos em segundo plano ficam numa fila curta; um toque
  /// (`immediate`) fura essa fila.
  Future<File> ensureFile({
    required String text,
    required String language,
    String voiceGender = 'female',
    TtsFetchPriority priority = TtsFetchPriority.immediate,
    required Future<String?> Function() resolveUrl,
  }) {
    if (text.trim().isEmpty) {
      return Future.error(const TtsAudioUnavailable());
    }
    final key = cacheKey(
      text: text,
      language: language,
      voiceGender: voiceGender,
    );
    final existing = _pending[key];
    if (existing != null) {
      if (priority == TtsFetchPriority.immediate) _promote(key);
      return existing.completer.future;
    }

    final pending = _Pending(() => _materialize(key, resolveUrl));
    _pending[key] = pending;
    final queued =
        priority == TtsFetchPriority.background &&
        _backgroundRunning >= maxBackground;
    if (queued) {
      _backgroundOrder.add(key);
    } else {
      _start(key, countsAsBackground: priority == TtsFetchPriority.background);
    }
    return pending.completer.future;
  }

  /// Arquivos de um texto já gravados por completo, na ordem dos pedaços.
  Future<List<String>?> readTextChunkPaths({
    required String sourceKind,
    required String textId,
    required String voiceGender,
  }) async {
    final dir = await _directory();
    final prefix = _textPrefix(sourceKind, textId, voiceGender);
    final manifest = File('${dir.path}/$prefix.count');
    if (!await manifest.exists()) return null;
    final count = int.tryParse((await manifest.readAsString()).trim());
    if (count == null || count <= 0) return null;
    final paths = <String>[];
    for (var i = 0; i < count; i++) {
      final file = File('${dir.path}/${prefix}_$i.mp3');
      if (!await file.exists() || await file.length() == 0) return null;
      paths.add(file.path);
    }
    return paths;
  }

  /// Grava os pedaços e o manifesto. Sem o manifesto, a próxima abertura
  /// busca de novo — um cache pela metade não toca.
  Future<List<String>> writeTextChunks({
    required String sourceKind,
    required String textId,
    required String voiceGender,
    required List<String> base64Chunks,
  }) async {
    final dir = await _directory();
    final prefix = _textPrefix(sourceKind, textId, voiceGender);
    final paths = <String>[];
    for (final encoded in base64Chunks) {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) continue;
      final file = File('${dir.path}/${prefix}_${paths.length}.mp3');
      await file.writeAsBytes(bytes, flush: true);
      paths.add(file.path);
    }
    if (paths.isEmpty) throw const TtsAudioUnavailable();
    final manifest = File('${dir.path}/$prefix.count');
    await manifest.writeAsString('${paths.length}', flush: true);
    return paths;
  }

  void _promote(String key) {
    if (!_backgroundOrder.remove(key)) return;
    _start(key, countsAsBackground: false);
  }

  void _start(String key, {required bool countsAsBackground}) {
    final pending = _pending[key];
    if (pending == null || pending.started) return;
    pending.started = true;
    if (countsAsBackground) _backgroundRunning++;
    unawaited(() async {
      try {
        final file = await pending.work();
        if (!pending.completer.isCompleted) pending.completer.complete(file);
      } catch (error, stack) {
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(error, stack);
        }
      } finally {
        _pending.remove(key);
        if (countsAsBackground) _backgroundRunning--;
        _drain();
      }
    }());
  }

  void _drain() {
    while (_backgroundRunning < maxBackground && _backgroundOrder.isNotEmpty) {
      final key = _backgroundOrder.removeAt(0);
      _start(key, countsAsBackground: true);
    }
  }

  Future<File> _materialize(
    String key,
    Future<String?> Function() resolveUrl,
  ) async {
    final dir = await _directory();
    final target = File('${dir.path}/$key.mp3');
    if (await target.exists() && await target.length() > 0) return target;

    final url = (await resolveUrl())?.trim() ?? '';
    if (url.isEmpty) throw const TtsAudioUnavailable();

    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();
    try {
      await _download(Uri.parse(url), part);
      if (await target.exists()) await target.delete();
      return await part.rename(target.path);
    } catch (error) {
      if (await part.exists()) await part.delete();
      if (error is TtsAudioUnavailable) rethrow;
      throw const TtsAudioUnavailable();
    }
  }

  String _textPrefix(String sourceKind, String textId, String voiceGender) {
    String safe(String value) =>
        value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'text_${safe(sourceKind)}_${safe(textId)}_${safe(voiceGender)}';
  }
}

class _Pending {
  _Pending(this.work);

  final Completer<File> completer = Completer<File>();
  final Future<File> Function() work;
  bool started = false;
}
