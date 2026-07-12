import 'dart:async';

typedef SaveReaderPage = Future<bool> Function(int page);

final class ReaderProgressDebouncer {
  ReaderProgressDebouncer({
    required SaveReaderPage onSave,
    this.delay = const Duration(seconds: 2),
  }) : _onSave = onSave;

  final Duration delay;
  SaveReaderPage _onSave;
  Timer? _timer;
  int? _pendingPage;
  Future<void> _saveChain = Future.value();
  bool _closed = false;

  set onSave(SaveReaderPage callback) => _onSave = callback;

  void schedule(int page) {
    if (_closed) return;
    _timer?.cancel();
    _pendingPage = page;
    _timer = Timer(delay, () => unawaited(flush()));
  }

  Future<bool> saveNow(int page) async {
    if (_closed) return false;
    _timer?.cancel();
    _pendingPage = null;
    return _enqueue(page);
  }

  Future<void> flush() async {
    _timer?.cancel();
    final page = _pendingPage;
    _pendingPage = null;
    if (page != null) {
      await _enqueue(page);
    } else {
      await _saveChain;
    }
  }

  Future<void> flushAndClose() async {
    _closed = true;
    await flush();
  }

  Future<bool> _enqueue(int page) {
    final save = _onSave;
    final operation = _saveChain.then((_) => save(page));
    _saveChain = operation.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return operation;
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
    _pendingPage = null;
  }
}
