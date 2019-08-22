// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import "dart:collection";

import "grapheme_clusters/constants.dart";
import "grapheme_clusters/breaks.dart";

/// The grapheme cluster boundaries in [string].
///
/// The [start] and [end] must satisfy `0 <= start <= end <= string.length`.
/// If [end] is omitted, it defaults to `string.length`.
///
/// Finds the boundaries of grapheme clusters after [start], and up to [end], in
/// the string `string.substring(start, end)`. Always includes [start] and [end]
/// unless `start == end`.
Iterable<int> graphemeClusterBoundaries(String string,
    [int start = 0, int end]) sync* {
  end = RangeError.checkValidRange(start, end, string.length);
  var breaks = Breaks(string, start, end, stateSoT);
  int breakAt;
  while ((breakAt = breaks.nextBreak()) >= 0) yield breakAt;
}

/// The grapheme clusters of a string.
abstract class GraphemeClusters implements Iterable<String> {
  /// Creates a [GraphemeClusters] allowing iteration of
  /// the grapheme clusters of [string].
  factory GraphemeClusters(String string) = _GraphemeClusters;

  /// The string to iterate over.
  String get string;

  /// A specialized grapheme cluster iterator.
  ///
  /// Allows iterating the grapheme clusters of [string] as a plain iterator,
  // as well as controlling the iteration in more detail.
  GraphemeCluster get iterator;

  /// Whether [graphemeCluster] is an element of this sequence of
  /// grapheme clusters.
  ///
  /// Returns false if [graphemeCluster] is not a string containing
  /// a single grapheme cluster,
  /// because then it is not a single element of this [Iterable]
  /// of grapheme clusters.
  bool contains(Object graphemeCluster);

  /// Whether this sequence of grapheme clusters contains [other]
  /// as a subsequence.
  bool containsAll(GraphemeClusters other);

  /// The first string index where [other] occurs as a subsequence of these
  /// grapheme clusters.
  ///
  /// If [startIndex] is supplied, searching starts at [startIndex], which
  /// *should* be a grapheme cluster boundary.
  int indexOf(GraphemeClusters other, [int startIndex = 0]);

  /// Whether [other] is an initial subsequence of this sequence
  /// of grapheme clusters.
  ///
  /// If [startIndex] is provided, then checks whether
  /// [other] is an initial subsequence of the grapheme clusters
  /// of the substring of [string] starting at [startIndex].
  bool startsWith(GraphemeClusters other, [int startIndex = 0]);

  /// Whether [other] is an trailing subsequence of this sequence
  /// of grapheme clusters.
  ///
  /// If [endIndex] is provided, then checks whether
  /// [other] is an trailing subsequence of the grapheme clusters
  /// of the substring of [string] ending at [endIndex].
  bool endsWith(GraphemeClusters other, [int endIndex]);

  /// Returns a new grapheme clusters sequence where [source] has been
  /// replaced by [replacement].start
  ///
  /// If [startIndex] is provided, instead replaces grapheme clusters of the
  /// substring of [string] starting at [startIndex].
  /// The [startIndex] should be a grapheme cluster boundary in [string],
  /// otherwise the replaced substrings may not correspond to grapheme
  /// clusters of this sequence.
  GraphemeClusters replaceAll(
      GraphemeClusters source, GraphemeClusters replacement,
      [int startIndex = 0]);

  /// Returns a new grapheme clusters sequence where the first occurrence of
  /// [source] has been replaced by [replacement].
  ///
  /// If [startIndex] is provided, instead replaces the first matching
  /// grapheme clusters of the substring of [string] starting at [startIndex].
  /// The [startIndex] should be a grapheme cluster boundary in [string],
  /// otherwise the replaced substrings may not correspond to grapheme
  /// clusters of this sequence.
  GraphemeClusters replaceFirst(
      GraphemeClusters source, GraphemeClusters replacement,
      [int startIndex = 0]);
}

/// Iterator over grapheme clusters of a string.
abstract class GraphemeCluster implements BidirectionalIterator<String> {
  /// Creates a new grapheme cluster iterator iterating the grapheme
  /// clusters of [string].
  factory GraphemeCluster(String string) = _GraphemeCluster;

  /// The beginning of the current grapheme cluster in the underlying string.
  ///
  /// This index is always at a cluster boundary unless the iterator
  /// has been reset to a non-boundary index.
  ///
  /// If equal to [end], there is no current grapheme cluster, and [moveNext]
  /// needs to be called first before accessing [current].
  /// This is the case at the beginning of iteration,
  /// after [moveNext] has returned false,
  /// or after calling [reset].
  int get start;

  /// The end of the current grapheme cluster in the underlying string.
  ///
  /// This index is always at a cluster boundary unless the iterator
  /// has been reset to a non-boundary index.
  ///
  /// If equal to [start], there is no current grapheme cluster.
  int get end;

  /// The code units of the current grapheme cluster.
  List<int> get codeUnits;

  /// The code points of the current grapheme cluster.
  Runes get runes;

  /// Resets the iterator to the [index] position.
  ///
  /// There is no [current] grapheme cluster after a reset,
  /// a call to [moveNext] is needed to find the end of the grapheme cluster
  /// at the [index] position.
  /// A `reset(0)` will reset to the beginning of the string, as for a newly
  /// created iterator.
  void reset(int index);

  /// Creates a copy of this [GraphemeIterator].
  ///
  /// The copy is in the exact same state as this iterator.
  /// Can be used to iterate the following grapheme clusters more than once
  /// at the same time. To simply rewind an iterator, remember the
  /// [start] or [end] position and use [reset] to reset the iterator
  /// to that position.
  GraphemeCluster copy();
}

/// The grapheme clusters of a string.
class _GraphemeClusters extends Iterable<String> implements GraphemeClusters {
  final String string;

  _GraphemeClusters(this.string);

  GraphemeCluster get iterator => _GraphemeCluster(string);

  String get first => string.isEmpty
      ? throw StateError("No element")
      : string.substring(
          0, Breaks(string, 0, string.length, stateSoTNoBreak).nextBreak());

  String get last => string.isEmpty
      ? throw StateError("No element")
      : string.substring(
          BackBreaks(string, string.length, 0, stateEoTNoBreak).nextBreak());

  String get single {
    if (string.isEmpty) throw StateError("No element");
    int firstEnd =
        Breaks(string, 0, string.length, stateSoTNoBreak).nextBreak();
    if (firstEnd == string.length) return string;
    throw StateError("Too many elements");
  }

  bool get isEmpty => string.isEmpty;

  bool get isNotEmpty => string.isNotEmpty;

  int get length {
    if (string.isEmpty) return 0;
    var brk = Breaks(string, 0, string.length, stateSoTNoBreak);
    int length = 0;
    while (brk.nextBreak() >= 0) length++;
    return length;
  }

  Iterable<T> whereType<T>() {
    Iterable<Object> self = this;
    if (self is Iterable<T>) {
      return self.map((x) => x);
    }
    return Iterable<T>.empty();
  }

  String join([String separator = ""]) {
    if (separator == "") return string;
    return super.join(separator);
  }

  String lastWhere(bool test(String element), {String orElse()}) {
    int cursor = string.length;
    var brk = BackBreaks(string, cursor, 0, stateEoTNoBreak);
    int next = 0;
    while ((next = brk.nextBreak()) >= 0) {
      String current = string.substring(next, cursor);
      if (test(current)) return current;
      cursor = next;
    }
    if (orElse != null) return orElse();
    throw StateError("no element");
  }

  bool contains(Object other) {
    if (other is String) {
      if (other.isEmpty) return false;
      int i = 0;
      while (i + other.length <= string.length) {
        int index = string.indexOf(other, i);
        if (index < 0) return false;
        if (isGraphemeClusterBoundary(string, 0, string.length, index)) {
          int next =
              Breaks(string, index, string.length, stateSoTNoBreak).nextBreak();
          assert(next >= 0);
          if (next == index + other.length) return true;
        }
        i = index + 1;
      }
    }
    return false;
  }

  int indexOf(GraphemeClusters other, [int startIndex = 0]) {
    int length = string.length;
    RangeError.checkValidRange(startIndex, length, length, "startIndex");
    return _indexOf(other, startIndex);
  }

  int _indexOf(GraphemeClusters other, int startIndex) {
    String otherString = other.string;
    int otherLength = otherString.length;
    if (otherLength == 0) return startIndex;
    int length = string.length;
    int index = startIndex;
    while (index + otherLength <= length) {
      int matchIndex = string.indexOf(otherString, startIndex);
      if (matchIndex < 0) return matchIndex;
      if (isGraphemeClusterBoundary(string, startIndex, length, matchIndex) &&
          isGraphemeClusterBoundary(
              string, startIndex, length, matchIndex + otherLength)) {
        return matchIndex;
      }
      startIndex = matchIndex + 1;
    }
    return -1;
  }

  bool startsWith(GraphemeClusters other, [int startIndex = 0]) {
    RangeError.checkValueInInterval(startIndex, 0, string.length, "startIndex");
    String otherString = other.string;
    if (otherString.isEmpty) return true;
    return string.startsWith(otherString, startIndex) &&
        isGraphemeClusterBoundary(
            string, 0, string.length, startIndex + otherString.length);
  }

  bool endsWith(GraphemeClusters other, [int endIndex]) {
    String otherString = other.string;
    if (otherString.isEmpty) return true;
    int length = string.length;
    int otherLength = otherString.length;
    if (endIndex == null || endIndex == length) {
      return string.endsWith(otherString) &&
          isGraphemeClusterBoundary(string, 0, length, length - otherLength);
    }
    int start = endIndex - otherLength;
    return start >= 0 &&
        string.startsWith(otherString, start) &&
        isGraphemeClusterBoundary(string, 0, endIndex, start);
  }

  GraphemeClusters replaceAll(
      GraphemeClusters pattern, GraphemeClusters replacement,
      [int startIndex = 0]) {
    if (startIndex > 0) {
      RangeError.checkValueInInterval(
          startIndex, 0, string.length, "startIndex");
    }
    if (pattern.string.isEmpty) {
      if (string.isEmpty) return replacement;
      return GraphemeClusters(_explodeReplace(replacement.string, startIndex));
    }
    int start = startIndex;
    StringBuffer buffer;
    int next = -1;
    while ((next = this.indexOf(pattern, start)) >= 0) {
      (buffer ??= StringBuffer())
        ..write(string.substring(start, next))
        ..write(replacement);
      start = next + pattern.string.length;
    }
    if (buffer == null) return this;
    buffer.write(string.substring(start));
    return GraphemeClusters(buffer.toString());
  }

  // Replaces every grapheme cluster boundary with [replacement].
  // Starts at startIndex.
  String _explodeReplace(String replacement, int startIndex) {
    var buffer = StringBuffer(string.substring(0, startIndex));
    var breaks = Breaks(string, startIndex, string.length, stateSoTNoBreak);
    int index = 0;
    while ((index = breaks.nextBreak()) >= 0) {
      buffer..write(replacement)..write(string.substring(startIndex, index));
      startIndex = index;
    }
    buffer.write(replacement);
    return buffer.toString();
  }

  GraphemeClusters replaceFirst(
      GraphemeClusters source, GraphemeClusters replacement,
      [int startIndex = 0]) {
    if (startIndex != 0) {
      RangeError.checkValueInInterval(
          startIndex, 0, string.length, "startIndex");
    }
    int index = this.indexOf(source, startIndex);
    if (index < 0) return this;
    return GraphemeClusters(string.replaceRange(
        index, index + source.string.length, replacement.string));
  }

  bool containsAll(GraphemeClusters other) {
    return _indexOf(other, 0) >= 0;
  }
}

class _GraphemeCluster implements GraphemeCluster {
  static const int _directionForward = 0;
  static const int _directionBackward = 0x04;
  static const int _directionMask = 0x04;
  static const int _cursorDeltaMask = 0x03;

  final String _string;
  int _start;
  int _end;
  // Encodes current state,
  // whether we are moving forwards or backwards ([_directionMask]),
  // and how far ahead the cursor is from the start/end ([_cursorDeltaMask]).
  int _state;
  String _currentCache;

  _GraphemeCluster(String string) : this._(string, 0, 0, stateSoTNoBreak);
  _GraphemeCluster._(this._string, this._start, this._end, this._state);

  int get start => _start;
  int get end => _end;

  String get current => _currentCache ??=
      (_start == _end ? null : _string.substring(_start, _end));

  bool moveNext() {
    int state = _state;
    int cursor = _end;
    if (state & _directionMask != _directionForward) {
      state = stateSoTNoBreak;
    } else {
      cursor += state & _cursorDeltaMask;
    }
    var breaks = Breaks(_string, cursor, _string.length, state);
    var next = breaks.nextBreak();
    _currentCache = null;
    if (next >= 0) {
      _start = _end;
      _end = next;
      _state =
          (breaks.state & 0xF0) | _directionForward | (breaks.cursor - next);
      return true;
    }
    _state = stateEoTNoBreak | _directionBackward;
    _start = _end;
    return false;
  }

  bool movePrevious() {
    int state = _state;
    int cursor = _start;
    if (state & _directionMask == _directionForward) {
      state = stateEoTNoBreak;
    } else {
      cursor -= state & _cursorDeltaMask;
    }
    var breaks = BackBreaks(_string, cursor, 0, state);
    var next = breaks.nextBreak();
    _currentCache = null;
    if (next >= 0) {
      _end = _start;
      _start = next;
      _state =
          (breaks.state & 0xF0) | _directionBackward | (next - breaks.cursor);
      return true;
    }
    _state = stateSoTNoBreak | _directionForward;
    _end = start;
    return false;
  }

  List<int> get codeUnits => _CodeUnits(_string, _start, _end);

  Runes get runes => Runes(current);

  void reset(int index) {
    RangeError.checkValueInInterval(index, 0, _string.length, "index");
    _state = stateSoTNoBreak | _directionForward;
    _currentCache = null;
    _start = _end = index;
  }

  GraphemeCluster copy() {
    return _GraphemeCluster._(_string, _start, _end, _state);
  }
}

class _CodeUnits extends ListBase<int> {
  final String _string;
  final int _start;
  final int _end;

  _CodeUnits(this._string, this._start, this._end);

  int get length => _end - _start;

  int operator [](int index) {
    RangeError.checkValidIndex(index, this, "index", _end - _start);
    return _string.codeUnitAt(_start + index);
  }

  void operator []=(int index, int value) {
    throw UnsupportedError("Cannot modify an unmodifiable list");
  }

  @override
  void set length(int newLength) {
    throw UnsupportedError("Cannot modify an unmodifiable list");
  }
}
