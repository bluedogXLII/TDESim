import 'maneuvers.dart';
import 'model.dart';

abstract class StrategySpace {
  const StrategySpace(this.maneuvers);

  /// The maneuvers this strategy may choose from. [enumerateChoices] will never
  /// return a maneuver not in this list, but a strategy may decide to discard
  /// a maneuver even if it occurs in this list.
  final List<Maneuver> maneuvers;

  List<PlayerChoice> enumerateChoices(HalfACombatRound turn);
}

/// All possible strategies.
class AllStrategies extends StrategySpace {
  const AllStrategies([List<Maneuver> maneuvers = Maneuver.values])
      : super(maneuvers);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    final result = <PlayerChoice>[];

    for (final maneuver in maneuvers) {
      final maxPenalty = turn.attacker.at -
          turn.attackerPenalty -
          2 * turn.attackerWounds -
          maneuver.calculatePenalty(turn.defender.ar);

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
