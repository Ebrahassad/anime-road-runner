// Run: `flutter test`  (or `flutter test test/game_math_test.dart`)

import 'package:anime_road_runner/game/game_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('laneX', () {
    test('lane 0 is centre', () {
      expect(laneX(0, 2.0), 0.0);
    });

    test('scales with lane width', () {
      expect(laneX(1, 3.5), 3.5);
      expect(laneX(-1, 3.5), -3.5);
    });
  });

  group('smoothing', () {
    test('is 0 at dt 0 and approaches 1 for a long frame', () {
      expect(smoothing(12.0, 0.0), 0.0);
      expect(smoothing(12.0, 10.0), closeTo(1.0, 1e-6));
    });
  });

  group('overlaps1D', () {
    test('true when centres are closer than the half-sum', () {
      expect(overlaps1D(0.0, 0.5, 1.0), isTrue);
    });

    test('false when centres are farther than the half-sum', () {
      expect(overlaps1D(0.0, 2.0, 1.0), isFalse);
    });
  });

  group('speedAt', () {
    test('ramps linearly then holds at max', () {
      expect(speedAt(0.0, base: 5.0, max: 20.0, rampPerSec: 1.0), 5.0);
      expect(speedAt(5.0, base: 5.0, max: 20.0, rampPerSec: 1.0), 10.0);
      expect(speedAt(100.0, base: 5.0, max: 20.0, rampPerSec: 1.0), 20.0);
    });
  });

  group('clampDt', () {
    test('passes small deltas through unchanged', () {
      expect(clampDt(0.01, 0.05), 0.01);
    });

    test('caps large deltas', () {
      expect(clampDt(1.0, 0.05), 0.05);
    });
  });

  group('lerpD / clampD / easeInQuad', () {
    test('lerpD interpolates linearly', () {
      expect(lerpD(0.0, 10.0, 0.5), 5.0);
    });

    test('clampD bounds the value', () {
      expect(clampD(-5.0, 0.0, 1.0), 0.0);
      expect(clampD(5.0, 0.0, 1.0), 1.0);
      expect(clampD(0.5, 0.0, 1.0), 0.5);
    });

    test('easeInQuad is 0 at 0, 1 at 1, and slower than linear before that',
        () {
      expect(easeInQuad(0.0), 0.0);
      expect(easeInQuad(1.0), 1.0);
      expect(easeInQuad(0.5), lessThan(0.5));
    });
  });

  group('ordinal', () {
    test('handles the 1/2/3 special cases', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
    });

    test('handles the 11-13 exception to the 1/2/3 rule', () {
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
    });

    test('handles larger numbers', () {
      expect(ordinal(21), '21st');
      expect(ordinal(102), '102nd');
    });
  });
}
