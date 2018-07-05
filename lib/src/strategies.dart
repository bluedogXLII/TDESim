import 'maneuvers.dart';
import 'model.dart';

abstract class Strategy {
  const Strategy([this.maneuvers = Maneuver.values]);

  /// The maneuvers this strategy may choose from. [enumerateChoices] will never
  /// return a maneuver not in this list, but a strategy may decide to discard
  /// a maneuver even if it occurs in this list.
  final List<Maneuver> maneuvers;

  List<PlayerChoice> enumerateChoices(HalfACombatRound turn);
}

/// A strategy that explores the whole search space.
class TotalStrategy extends Strategy {
  const TotalStrategy([List<Maneuver> maneuvers]) : super(maneuvers);

  @override
  List<PlayerChoice> enumerateChoices(HalfACombatRound turn) {
    final result = <PlayerChoice>[];
    for (final maneuver in maneuvers) {
      final maneuverPenalty = maneuver.calculatePenalty(turn.defender.ar);
      for (var feint = 0; feint < turn.attacker.at - maneuverPenalty; feint++) {
        for (var forcefulBlow = 0;
            forcefulBlow < turn.attacker.at - maneuverPenalty - feint;
            forcefulBlow++) {
          result.add(new PlayerChoice(maneuver, feint, forcefulBlow));
        }
      }
    }
    return result;
  }
}
