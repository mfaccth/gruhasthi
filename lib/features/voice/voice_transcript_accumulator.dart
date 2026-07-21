/// Shared transcript state for Gruhasthi's press-and-hold speech surfaces.
///
/// Android reports several evolving partial hypotheses for one phrase. Those
/// hypotheses replace one another; only a final result, a recognizer pause, or
/// release of the microphone commits a phrase to the finished transcript.
class VoiceTranscriptAccumulator {
  String _completed = '';
  String _currentPartial = '';
  String _lastFinal = '';

  String get transcript => _merge(_completed, _currentPartial);

  void reset() {
    _completed = '';
    _currentPartial = '';
    _lastFinal = '';
  }

  void addResult(String words, {required bool isFinal}) {
    final segment = words.trim();
    if (segment.isEmpty) return;
    if (isFinal) {
      if (segment != _lastFinal) {
        _completed = _merge(_completed, segment);
        _lastFinal = segment;
      }
      _currentPartial = '';
    } else {
      _currentPartial = segment;
    }
  }

  void commitPartial() {
    if (_currentPartial.isEmpty) return;
    _completed = _merge(_completed, _currentPartial);
    _currentPartial = '';
  }

  String finish() {
    commitPartial();
    return transcript.trim();
  }

  static String _merge(String first, String second) {
    final existing = first.trim();
    final incoming = second.trim();
    if (existing.isEmpty) return incoming;
    if (incoming.isEmpty ||
        existing == incoming ||
        existing.endsWith(incoming)) {
      return existing;
    }
    if (incoming.startsWith(existing) || incoming.contains(existing)) {
      return incoming;
    }
    final existingWords = existing.split(RegExp(r'\s+'));
    final incomingWords = incoming.split(RegExp(r'\s+'));
    for (
      var overlap = existingWords.length < incomingWords.length
          ? existingWords.length
          : incomingWords.length;
      overlap > 0;
      overlap--
    ) {
      final suffix = existingWords.sublist(existingWords.length - overlap);
      final prefix = incomingWords.sublist(0, overlap);
      if (_sameWords(suffix, prefix)) {
        return [...existingWords, ...incomingWords.sublist(overlap)].join(' ');
      }
    }
    return '$existing $incoming';
  }

  static bool _sameWords(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].toLowerCase() != second[index].toLowerCase()) {
        return false;
      }
    }
    return true;
  }
}
