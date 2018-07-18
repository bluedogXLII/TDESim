import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'model.dart';

abstract class StrategySpace {
  StrategySpace(this.maneuvers);

  /// The maneuvers this strategy may choose from. [enumerateChoices] will never
  /// return a maneuver not in this list, but a strategy may decide to discard
  /// a maneuver even if it occurs in this list.
  final List<Maneuver> maneuvers;

  List<PlayerChoice> enumerateChoices(HalfACombatRound turn);
}

/// All possible strategies.
class AllAttacks extends StrategySpace {
  AllAttacks() : super(Maneuver.values);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    final result = <PlayerChoice>[];

    for (final maneuver in maneuvers) {
      final maxPenalty =
          turn.attacker.at - maneuver.calculatePenalty(turn.defender.ar);

      for (var w = 0; w < maxPenalty; w++) {
        for (var f = 0; f < maxPenalty - w; f++) {
          result.add(new PlayerChoice(turn, maneuver, f, w));
        }
        if (!maneuver.allowsForcefulBlow) break;
      }
    }
    return result;
  }
}

class NormalAttacks extends StrategySpace {
  NormalAttacks() : super([Maneuver.normalAttack]);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    final result = <PlayerChoice>[];

    for (var w = 0; w < turn.attacker.at; w++) {
      for (var f = 0; f < turn.attacker.at - w; f++) {
        result.add(new PlayerChoice(turn, Maneuver.normalAttack, f, w));
      }
    }

    return result;
  }
}

class ShortSightedAttacks extends StrategySpace {
  ShortSightedAttacks() : super([Maneuver.normalAttack]);

  final Rational _zero = new Rational.fromInt(0);
  final Rational _one400th = new Rational.fromInt(1, 400);
  final Rational _oneThird = new Rational.fromInt(1, 3);
  final Rational _oneHalf = new Rational.fromInt(1, 2);
  final Rational _nineteen = new Rational.fromInt(19);

  Rational expectedMaxFunction(
          Rational a, Rational p, Rational s, Rational w, Rational f) =>
      _one400th * (a - w - f) * (p + f) * (s + w);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    assert(1 <= turn.attacker.at && turn.attacker.at <= 19);
    assert(1 <= turn.defender.pa && turn.defender.pa <= 19);
    assert(turn.attacker.hp >= turn.defender.ar);

    final a = new Rational.fromInt(turn.attacker.at);
    final p = new Rational.fromInt(20 - turn.defender.pa);
    final s =
        new Rational.fromInt(2 * (turn.attacker.hp - turn.defender.ar) + 7, 2);

    final w = _oneThird * (a + p - s - s);
    final f = _oneThird * (a + s - p - p);
    if (_zero <= w && _zero <= f && f <= _nineteen - p) {
      var expectedMax = _zero;
      int intW, intF;
      for (var wTemp in [w.floor().toInt(), w.ceil().toInt()]) {
        for (var fTemp in [f.floor().toInt(), f.ceil().toInt()]) {
          if (expectedMaxFunction(a, p, s, w, f) > expectedMax) {
            intW = wTemp;
            intF = fTemp;
            expectedMax = expectedMaxFunction(a, p, s, w, f);
          }
        }
      }
      return [
        new PlayerChoice(turn, Maneuver.normalAttack, intW, intF)
      ]; // (max)
    }

    if (p >= s) {
      if (a >= p) {
        return [
          new PlayerChoice(turn, Maneuver.normalAttack,
              (_oneHalf * (a - s)).round().toInt(), 0)
        ]; // (ii)
      } else if (a >= s) {
        return [
          new PlayerChoice(turn, Maneuver.normalAttack, 0,
              (_oneHalf * (a - p)).round().toInt())
        ]; // (i)
      }
    } else {
      if (a >= s) {
        return [
          new PlayerChoice(turn, Maneuver.normalAttack, 0,
              (_oneHalf * (a - p)).round().toInt())
        ]; // (i)
      } else if (a >= p) {
        return [
          new PlayerChoice(turn, Maneuver.normalAttack,
              (_oneHalf * (a - s)).round().toInt(), 0)
        ]; // (ii)
      }
    }

    return [new PlayerChoice(turn, Maneuver.normalAttack, 0, 0)]; // (i, ii)
  }
}

class StandardAttacks extends StrategySpace {
  StandardAttacks() : super([Maneuver.normalAttack]);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) =>
      [new PlayerChoice(turn, Maneuver.normalAttack, 0, 0)];
}
