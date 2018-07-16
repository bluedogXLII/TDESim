import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'strategies.dart';

final Rational _one = new Rational.fromInt(1);
final Rational _oneSixth = new Rational.fromInt(1, 6);

class Hero {
  final String name;

  ///wound threshold: WS
  final int wt;

  /// armor rating (RS): Incoming damage is reduced by this amount.
  final int ar;

  /// hit points (TP): Damage dealt with a successful attack.
  final int hp;

  /// attack value (AT): An attack is successful if the attacker rolls a lower
  /// number than this on a D20.
  final int at;

  /// parry value (PA): A parry is successful if the defender rolls a lower
  /// number than this on a D20.
  final int pa;

  final StrategySpace strategySpace;

  Hero(this.name, this.strategySpace,
      {@required this.wt,
      @required this.ar,
      @required this.hp,
      @required this.at,
      @required this.pa});
}

class PlayerChoice {
  PlayerChoice(this.turn, this.maneuver, this.feint, this.forcefulBlow);

  final HalfACombatRound turn;
  final Maneuver maneuver;
  final int feint;
  final int forcefulBlow;

  /// Sum of [feint], [forcefulBlow] and the maneuver penalty.
  int get attackPenalty =>
      feint + forcefulBlow + maneuver.calculatePenalty(turn.defender.ar);

  /// The expected payoff of a choice is the sum over all [transitions],
  /// weighted with their probability.
  /// The positive payoff of a PlayerChoice benefits the current attacker
  /// and must therefore be inversely related to the payoff of the next
  /// rounds, the payoff of which benefits the defender of the current
  /// round.
  Rational get payoff => _payoff ??= transitions.entries
      .map((transition) => -transition.key.payoff * transition.value)
      .reduce((a, b) => a + b);
  Rational _payoff;

  /// All succeeding combat rounds that have a non-zero chance of happening.
  /// The values of this map are the probabilities of this transition being
  /// taken, in the range (0, 1].
  Map<HalfACombatRound, Rational> get transitions =>
      _transitions ??= _calculateTransitions();
  Map<HalfACombatRound, Rational> _transitions;

  Map<HalfACombatRound, Rational> _calculateTransitions() {
    final attacker = turn.attacker;
    final defender = turn.defender;
    final result = <HalfACombatRound, Rational>{};

    /// [attackerPenalty] is for the attacker in **this** turn, not the next!
    void addSuccessor(Rational successorProbability,
            {@required int damage,
            @required int wounds,
            @required int attackerPenalty,
            @required int defenderPenalty}) =>
        result[new HalfACombatRound._(
            attacker: defender,
            defender: attacker,
            attackerLostVp: turn.defenderLostVp + damage,
            defenderLostVp: turn.attackerLostVp,
            attackerPenalty: defenderPenalty,
            defenderPenalty: attackerPenalty,
            attackerWounds: turn.defenderWounds + wounds,
            defenderWounds: turn.attackerWounds,
            allowParry: !maneuver.consumesDefensiveAction,
            remainingDepth: turn.remainingDepth - 1)] = successorProbability;

    final attackSuccess = new Rational.fromInt(
        (turn.attacker.at -
                turn.attackerPenalty -
                turn.attackerWounds * 2 -
                attackPenalty)
            .clamp(1, 19),
        20);

    // attack failed
    addSuccessor(_one - attackSuccess,
        damage: 0,
        wounds: 0,
        attackerPenalty: maneuver.calculateAttackerPenalty(feint, forcefulBlow),
        defenderPenalty: turn.defenderPenalty);

    if (turn.allowParry) {
      // parry allowed
      final parrySuccess = new Rational.fromInt(
          (defender.pa - feint - turn.defenderPenalty - 2 * turn.defenderWounds)
              .clamp(1, 19),
          20);

      // parry succeeded
      addSuccessor(attackSuccess * parrySuccess,
          damage: 0, wounds: 0, attackerPenalty: 0, defenderPenalty: 0);

      final hitSuccess = attackSuccess * (_one - parrySuccess);
      for (var roll = 6; roll >= 1; roll--) {
        final dmg = maneuver.calculateDamage(
            attacker.hp, roll, forcefulBlow, defender.ar);
        if (dmg > 0) {
          // attack succeeded
          addSuccessor(hitSuccess * _oneSixth,
              damage: dmg,
              wounds: maneuver.calculateWounds(dmg, defender.wt),
              attackerPenalty: 0,
              defenderPenalty: 0);
        } else {
          // no damage dealt
          addSuccessor(hitSuccess * new Rational.fromInt(roll, 6),
              damage: 0,
              wounds: maneuver.calculateWounds(0, turn.defender.wt),
              attackerPenalty: 0,
              defenderPenalty: 0);
          break;
        }
      }
    } else {
      // no parry allowed
      for (var roll = 6; roll >= 1; roll--) {
        final dmg = maneuver.calculateDamage(
            attacker.hp, roll, forcefulBlow, defender.ar);
        if (dmg > 0) {
          // attack succeeded
          addSuccessor(attackSuccess * _oneSixth,
              damage: dmg,
              wounds: maneuver.calculateWounds(dmg, defender.wt),
              attackerPenalty: 0,
              defenderPenalty: turn.defenderPenalty);
        } else {
          // no damage dealt
          addSuccessor(attackSuccess * new Rational.fromInt(roll, 6),
              damage: 0,
              wounds: maneuver.calculateWounds(0, turn.defender.wt),
              attackerPenalty: 0,
              defenderPenalty: turn.defenderPenalty);
          break;
        }
      }
    }

    assert(result.values.reduce((a, b) => a + b) == _one,
        'The sum of all probablities must be 1');
    return result;
  }

  @override
  String toString() =>
      'maneuver: $maneuver, feint: $feint, forcefulBlow: $forcefulBlow';
}

class HalfACombatRound {
  /// Creates a new combat round for a new combat.
  HalfACombatRound(this.attacker, this.defender, this.remainingDepth)
      : attackerLostVp = 0,
        defenderLostVp = 0,
        attackerPenalty = 0,
        defenderPenalty = 0,
        attackerWounds = 0,
        defenderWounds = 0,
        allowParry = true;

  /// Internal constructor for succeeding combat rounds.
  HalfACombatRound._(
      {@required this.attacker,
      @required this.defender,
      @required this.attackerLostVp,
      @required this.defenderLostVp,
      @required this.attackerPenalty,
      @required this.defenderPenalty,
      @required this.attackerWounds,
      @required this.defenderWounds,
      @required this.allowParry,
      @required this.remainingDepth});

  final Hero attacker, defender;
  final int attackerLostVp, defenderLostVp; // LeP
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final bool allowParry;
  final int remainingDepth;

  /// All choices that the [attacker]s [StrategySpace] considers, ordered by payoff
  /// descending, or an empty list if [remainingDepth] is 0.
  List<PlayerChoice> get choices => _choices ??= remainingDepth == 0
      ? const []
      : attacker.strategySpace.enumerateChoices(this);
  List<PlayerChoice> _choices;

  /// The choice with the highest payoff. Throws an [AssertionError] if this is
  /// a leaf.
  PlayerChoice get bestChoice {
    assert(_choices != null);
    assert(
        remainingDepth > 0,
        "Can't get the best choice of a state whose choices "
        "shouldn't be generated (because remainingDepth == 0)");
    if (!_choicesSorted) {
      choices.sort(_sortChoicesDescending);
      _choicesSorted = true;
    }
    return choices.first;
  }

  bool _choicesSorted = false;

  /// The payoff is the difference between attacker and defender VP if this is a
  /// leaf, or the best payoff of all children if this is an internal node.
  /// A positive Payoff benefits the attacker of the current round.
  Rational get payoff => _payoff ??= remainingDepth == 0
      ? new Rational.fromInt(defenderLostVp - attackerLostVp)
      : bestChoice.payoff;
  Rational _payoff;

  @override
  String toString() => '$remainingDepth rounds to go: '
      '${attacker.name} (lost vp=$attackerLostVp, wounds=$attackerWounds) '
      'attacks '
      '${defender.name} (lost vp=$defenderLostVp, wounds=$defenderWounds)';
}

/// A [Comparator] that sorts the [PlayerChoice] with the highest payoff on the
/// first position.
int _sortChoicesDescending(PlayerChoice a, PlayerChoice b) =>
    (b.payoff - a.payoff).signum;
