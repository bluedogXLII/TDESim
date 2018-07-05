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
      // Erschwernis. Wie übersetzt man das?
      var complication = 0;

      // ignore: literal_only_boolean_expressions
      while (true) {
        final choice = new PlayerChoice(turn, maneuver, complication, 0);
        // TODO: Can you win an attack with success chance 0 if you roll a 1?
        // Are you even allowed to announce that attack?
        if (choice.requiredSuccessRoll <= 0) {
          break;
        }
        // Enumerate all other distributions of [complication] onto `feint` and
        // `forcefulBlow`
        for (var i = 1; i <= complication; i++) {
          // TODO: Not all maneuvers allow feint or forceful blow. Add an
          // appropriate getter to [Maneuver] and check it here.
          final feint = complication - i;
          final forcefulBlow = complication - feint;
          result.add(new PlayerChoice(turn, maneuver, feint, forcefulBlow));
        }
        complication++;
      }
    }
    return result;
  }
}
