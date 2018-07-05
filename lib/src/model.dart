import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'strategies.dart';

final Rational _one = new Rational.fromInt(1);
final Rational _oneSixth = new Rational.fromInt(1, 6);

class Hero {
  final String name;

  /// vitality (Le): The starting vitality points.
  @deprecated
  final int vi;

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

  final Strategy strategy;

  Hero(this.name, this.strategy,
      {@required this.vi,
      @required this.wt,
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

  /// If the attacker chooses to make this attack, they must roll this number or
  /// lower on a D20 to make a successful attack. This value is **not** clamped.
  int get requiredSuccessRoll =>
      turn.attacker.at -
      turn.attackerPenalty -
      turn.attackerWounds * 2 -
      attackPenalty;

  /// The expected payoff of a choice is the sum over all [transitions],
  /// weighted with their probability.
  Rational get payoff => _payoff ??= transitions.entries
      .map((transition) => transition.key.payoff * transition.value)
      .reduce((a, b) => a + b);
  Rational _payoff;

  /// All succeeding combat rounds that have a non-zero chance of happening.
  /// The values of this map are the probabilities of this transition being
  /// taken, in the range (0, 1].
  Map<HalfACombatRound, Rational> get transitions =>
      _transitions ??= _calculateTransitions();
  Map<HalfACombatRound, Rational> _transitions;

  Map<HalfACombatRound, Rational> _calculateTransitions() {
    assert(requiredSuccessRoll > 0);

    final attacker = turn.attacker;
    final defender = turn.defender;
    final result = <HalfACombatRound, Rational>{};

    /// [attackerPenalty] is for the attacker in **this** turn, not the next!
    void addSuccessor(Rational successorProbability,
            {int damage: 0, int wounds: 0, int attackerPenalty: 0}) =>
        result[new HalfACombatRound._(
            attacker: defender,
            defender: attacker,
            attackerLostVp: turn.defenderLostVp - damage,
            defenderLostVp: turn.attackerLostVp,
            attackerPenalty: 0,
            defenderPenalty: attackerPenalty,
            attackerWounds: turn.defenderWounds + wounds,
            defenderWounds: turn.attackerWounds,
            lastFeint: feint,
            lastForcefulBlow: forcefulBlow,
            lastManeuver: maneuver,
            probability: turn.probability * successorProbability,
            remainingDepth: turn.remainingDepth - 1)] = successorProbability;

    final attackSuccess =
        new Rational.fromInt(requiredSuccessRoll.clamp(1, 19), 20);

    // attack failed
    addSuccessor(_one - attackSuccess, attackerPenalty: attackPenalty);

    var parrySuccess = new Rational.fromInt(0);
    if (!turn.lastManeuver.consumesDefensiveAction) {
      parrySuccess = new Rational.fromInt(
          (defender.pa - feint - turn.defenderPenalty - 2 * turn.defenderWounds)
              .clamp(1, 19),
          20);

      // parry succeeded
      addSuccessor(attackSuccess * parrySuccess);
    }

    final hitSuccess = attackSuccess * (_one - parrySuccess);
    for (var roll = 6; roll >= 1; roll--) {
      final dmg = maneuver.calculateDamage(
          attacker.hp, roll, forcefulBlow, defender.ar);
      if (dmg > 0) {
        // attack succeeded
        addSuccessor(hitSuccess * _oneSixth,
            damage: dmg, wounds: maneuver.calculateWounds(dmg, defender.wt));
      } else {
        // no damage dealt
        addSuccessor(hitSuccess * new Rational.fromInt(roll, 6));
        break;
      }
    }

    assert(result.values.reduce((a, b) => a + b) == _one,
        'The sum of all probablities must be 1');
    return result;
  }
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
        probability = new Rational.fromInt(1),
        lastFeint = 0,
        lastForcefulBlow = 0,
        lastManeuver = Maneuver.normalAttack;

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
      @required this.lastFeint,
      @required this.lastForcefulBlow,
      @required this.lastManeuver,
      @required this.probability,
      @required this.remainingDepth});

  final Hero attacker, defender;
  final int attackerLostVp, defenderLostVp; // LeP
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final int lastFeint, lastForcefulBlow;
  final Maneuver lastManeuver;
  final Rational probability;
  final int remainingDepth;

  /// All choices that the [attacker]s [Strategy] considers, ordered by payoff
  /// descending, or an empty list if [remainingDepth] is 0.
  List<PlayerChoice> get choices => _choices ??=
      remainingDepth == 0 ? const [] : attacker.strategy.enumerateChoices(this);
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

  /// All [PlayerChoice.transitions] of all [choices].
  Iterable<HalfACombatRound> get successors =>
      choices.expand((choice) => choice.transitions.keys);

  /// The payoff is the difference between attacker and defender VP if this is a
  /// leaf, or the best payoff of all children if this is an internal node.
  Rational get payoff => _payoff ??= remainingDepth == 0
      ? new Rational.fromInt(attackerLostVp - defenderLostVp)
      : choices.first.payoff;
  Rational _payoff;

  @override
  String toString() => 'Round $remainingDepth (probability: $probability): '
      '${attacker.name} (lost vp=$attackerLostVp, wounds=$attackerWounds) '
      'attacks '
      '${defender.name} (lost vp=$defenderLostVp, wounds=$defenderWounds)';
}

/// A [Comparator] that sorts the [PlayerChoice] with the highest payoff on the
/// first position.
int _sortChoicesDescending(PlayerChoice a, PlayerChoice b) =>
    (b.payoff - a.payoff).signum;
