import "models/candidate.dart";
import "dart:math";
import "dart:convert";

const double _eps = 0.3;
const int _topN = 3;
const int _logN = 5;

class SamplerOutput {
  const SamplerOutput({
    required this.winner,
    required this.topK,
  });

  final ScoredCandidate winner;
  final List<ScoredCandidate> topK;
}

SamplerOutput sample(List<ScoredCandidate> ranked, String seed) {
  if (ranked.isEmpty) {
    throw ArgumentError('Cannot sample from empty candidate list');
  }

  List<ScoredCandidate> topKList = ranked.sublist(0, min(_logN, ranked.length));
  List<ScoredCandidate> poolForRandom =
      ranked.sublist(0, min(_topN, ranked.length)); // sample from 3

  int rngSeed = stableHash(seed);
  Random rng = Random(rngSeed);

  if (ranked.length == 1) {
    return SamplerOutput(winner: ranked[0], topK: topKList);
  }

  double r = rng.nextDouble();
  if (r <= _eps) {
    int idx = rng.nextInt(poolForRandom.length);
    return SamplerOutput(winner: poolForRandom[idx], topK: topKList);
  }

  return SamplerOutput(winner: ranked[0], topK: topKList);
}

int stableHash(String s) {
  const int fnvOffsetBasis = 0x811c9dc5;
  const int fnvPrime = 0x01000193;
  const int mask32 = 0xFFFFFFFF;

  final bytes = utf8.encode(s);
  int hash = fnvOffsetBasis;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * fnvPrime) & mask32;
  }
  return hash;
}
