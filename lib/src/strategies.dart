import 'dart:math';
import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'model.dart';

abstract class StrategySpace {
  StrategySpace(this.maneuvers);

  /// The maneuvers this strategy may choose from. [enumerateChoices] will never
  /// return a maneuver not in this list, but a strategy may decide to discard
  /// a maneuver even if it occurs in this list.
  final List<Maneuver> maneuvers;

  List<PlayerChoice> enumerateChoices(CombatTurn turn);
}

/// All possible strategies.
class AllAttacks extends StrategySpace {
  AllAttacks() : super(Maneuver.values);

  @override
  List<PlayerChoice> enumerateChoices(CombatTurn turn) {
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

  @override
  String toString() => 'AllAttacks';
}

class NormalAttacks extends StrategySpace {
  NormalAttacks() : super([Maneuver.normalAttack]);

  @override
  List<PlayerChoice> enumerateChoices(CombatTurn turn) {
    final result = <PlayerChoice>[];

    for (var w = 0; w < turn.attacker.at; w++) {
      for (var f = 0; f < turn.attacker.at - w; f++) {
        result.add(new PlayerChoice(turn, Maneuver.normalAttack, w, f));
      }
    }

    return result;
  }

  @override
  String toString() => 'NormalAttacks';
}

class ShorttermAttacks extends StrategySpace {
  ShorttermAttacks() : super([Maneuver.normalAttack]);

  final Rational _zero = new Rational.fromInt(0);
  final Rational _one400th = new Rational.fromInt(1, 400);
  final Rational _oneThird = new Rational.fromInt(1, 3);
  final Rational _oneHalf = new Rational.fromInt(1, 2);
  final Rational _nineteen = new Rational.fromInt(19);

  Rational expectedMaxFunction(
          Rational a, Rational p, Rational s, Rational w, Rational f) =>
      _one400th * (a - w - f) * (p + f) * (s + w);

  @override
  List<PlayerChoice> enumerateChoices(CombatTurn turn) {
    assert(1 <= turn.attacker.at && turn.attacker.at <= 19);
    assert(1 <= turn.defender.pa && turn.defender.pa <= 19);
    //assert(turn.attacker.hp >= turn.defender.ar);

    final a = new Rational.fromInt(turn.attacker.at);
    final p = new Rational.fromInt(20 - turn.defender.pa);
    final s =
        new Rational.fromInt(2 * (turn.attacker.hp - turn.defender.ar) + 7, 2);

    final w = _oneThird * (a + p - s - s);
    final f = _oneThird * (a + s - p - p);
    if (_zero <= w && _zero <= f && f <= _nineteen - p) {
      var expectedMax = _zero;
      int intW, intF;
      for (var wTemp in [w.floor(), w.ceil()]) {
        for (var fTemp in [f.floor(), f.ceil()]) {
          if (expectedMaxFunction(a, p, s, wTemp, fTemp) > expectedMax) {
            intW = wTemp.toInt();
            intF = fTemp.toInt();
            expectedMax = expectedMaxFunction(a, p, s, wTemp, fTemp);
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

  @override
  String toString() => 'ShorttermAttacks';
}

class ZeroAttacks extends StrategySpace {
  ZeroAttacks() : super([Maneuver.normalAttack]);

  @override
  List<PlayerChoice> enumerateChoices(CombatTurn turn) =>
      [new PlayerChoice(turn, Maneuver.normalAttack, 0, 0)];

  @override
  String toString() => 'ZeroAttacks';
}

class RandomAttacks extends StrategySpace {
  RandomAttacks() : super([Maneuver.normalAttack]);

  final rng = new Random();

  @override
  List<PlayerChoice> enumerateChoices(CombatTurn turn) {
    final sum = rng.nextInt(turn.attacker.at - 1);
    final w = sum == 0 ? 0 : rng.nextInt(sum);
    final f = sum - w;
    return [new PlayerChoice(turn, Maneuver.normalAttack, w, f)];
  }

  @override
  String toString() => 'ZeroAttacks';
}
