// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "constants.dart";
import "table.dart";

/// Iterates grapheme cluster breaks of a string.
///
/// Iterates the grapheme cluster breaks of the substring of
/// [base] from [cursor] to [end].
///
/// To iterate a substring, use:
/// ```dart
/// var breaks = Breaks(string, start, end, stateSoT);
/// int brk = 0;
/// while((brk = breaks.nextBreak) >= 0) {
///   print("Break at index $brk");
/// }
/// ```
/// If you use [stateSoTNoBreak] instead of [stateSoT], the
/// initial break between the start-of-text and the first grapheme
/// is suppressed.
class Breaks {
  /// Text being iterated.
  final String base;

  /// end of substring of [base] being iterated.
  final int end;

  /// Position of the first yet-unprocessed code point.
  int cursor;

  /// Current state based on code points processed so far.
  int state;

  Breaks(this.base, this.cursor, this.end, this.state);

  /// Creates a copy of the current iteration, at the exact same state.
  Breaks copy() => Breaks(base, cursor, end, state);

  /// The index of the next grapheme cluster break in last-to-first index order.
  ///
  /// Returns a negative number if there are no further breaks,
  /// which means that [cursor] has reached [end].
  int nextBreak() {
    while (cursor < end) {
      int breakAt = cursor;
      int char = base.codeUnitAt(cursor++);
      if (char & 0xFC00 != 0xD800) {
        state = move(state, low(char));
        if (state & stateNoBreak == 0) {
          return breakAt;
        }
        continue;
      }
      // The category of an unpaired lead surrogate is Control.
      int category = categoryControl;
      if (cursor < end) {
        int nextChar = base.codeUnitAt(cursor);
        if (nextChar & 0xFC00 == 0xDC00) {
          category = high(char, nextChar);
          cursor++;
        }
      }
      state = move(state, category);
      if (state & stateNoBreak == 0) {
        return breakAt;
      }
    }
    state = move(state, categoryEoT);
    if (state & stateNoBreak == 0) return cursor;
    return -1;
  }
}

/// Iterates grapheme cluster breaks backwards.
///
/// Given a substring of a [base] string from [start] to [cursor],
/// iterates the grapheme cluster breaks from [cursor] to [start].
///
/// To iterate a substring, do
/// ```dart
/// var breaks = BackBreaks(string, start, end, stateEoT);
/// int brk = 0;
/// while ((brk = breaks.nextBreak()) >= 0) {
///   print("Break at index $brk");
/// }
/// ```
/// If the initial [state] is [stateEoTNoBreak] instead of [stateEoT],
/// the initial break between the last grapheme and the end-of-text
/// is suppressed.
class BackBreaks {
  /// Text being iterated.
  final String base;

  /// Start of substring of [base] being iterated.
  final int start;

  /// Position after the last yet-unprocessed code point.
  int cursor;

  /// Current state based on code points processed so far.
  int state;
  BackBreaks(this.base, this.cursor, this.start, this.state);

  BackBreaks copy() => BackBreaks(base, cursor, start, state);

  /// The index of the next grapheme cluster break in first-to-last index order.
  ///
  /// Returns a negative number if there are no further breaks,
  /// which means that [cursor] has reached [start].
  int nextBreak() {
    while (cursor > start) {
      int breakAt = cursor;
      int char = base.codeUnitAt(--cursor);
      if (char & 0xFC00 != 0xDC00) {
        state = moveBack(state, low(char));
        if (state >= stateLookaheadMin) state = _lookAhead(state);
        if (state & stateNoBreak == 0) {
          return breakAt;
        }
        continue;
      }
      // The category of an unpaired tail surrogate is Control.
      int category = categoryControl;
      if (cursor >= start) {
        int prevChar = base.codeUnitAt(cursor - 1);
        if (prevChar & 0xFC00 == 0xD800) {
          category = high(prevChar, char);
          cursor -= 1;
        }
      }
      state = moveBack(state, category);
      if (state >= stateLookaheadMin) state = _lookAhead(state);
      if (state & stateNoBreak == 0) {
        return breakAt;
      }
    }
    state = moveBack(state, categoryEoT);
    if (state >= stateLookaheadMin) state = _lookAhead(state);
    if (state & stateNoBreak == 0) return cursor;
    return -1;
  }

  int _lookAhead(int state) => lookAhead(base, start, cursor, state);
}

/// Request a lookahead for [state].
///
/// The [state] was output by the backwards grapheme cluster state
/// machine and is above [stateLookaheadMin].
/// The lookahead looks at the [base] string from just before [cursor]
/// back to [start], to detect which actual state to enter.
int lookAhead(String base, int start, int cursor, int state) {
  assert(state >= stateLookaheadMin);
  if (state == stateRegionalLookahead) {
    return lookAheadRegional(base, start, cursor);
  }
  if (state == stateZWJPictographicLookahead) {
    return lookAheadZWJPictorgraphic(base, start, cursor);
  }
  throw StateError("Unexpected state: ${state.toRadixString(16)}");
}

/// Counts preceding regional indicators.
///
/// The look-ahead for the backwards moving grapheme cluster
/// state machine is called when two RIs are found in a row.
/// The [cursor] points to the first code unit of the former of those RIs,
/// and it preceding RIs until [start].
/// If that count is even, there should not be a break before
/// the second of the original RIs.
/// If the count is odd, there should be a break, because that RI
/// is combined with a prior RI in the string.
int lookAheadRegional(String base, int start, int cursor) {
  // Has just seen second regional indicator.
  // Figure out if there are an odd or even number of preceding RIs.
  // ALL REGIONAL INDICATORS ARE NON-BMP CHARACTERS.
  int count = 0; // Include the current character triggering this.
  int index = cursor;
  while (index - 2 >= start) {
    int tail = base.codeUnitAt(index - 1);
    if (tail & 0xFC00 != 0xDC00) break;
    int lead = base.codeUnitAt(index - 2);
    if (lead & 0xFC00 != 0xD800) break;
    int category = high(lead, tail);
    if (category != categoryRegionalIndicator) break;
    index -= 2;
    count ^= 1;
  }
  if (count == 0) {
    return stateRegionalEven | stateNoBreak;
  } else {
    return stateRegionalOdd;
  }
}

/// Checks if a ZWJ+Pictographic token sequence should be broken.
///
/// The sequence should no be broken if the preceding code points
/// are Pictographic Extend*.
/// Only the [base] string from [start] to [cursor] is checked.
/// The [cursor] points to the ZWJ code point.
int lookAheadZWJPictorgraphic(String base, int start, int cursor) {
  // Has just seen ZWJ+Pictographic. Check if preceeding is Pic Ext*.
  // (If so, just move cursor back to the Pic).
  int index = cursor;
  while (index > start) {
    int char = base.codeUnitAt(--index);
    int prevChar = 0;
    int category = categoryControl;
    if (char & 0xFC00 != 0xDC00) {
      category = low(char);
    } else if (index > start &&
        (prevChar = base.codeUnitAt(--index)) & 0xFC00 == 0xD800) {
      category = high(prevChar, char);
    } else {
      break;
    }
    if (category == categoryPictographic) {
      return stateZWJPictographic | stateNoBreak;
    }
    if (category != categoryExtend) break;
  }
  return stateExtend; // State for break before seeing ZWJ.
}

/// Whether there is a grapheme cluster boundary before [index] in [text].
///
/// This is a low-level function. There is no validation of the arguments.
/// They should satisfy `0 <= start <= index <= end <= text.length`.
bool isGraphemeClusterBoundary(String text, int start, int end, int index) {
  assert(0 <= start);
  assert(start <= index);
  assert(index <= end);
  assert(end <= text.length);
  // Uses the backwards automaton because answering the question
  // might be answered by looking only at the code points around the
  // index, but it may also require looking further back. It never
  // requires looking further ahead, though.
  // The backwards automaton is built for this use case.
  // Most of the apparent complication in this function is merely dealing with
  // surrogates.
  if (start < index && index < end) {
    // Something on both sides of index.
    int char = text.codeUnitAt(index);
    int prevChar = text.codeUnitAt(index - 1);
    int catAfter = categoryControl;
    if (char & 0xF800 != 0xD800) {
      catAfter = low(char);
    } else if (char & 0xFC00 == 0xD800) {
      // Lead surrogate. Combine with following tail surrogate,
      // otherwise it's a control and always a boundary.
      if (index + 1 >= end) return true;
      int nextChar = text.codeUnitAt(index + 1);
      if (nextChar & 0xFC00 != 0xDC00) return true;
      catAfter = high(char, nextChar);
    } else {
      // Tail surrogate after index. Either combines with lead surrogate
      // before or is always a bundary.
      return prevChar & 0xFC00 != 0xD800;
    }
    int catBefore = categoryControl;
    if (prevChar & 0xFC00 != 0xDC00) {
      catBefore = low(prevChar);
      index -= 1;
    } else {
      // If no prior lead surrogate, it's a control and always a boundary.
      index -= 2;
      if (start <= index) {
        int prevPrevChar = text.codeUnitAt(index);
        if (prevPrevChar & 0xFC00 != 0xD800) {
          return true;
        }
        catBefore = high(prevPrevChar, prevChar);
      } else {
        return true;
      }
    }
    var state = moveBack(stateEoTNoBreak, catAfter);
    // It requires at least two moves from EoT to trigger a lookahead,
    // either ZWJ+Pic or RI+RI.
    assert(state < stateLookaheadMin);
    state = moveBack(state, catBefore);
    if (state >= stateLookaheadMin) {
      state = lookAhead(text, start, index, state);
    }
    return state & stateNoBreak == 0;
  }
  // Always boundary at EoT or SoT, unless there is nothing between them.
  return start != end;
}
