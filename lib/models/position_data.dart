/*
 *     Copyright (C) 2025 Akash Patel
 *
 *     Reverbio is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Reverbio is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Reverbio, including how to contribute,
 *     please visit: https://github.com/akashskypatel/Reverbio
 */

/// R1 fix: PositionData with value equality to prevent duplicate events
/// R4 fix: Added invariant validation via factory constructor
/// R5 fix: Added const constructor (without validation)
/// R6 fix: Added toString() override for debugging
class PositionData {
  const PositionData(
    this.position,
    this.bufferedPosition,
    this.duration,
  );

  factory PositionData.validated(
    Duration position,
    Duration bufferedPosition,
    Duration duration,
  ) {
    assert(!position.isNegative, 'position cannot be negative');
    assert(!bufferedPosition.isNegative, 'bufferedPosition cannot be negative');
    assert(!duration.isNegative, 'duration cannot be negative');
    return PositionData(
      position,
      bufferedPosition,
      duration,
    );
  }

  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionData &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          bufferedPosition == other.bufferedPosition &&
          duration == other.duration;

  @override
  int get hashCode =>
      position.hashCode ^ bufferedPosition.hashCode ^ duration.hashCode;

  @override
  String toString() =>
      'PositionData(position: $position, buffered: $bufferedPosition, duration: $duration)';
}
