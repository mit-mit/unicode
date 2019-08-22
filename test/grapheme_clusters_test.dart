// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:math";

import "package:test/test.dart";

import "package:unicode/unicode.dart";

import "src/unicode_tests.dart";
import "src/unicode_grapheme_tests.dart";
import "src/various_tests.dart";

Random random;

void main([List<String> args]) {
  // Ensure random seed is part of every test failure message,
  // and that it can be reapplied for testing.
  var seed = (args != null && args.isNotEmpty)
      ? int.parse(args[0])
      : Random().nextInt(0x3FFFFFFF);
  random = Random(seed);
  group("[RS:$seed]", tests);
}

void tests() {
  test("empty", () {
    expectGC(GraphemeClusters(""), []);
  });
  group("gc-ASCII", () {
    for (var text in [
      "",
      "A",
      "123456abcdefab",
    ]) {
      test('"$text"', () {
        expectGC(GraphemeClusters(text), charsOf(text));
      });
    }
    test("CR+NL", () {
      expectGC(GraphemeClusters("a\r\nb"), ["a", "\r\n", "b"]);
      expectGC(GraphemeClusters("a\n\rb"), ["a", "\n", "\r", "b"]);
    });
  });
  group("Non-ASCII single-code point", () {
    for (var text in [
      "à la mode",
      "rødgrød-æble-ål",
    ]) {
      test('"$text"', () {
        expectGC(GraphemeClusters(text), charsOf(text));
      });
    }
  });
  group("Combining marks", () {
    var text = "a\u0300 la mode";
    test('"$text"', () {
      expectGC(GraphemeClusters(text),
          ["a\u0300", " ", "l", "a", " ", "m", "o", "d", "e"]);
    });
    var text2 = "æble-a\u030Al";
    test('"$text2"', () {
      expectGC(
          GraphemeClusters(text2), ["æ", "b", "l", "e", "-", "a\u030A", "l"]);
    });
  });

  group("Regional Indicators", () {
    test('"🇦🇩🇰🇾🇪🇸"', () {
      // Andorra, Cayman Islands, Spain.
      expectGC(GraphemeClusters("🇦🇩🇰🇾🇪🇸"), ["🇦🇩", "🇰🇾", "🇪🇸"]);
    });
    test('"X🇦🇩🇰🇾🇪🇸"', () {
      // Other, Andorra, Cayman Islands, Spain.
      expectGC(
          GraphemeClusters("X🇦🇩🇰🇾🇪🇸"), ["X", "🇦🇩", "🇰🇾", "🇪🇸"]);
    });
    test('"🇩🇰🇾🇪🇸"', () {
      // Denmark, Yemen, unmatched S.
      expectGC(GraphemeClusters("🇩🇰🇾🇪🇸"), ["🇩🇰", "🇾🇪", "🇸"]);
    });
    test('"X🇩🇰🇾🇪🇸"', () {
      // Other, Denmark, Yemen, unmatched S.
      expectGC(GraphemeClusters("X🇩🇰🇾🇪🇸"), ["X", "🇩🇰", "🇾🇪", "🇸"]);
    });
  });

  group("Hangul", () {
    // Individual characters found on Wikipedia. Not expected to make sense.
    test('"읍쌍된밟"', () {
      expectGC(GraphemeClusters("읍쌍된밟"), ["읍", "쌍", "된", "밟"]);
    });
  });

  group("Unicode test", () {
    for (var gcs in splitTests) {
      test("[${testDescription(gcs)}]", () {
        expectGC(GraphemeClusters(gcs.join()), gcs);
      });
    }
  });

  group("Emoji test", () {
    for (var gcs in emojis) {
      test("[${testDescription(gcs)}]", () {
        expectGC(GraphemeClusters(gcs.join()), gcs);
      });
    }
  });

  group("Zalgo test", () {
    for (var gcs in zalgo) {
      test("[${testDescription(gcs)}]", () {
        expectGC(GraphemeClusters(gcs.join()), gcs);
      });
    }
  });
}

// Converts text with no multi-code-point grapheme clusters into
// list of grapheme clusters.
List<String> charsOf(String text) =>
    text.runes.map((r) => String.fromCharCode(r)).toList();

void expectGC(GraphemeClusters actual, List<String> expected) {
  var text = expected.join();
  // Iterable operations.
  expect(actual.toList(), expected);
  expect(actual.length, expected.length);
  if (expected.isNotEmpty) {
    expect(actual.first, expected.first);
    expect(actual.last, expected.last);
  } else {
    expect(() => actual.first, throwsStateError);
    expect(() => actual.last, throwsStateError);
  }
  if (expected.length == 1) {
    expect(actual.single, expected.single);
  } else {
    expect(() => actual.single, throwsStateError);
  }
  expect(actual.isEmpty, expected.isEmpty);
  expect(actual.isNotEmpty, expected.isNotEmpty);
  expect(actual.contains(""), false);
  for (var char in expected) {
    expect(actual.contains(char), true);
  }
  for (int i = 1; i < expected.length; i++) {
    expect(actual.contains(expected[i - 1] + expected[i]), false);
  }
  expect(actual.skip(1).toList(), expected.skip(1).toList());
  expect(actual.take(1).toList(), expected.take(1).toList());

  List<int> accumulatedLengths = [0];
  for (int i = 0; i < expected.length; i++) {
    accumulatedLengths.add(accumulatedLengths.last + expected[i].length);
  }

  // Iteration.
  var it = actual.iterator;
  expect(it.start, 0);
  expect(it.end, 0);
  for (var i = 0; i < expected.length; i++) {
    expect(it.moveNext(), true);
    expect(it.start, accumulatedLengths[i]);
    expect(it.end, accumulatedLengths[i + 1]);
    expect(it.current, expected[i]);
  }
  expect(it.moveNext(), false);
  expect(it.start, accumulatedLengths.last);
  expect(it.end, accumulatedLengths.last);
  for (var i = expected.length - 1; i >= 0; i--) {
    expect(it.movePrevious(), true);
    expect(it.start, accumulatedLengths[i]);
    expect(it.end, accumulatedLengths[i + 1]);
    expect(it.current, expected[i]);
  }
  expect(it.movePrevious(), false);
  expect(it.start, 0);
  expect(it.end, 0);

  // GraphemeClusters operations.
  expect(actual.string, text);

  expect(actual.containsAll(GraphemeClusters("")), true);
  expect(actual.containsAll(actual), true);
  if (expected.isNotEmpty) {
    int steps = min(5, expected.length);
    for (int s = 0; s <= steps; s++) {
      int i = expected.length * s ~/ steps;
      expect(actual.startsWith(GraphemeClusters(expected.sublist(0, i).join())),
          true);
      expect(
          actual.endsWith(GraphemeClusters(expected.sublist(i).join())), true);
      for (int t = s + 1; t <= steps; t++) {
        int j = expected.length * t ~/ steps;
        int start = accumulatedLengths[i];
        int end = accumulatedLengths[j];
        var slice = expected.sublist(i, j).join();
        var gcs = GraphemeClusters(slice);
        expect(actual.containsAll(gcs), true);
        expect(actual.startsWith(gcs, start), true);
        expect(actual.endsWith(gcs, end), true);
      }
    }
    if (accumulatedLengths.last > expected.length) {
      int i = expected.indexWhere((s) => s.length != 1);
      assert(accumulatedLengths[i + 1] > accumulatedLengths[i] + 1);
      expect(
          actual.startsWith(
              GraphemeClusters(text.substring(0, accumulatedLengths[i] + 1))),
          false);
      expect(
          actual.endsWith(
              GraphemeClusters(text.substring(accumulatedLengths[i] + 1))),
          false);
      if (i > 0) {
        expect(
            actual.startsWith(
                GraphemeClusters(text.substring(1, accumulatedLengths[i] + 1)),
                1),
            false);
      }
      if (i < expected.length - 1) {
        int secondToLast = accumulatedLengths[expected.length - 1];
        expect(
            actual.endsWith(
                GraphemeClusters(
                    text.substring(accumulatedLengths[i] + 1, secondToLast)),
                secondToLast),
            false);
      }
    }
  }

  {
    // Random walk back and forth.
    var it = actual.iterator;
    int pos = -1;
    if (random.nextBool()) {
      pos = expected.length;
      it.reset(text.length);
    }
    int steps = 5 + random.nextInt(expected.length * 2 + 1);
    bool lastMove = false;
    while (true) {
      bool back = false;
      if (pos < 0) {
        expect(lastMove, false);
        expect(it.start, 0);
        expect(it.end, 0);
      } else if (pos >= expected.length) {
        expect(lastMove, false);
        expect(it.start, text.length);
        expect(it.end, text.length);
        back = true;
      } else {
        expect(lastMove, true);
        expect(it.current, expected[pos]);
        expect(it.start, accumulatedLengths[pos]);
        expect(it.end, accumulatedLengths[pos + 1]);
        back = random.nextBool();
      }
      if (--steps < 0) break;
      if (back) {
        lastMove = it.movePrevious();
        pos -= 1;
      } else {
        lastMove = it.moveNext();
        pos += 1;
      }
    }
  }
}
