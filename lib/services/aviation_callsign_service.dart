/// Haftalık test için değiştirilemeyen, UID tabanlı havacılık çağrı kodu.
abstract final class AviationCallsignService {
  static const _alphabet = <String>[
    'ALFA',
    'BRAVO',
    'CHARLIE',
    'DELTA',
    'ECHO',
    'FOXTROT',
    'GOLF',
    'HOTEL',
    'INDIA',
    'JULIETT',
    'KILO',
    'LIMA',
    'MIKE',
    'NOVEMBER',
    'OSCAR',
    'PAPA',
    'QUEBEC',
    'ROMEO',
    'SIERRA',
    'TANGO',
    'UNIFORM',
    'VICTOR',
    'WHISKEY',
    'X-RAY',
    'YANKEE',
    'ZULU',
  ];

  static String fromUserId(String userId) {
    // FNV-1a: Dart sürümünden bağımsız, aynı UID için daima aynı sonuç.
    var hash = 0x811C9DC5;
    for (final unit in userId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    final word = _alphabet[hash % _alphabet.length];
    final number =
        ((hash ~/ _alphabet.length) % 1000).toString().padLeft(3, '0');
    return '$word-$number';
  }
}
