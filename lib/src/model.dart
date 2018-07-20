import 'package:meta/meta.dart';
import 'package:quiver/core.dart';
import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'strategies.dart';

final Rational _zero = new Rational.fromInt(0);
final Rational _one = new Rational.fromInt(1);
final Rational _oneSixth = new Rational.fromInt(1, 6);

/// Global variables are ugly, but this one is just used to get a better
/// understanding of the performance implications of
/// [CombatTurn.discovered]. We should delete it soon.
var duplicates = 0;

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

  @override
  String toString() =>
      '$name: ( WT: $wt, AR: $ar, HP: $hp, AT: $at, PA: $pa, strategy: $strategySpace )';
}

class PlayerChoice {
  PlayerChoice(this.turn, this.maneuver, this.forcefulBlow, this.feint);

  final CombatTurn turn;
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
  Rational payoff(int depth) {
    assert(
        depth > 0,
        'if depth == 0 then HalfACombatTurn.payoff should '
        'have calculated the payoff itself');

    if (_payoff.length < depth) {
      _payoff.length = depth;
    }
    return _payoff[depth - 1] ??= transitions.entries
        .map((transition) =>
            -transition.key.payoff(depth - 1) * transition.value)
        .reduce((a, b) => a + b);
  }

  /// Cached payoff values for each depth; the payoff for depth 1 is stored at
  /// index 0.
  final List<Rational> _payoff = [];

  /// All succeeding combat rounds that have a non-zero chance of happening.
  /// The values of this map are the probabilities of this transition being
  /// taken, in the range (0, 1].
  Map<CombatTurn, Rational> get transitions =>
      _transitions ??= _calculateTransitions();
  Map<CombatTurn, Rational> _transitions;

  Map<CombatTurn, Rational> _calculateTransitions() {
    final attacker = turn.attacker;
    final defender = turn.defender;
    final result = <CombatTurn, Rational>{};

    /// [attackerPenalty] is for the attacker in **this** turn, not the next!
    void addSuccessor(Rational successorProbability,
        {@required int damage,
        @required int wounds,
        @required int attackerPenalty,
        @required int defenderPenalty}) {
      var state = new CombatTurn._(
          attacker: defender,
          defender: attacker,
          attackerLostVp: turn.defenderLostVp + damage,
          defenderLostVp: turn.attackerLostVp,
          attackerPenalty: defenderPenalty,
          defenderPenalty: attackerPenalty,
          attackerWounds: turn.defenderWounds + wounds,
          defenderWounds: turn.attackerWounds,
          allowParry: !maneuver.consumesDefensiveAction,
          discovered: turn.discovered);
      final duplicate = turn.discovered.lookup(state);
      if (duplicate != null) {
        state = duplicate;
        duplicates++;
      } else {
        turn.discovered.add(state);
      }

      result[state] ??= _zero;
      result[state] += successorProbability;
    }

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

class CombatTurn {
  /// Creates a new combat round for a new combat.
  CombatTurn(this.attacker, this.defender)
      : attackerLostVp = 0,
        defenderLostVp = 0,
        attackerPenalty = 0,
        defenderPenalty = 0,
        attackerWounds = 0,
        defenderWounds = 0,
        allowParry = true,
        discovered = new Set() {
    discovered.add(this);
  }

  /// Internal constructor for succeeding combat rounds.
  CombatTurn._(
      {@required this.attacker,
      @required this.defender,
      @required this.attackerLostVp,
      @required this.defenderLostVp,
      @required this.attackerPenalty,
      @required this.defenderPenalty,
      @required this.attackerWounds,
      @required this.defenderWounds,
      @required this.allowParry,
      @required this.discovered});

  final Hero attacker, defender;
  final int attackerLostVp, defenderLostVp; // LeP
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final bool allowParry;
  final Set<CombatTurn> discovered;

  /// All choices that the [attacker]s [StrategySpace] considers, unordered.
  List<PlayerChoice> get choices =>
      _choices ??= attacker.strategySpace.enumerateChoices(this);
  List<PlayerChoice> _choices;

  /// Returns the best choice if the combat is fully explored up to [depth]
  /// additional turns.
  PlayerChoice bestChoice(int depth) {
    assert(
        depth > 0,
        'if depth == 0 then CombatTurn.payoff should '
        'have calculated the payoff itself');

    if (_bestChoice.length < depth) {
      _bestChoice.length = depth;
    }
    return _bestChoice[depth - 1] ??=
        choices.reduce((a, b) => a.payoff(depth) > b.payoff(depth) ? a : b);
  }

  final List<PlayerChoice> _bestChoice = [];

  /// Returns the worst choice if the combat is fully explored up to [depth]
  /// additional turns.
  PlayerChoice worstChoice(int depth) {
    assert(
        depth > 0,
        'if depth == 0 then CombatTurn.payoff should '
        'have calculated the payoff itself');

    if (_worstChoice.length < depth) {
      _worstChoice.length = depth;
    }
    return _worstChoice[depth - 1] ??=
        choices.reduce((a, b) => a.payoff(depth) < b.payoff(depth) ? a : b);
  }

  final List<PlayerChoice> _worstChoice = [];

  /// The payoff is the difference between attacker and defender VP if this is a
  /// leaf, or the best payoff of all children if this is an internal node.
  /// A positive Payoff benefits the attacker of the current round.
  Rational payoff(int depth) {
    if (depth == 0) {
      return new Rational.fromInt(defenderLostVp - attackerLostVp);
    } else {
      return bestChoice(depth).payoff(depth);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CombatTurn &&
      attacker == other.attacker &&
      defender == other.defender &&
      attackerLostVp == other.attackerLostVp &&
      defenderLostVp == other.defenderLostVp &&
      defenderPenalty == other.defenderPenalty &&
      attackerWounds == other.attackerWounds &&
      defenderWounds == other.defenderWounds &&
      allowParry == other.allowParry;

  @override
  int get hashCode => hashObjects([
        attacker,
        defender,
        attackerLostVp,
        defenderLostVp,
        defenderPenalty,
        attackerWounds,
        defenderWounds,
        allowParry
      ]);

  @override
  String toString() =>
      '${attacker.name} (lost vp=$attackerLostVp, wounds=$attackerWounds) '
      'attacks '
      '${defender.name} (lost vp=$defenderLostVp, wounds=$defenderWounds)';
}
