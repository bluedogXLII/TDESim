import 'dart:math';

import 'maneuvers.dart';
import 'model.dart';

abstract class Strategy {
  const Strategy(this.maneuvers);

  /// The maneuvers this strategy may choose from. [enumerateChoices] will never
  /// return a maneuver not in this list, but a strategy may decide to discard
  /// a maneuver even if it occurs in this list.
  final List<Maneuver> maneuvers;

  List<PlayerChoice> enumerateChoices(HalfACombatRound turn);
}

/// A strategy that explores the whole search space.
class TotalStrategy extends Strategy {
  const TotalStrategy([List<Maneuver> maneuvers = Maneuver.values])
      : super(maneuvers);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    final result = <PlayerChoice>[];
    for (final maneuver in maneuvers) {
      final maneuverPenalty = maneuver.calculatePenalty(turn.defender.ar);

      // Erschwernis. Wie übersetzt man das?
      var complication = 0;

      // ignore: literal_only_boolean_expressions
      while (true) {
        final requiredAttackRoll = min(
            turn.attacker.at -
                turn.attackerPenalty -
                turn.attackerWounds * 2 -
                maneuverPenalty -
                complication,
            19);
        // TODO: Can you win an attack with success chance 0 if you roll a 1?
        // Are you even allowed to announce that attack?
        if (requiredAttackRoll <= 0) {
          break;
        }
        for (var i = 0; i <= complication; i++) {
          // TODO: Not all maneuvers allow feint or forceful blow. Add an
          // appropriate getter to [Maneuver] and check it here.
          final feint = complication - i;
          final forcefulBlow = complication - feint;
          result.add(new PlayerChoice(
              maneuver, feint, forcefulBlow, requiredAttackRoll));
        }
        complication++;
      }
    }
    return result;
  }
}
