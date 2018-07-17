import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:quiver/core.dart';
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
      turn.attacker.at - turn.attackerWounds * 2 - attackPenalty;

  /// The expected payoff of a choice is the sum over all [transitions],
  /// weighted with their probability.
  Rational payoff(int depth) {
    assert(
        depth > 0,
        'if depth == 0 then HalfACombatTurn.payoff should '
        'have calculated the payoff itself');

    if (_payoff.length < depth) {
      _payoff.length = depth;
    }
    return _payoff[depth - 1] = transitions.entries
        .map(
            (transition) => transition.key.payoff(depth - 1) * transition.value)
        .reduce((a, b) => a + b);
  }

  final List<Rational> _payoff = [];

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
        {int damage: 0, int wounds: 0, int attackerPenalty: 0}) {
      final state = new HalfACombatRound._(
          attacker: defender,
          defender: attacker,
          attackerLostVp: turn.defenderLostVp - damage,
          defenderLostVp: turn.attackerLostVp,
          defenderPenalty: attackerPenalty,
          attackerWounds: turn.defenderWounds + wounds,
          defenderWounds: turn.attackerWounds,
          defenderCanBlock: !maneuver.consumesDefensiveAction,
          discovered: turn.discovered);
      final duplicate = turn.discovered.lookup(state);
      if (duplicate != null) {
        result[duplicate] = successorProbability;
      } else {
        turn.discovered.add(state);
        result[state] = successorProbability;
      }
    }

    final attackSuccess =
        new Rational.fromInt(requiredSuccessRoll.clamp(1, 19), 20);

    // attack failed
    addSuccessor(_one - attackSuccess, attackerPenalty: attackPenalty);

    var parrySuccess = new Rational.fromInt(0);
    if (turn.defenderCanBlock) {
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
  HalfACombatRound(this.attacker, this.defender)
      : attackerLostVp = 0,
        defenderLostVp = 0,
        defenderPenalty = 0,
        attackerWounds = 0,
        defenderWounds = 0,
        defenderCanBlock = true,
        discovered = new LinkedHashSet(equals: _equivalent, hashCode: _hash);

  /// Internal constructor for succeeding combat rounds.
  HalfACombatRound._(
      {@required this.attacker,
      @required this.defender,
      @required this.attackerLostVp,
      @required this.defenderLostVp,
      @required this.defenderPenalty,
      @required this.attackerWounds,
      @required this.defenderWounds,
      @required this.defenderCanBlock,
      @required this.discovered});

  final Hero attacker, defender;
  final int attackerLostVp, defenderLostVp; // LeP
  final int defenderPenalty;
  final int attackerWounds, defenderWounds;
  final bool defenderCanBlock;

  /// All [HalfACombatRound]s in this graph. Multiple paths lead to the same
  /// outcome; this set is used to detect if an already known state is
  /// discovered again, and that object is reused.
  final Set<HalfACombatRound> discovered;

  bool get attackerWon =>
      defenderLostVp >= defender.vi || defenderWounds >= defender.at ~/ 2;

  bool get defenderWon =>
      attackerLostVp >= attacker.vi || attackerWounds >= attacker.at ~/ 2;

  /// All choices that the [attacker]s [Strategy] considers.
  List<PlayerChoice> get choices =>
      _choices ??= attacker.strategy.enumerateChoices(this);
  List<PlayerChoice> _choices;

  /// All [PlayerChoice.transitions] of all [choices].
  Iterable<HalfACombatRound> get successors =>
      choices.expand((choice) => choice.transitions.keys);

  /// Returns the payoff of this state, if it is explored to a depth of [depth].
  /// The payoff is the difference between attacker and defender VP if this is a
  /// leaf, or the best payoff of all children if this is an internal node.
  Rational payoff(int depth) {
    if (attackerWon) {
      return new Rational.fromInt(defender.vi);
    } else if (defenderWon) {
      return new Rational.fromInt(-attacker.vi);
    } else if (depth == 0) {
      return new Rational.fromInt(attackerLostVp - defenderLostVp);
    } else {
      return bestChoice(depth).payoff(depth);
    }
  }

  /// Returns the best choice if the combat is fully explored up to [depth]
  /// additional turns.
  PlayerChoice bestChoice(int depth) {
    assert(
        depth > 0,
        'if depth == 0 then HalfACombatTurn.payoff should '
        'have calculated the payoff itself');

    if (_bestChoice.length < depth) {
      _bestChoice.length = depth;
    }
    return _bestChoice[depth - 1] ??=
        choices.reduce((a, b) => a.payoff(depth) > b.payoff(depth) ? a : b);
  }

  final List<PlayerChoice> _bestChoice = [];

  @override
  String toString() =>
      '${attacker.name} (lost vp=$attackerLostVp, wounds=$attackerWounds) '
      'attacks '
      '${defender.name} (lost vp=$defenderLostVp, wounds=$defenderWounds)';
}

bool _equivalent(HalfACombatRound a, HalfACombatRound b) =>
    a.attackerLostVp == b.attackerLostVp &&
    a.defenderLostVp == b.defenderLostVp &&
    a.defenderPenalty == b.defenderPenalty &&
    a.attackerWounds == b.attackerWounds &&
    a.defenderWounds == b.defenderWounds &&
    a.defenderCanBlock == b.defenderCanBlock;

int _hash(HalfACombatRound r) => hashObjects([
      r.attackerLostVp,
      r.defenderLostVp,
      r.defenderPenalty,
      r.attackerWounds,
      r.defenderWounds,
      r.defenderCanBlock
    ]);
