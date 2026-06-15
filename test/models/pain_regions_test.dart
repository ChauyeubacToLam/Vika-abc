import 'package:flutter_test/flutter_test.dart';
import 'package:vika/interpreter/intepreting_map.dart';
import 'package:vika/models/pain_regions.dart';

void main() {
  group('canonicalPainRegion', () {
    test('passes through canonical user_pain_areas ids', () {
      const canonical = [
        'shoulder_neck',
        'back',
        'lower_back',
        'hip',
        'wrist',
        'knee',
        'ankle',
        'other',
      ];

      for (final id in canonical) {
        expect(canonicalPainRegion(id), id);
      }
    });

    test('normalizes legacy shoulder-neck aliases', () {
      expect(canonicalPainRegion('shoulder'), 'shoulder_neck');
      expect(canonicalPainRegion('neck'), 'shoulder_neck');
      expect(canonicalPainRegion('chest'), 'shoulder_neck');
    });

    test('drops empty, conditioning, and unknown regions', () {
      for (final raw in ['', 'leg', 'core', 'lower_body', 'unknown']) {
        expect(canonicalPainRegion(raw), isNull);
      }
    });
  });

  group('S09 self-report bodyRegion mapping', () {
    test('pain-zone candidates resolve to canonical regions', () {
      const expected = {
        'shoulder_pain': 'shoulder_neck',
        'shoulder_high': 'shoulder_neck',
        'chest_tight': 'shoulder_neck',
        'calf_tight': 'ankle',
        'hamstring_tight': 'lower_back',
        'knee_pain': 'knee',
        'ankle_tight': 'ankle',
        'hip_tight': 'hip',
        'hip_pain': 'hip',
        'low_back_pain': 'lower_back',
        'wrist_discomfort': 'wrist',
      };

      for (final entry in expected.entries) {
        final def = interpretingMap[entry.key]!;
        expect(def.priority, 99);
        expect(canonicalPainRegion(def.bodyRegion), entry.value);
      }
    });

    test('fatigue and breath candidates produce no pain row', () {
      const dropped = [
        'thigh_fatigue',
        'leg_shake',
        'shoulder_fatigue',
        'breath',
      ];

      for (final id in dropped) {
        final def = interpretingMap[id]!;
        expect(def.priority, 99);
        expect(canonicalPainRegion(def.bodyRegion), isNull);
      }
    });

    test('all priority 99 candidates are canonical or explicitly dropped', () {
      final invalid = interpretingMap.entries
          .where((entry) => entry.value.priority == 99)
          .where((entry) => canonicalPainRegion(entry.value.bodyRegion) == null)
          .where((entry) => entry.value.bodyRegion.isNotEmpty)
          .map((entry) => entry.key)
          .toList();

      expect(invalid, isEmpty);
    });
  });
}
