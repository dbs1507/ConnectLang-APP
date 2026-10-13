import 'dart:async';
import 'dart:io';

import 'package:connectlang_app/core/audio/tts_audio_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses the file and does not ask for a url again', () async {
    final dir = await Directory.systemTemp.createTemp('tts_cache');
    addTearDown(() => dir.delete(recursive: true));
    var calls = 0;
    final cache = TtsAudioCache(
      directory: () async => dir,
      download: (uri, file) async {
        await file.writeAsBytes([1, 2, 3, 4]);
      },
    );

    final first = await cache.ensureFile(
      text: 'hello',
      language: 'en',
      resolveUrl: () async {
        calls += 1;
        return 'https://example.com/a.mp3';
      },
    );
    final second = await cache.ensureFile(
      text: 'hello',
      language: 'EN',
      resolveUrl: () async {
        calls += 1;
        return 'https://example.com/other.mp3';
      },
    );

    expect(calls, 1);
    expect(second.path, first.path);
    expect(await second.readAsBytes(), [1, 2, 3, 4]);
  });

  test('a tap downloads while background requests stay queued', () async {
    final dir = await Directory.systemTemp.createTemp('tts_cache_queue');
    addTearDown(() => dir.delete(recursive: true));
    final gate = Completer<void>();
    var calls = 0;
    final cache = TtsAudioCache(
      directory: () async => dir,
      download: (uri, file) async {
        await gate.future;
        await file.writeAsBytes([9]);
      },
    );

    final pending = <Future<File>>[];
    for (var i = 0; i < 3; i++) {
      pending.add(
        cache.ensureFile(
          text: 'bg$i',
          language: 'EN',
          priority: TtsFetchPriority.background,
          resolveUrl: () async {
            calls += 1;
            return 'https://example.com/$i.mp3';
          },
        ),
      );
    }
    await pumpEventQueue();
    expect(calls, 3);

    var tapped = false;
    final tap = cache.ensureFile(
      text: 'now',
      language: 'EN',
      resolveUrl: () async {
        tapped = true;
        calls += 1;
        return 'https://example.com/now.mp3';
      },
    );
    final waiting = cache.ensureFile(
      text: 'bg-waiting',
      language: 'EN',
      priority: TtsFetchPriority.background,
      resolveUrl: () async {
        calls += 1;
        return 'https://example.com/waiting.mp3';
      },
    );
    await pumpEventQueue();

    expect(tapped, isTrue);
    expect(calls, 4);
    gate.complete();
    await Future.wait([...pending, tap, waiting]);
    expect(calls, 5);
  });

  test('text chunks are reused only after the full set is stored', () async {
    final dir = await Directory.systemTemp.createTemp('tts_cache_text');
    addTearDown(() => dir.delete(recursive: true));
    final cache = TtsAudioCache(directory: () async => dir);

    expect(
      await cache.readTextChunkPaths(
        sourceKind: 'library',
        textId: 'abc',
        voiceGender: 'female',
      ),
      isNull,
    );

    final paths = await cache.writeTextChunks(
      sourceKind: 'library',
      textId: 'abc',
      voiceGender: 'female',
      base64Chunks: ['aGVsbG8=', 'd29ybGQ='],
    );
    final again = await cache.readTextChunkPaths(
      sourceKind: 'library',
      textId: 'abc',
      voiceGender: 'female',
    );

    expect(paths, hasLength(2));
    expect(again, paths);
    expect(await File(paths.first).readAsString(), 'hello');
  });
}
