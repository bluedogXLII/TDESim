import 'package:meta/meta.dart';
import 'package:rational/rational.dart';

import 'maneuvers.dart';
import 'strategies.dart';

final allowImprovedParry = true;

final Rational _one = new Rational.fromInt(1);
final Rational _oneSixth = new Rational.fromInt(1, 6);

class Hero {
  final String name;

  /// vitality (Le): The starting vitality points.
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
  PlayerChoice(this.maneuver, this.feint, this.forcefulBlow);

  final Maneuver maneuver;
  final int feint;
  final int forcefulBlow;

  Map<HalfACombatRound, Rational> transitions;
}

class HalfACombatRound {
  final Hero attacker, defender;
  final int attackerVp, defenderVp; // LeP
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final int lastFeint, lastForcefulBlow, lastImprovedParry;
  final Maneuver lastManeuver;
  final Rational probability;
  final int remainingDepth;

  /// All succeeding combat rounds that have a non-zero chance of happening.
  /// The values of this map are the probabilities of this transition being
  /// taken, in the range [0, 1].
  Map<HalfACombatRound, Rational> get transitions =>
      _transitions ??= _computeTransitions();
  Map<HalfACombatRound, Rational> _transitions;

  Rational get payoff => _payoff ??= remainingDepth == 0
      ? new Rational.fromInt(
          (attacker.vi - attackerVp) - (defender.vi - defenderVp))
      : bestTransition.payoff * transitions[bestTransition];
  Rational _payoff;

  HalfACombatRound get bestTransition => _bestTransition ??= remainingDepth == 0
      ? throw new StateError(
          "Can't get the best transition of a state whose transitions "
          "shouldn't be generated (because remainingDepth == 0)")
      : transitions.entries
          .reduce(
              (a, b) => a.key.payoff * a.value > b.key.payoff * b.value ? a : b)
          .key;
  HalfACombatRound _bestTransition;

  /// Creates a new combat round for a new combat.
  HalfACombatRound(this.attacker, this.defender, this.remainingDepth)
      : attackerVp = attacker.vi,
        defenderVp = defender.vi,
        attackerPenalty = 0,
        defenderPenalty = 0,
        attackerWounds = 0,
        defenderWounds = 0,
        probability = new Rational.fromInt(1),
        lastFeint = 0,
        lastForcefulBlow = 0,
        lastImprovedParry = 0,
        lastManeuver = Maneuver.normalAttack;

  /// Internal constructor for succeeding combat rounds.
  HalfACombatRound._(
      {@required this.attacker,
      @required this.defender,
      @required this.attackerVp,
      @required this.defenderVp,
      @required this.attackerPenalty,
      @required this.defenderPenalty,
      @required this.attackerWounds,
      @required this.defenderWounds,
      @required this.lastFeint,
      @required this.lastForcefulBlow,
      @required this.lastImprovedParry,
      @required this.lastManeuver,
      @required this.probability,
      @required this.remainingDepth});

  Map<HalfACombatRound, Rational> _computeTransitions() {
    final result = <HalfACombatRound, Rational>{};

    void addSuccessor(
            {@required int attackerVp,
            @required int defenderVp,
            @required int attackerPenalty,
            @required int defenderPenalty,
            @required int attackerWounds,
            @required int defenderWounds,
            @required int lastFeint,
            @required int lastForcefulBlow,
            @required int lastImprovedParry,
            @required Maneuver lastManeuver,
            @required Rational successorProbability}) =>
        result[new HalfACombatRound._(
            attacker: defender,
            defender: attacker,
            attackerVp: attackerVp,
            defenderVp: defenderVp,
            attackerPenalty: attackerPenalty,
            defenderPenalty: defenderPenalty,
            attackerWounds: attackerWounds,
            defenderWounds: defenderWounds,
            lastFeint: lastFeint,
            lastForcefulBlow: lastForcefulBlow,
            lastImprovedParry: lastImprovedParry,
            lastManeuver: lastManeuver,
            probability: probability * successorProbability,
            remainingDepth: remainingDepth - 1)] = successorProbability;

    //elaborate simulation
    for (final choice in attacker.strategy.enumerateChoices(this)) {
      final attackPenalty = choice.feint +
          choice.forcefulBlow +
          choice.maneuver.calculatePenalty(defender.ar);

      final attackSuccess = new Rational.fromInt(
          (attacker.at - attackerPenalty - attackPenalty - 2 * attackerWounds)
              .clamp(1, 19),
          20);

      // attack failed
      addSuccessor(
          attackerVp: defenderVp,
          defenderVp: attackerVp,
          attackerPenalty: defenderPenalty,
          defenderPenalty: attackPenalty,
          attackerWounds: defenderWounds,
          defenderWounds: attackerWounds,
          lastFeint: choice.feint,
          lastForcefulBlow: choice.forcefulBlow,
          lastImprovedParry: 0,
          lastManeuver: choice.maneuver,
          successorProbability: _one - attackSuccess);

      if (lastManeuver.consumesDefensiveAction) {
        // no parry
        var noDamageCount = 0;
        for (var die = 1; die <= 6; die++) {
          final s = choice.maneuver.calculateDamage(
              attacker.hp, die, choice.forcefulBlow, defender.ar);
          final wounds = choice.maneuver.calculateWounds(s, defender.wt);
          if (s <= 0)
            noDamageCount++;
          else
            addSuccessor(
                attackerVp: defenderVp - s,
                defenderVp: attackerVp,
                attackerPenalty: defenderPenalty,
                defenderPenalty: 0,
                attackerWounds: defenderWounds + wounds,
                defenderWounds: attackerWounds,
                lastFeint: choice.feint,
                lastForcefulBlow: choice.forcefulBlow,
                lastImprovedParry: 0,
                lastManeuver: choice.maneuver,
                successorProbability: attackSuccess * _oneSixth);
        }
        // no damage inflicted
        if (noDamageCount > 0)
          addSuccessor(
              attackerVp: defenderVp,
              defenderVp: attackerVp,
              attackerPenalty: defenderPenalty,
              defenderPenalty: 0,
              attackerWounds: defenderWounds,
              defenderWounds: attackerWounds,
              lastFeint: choice.feint,
              lastForcefulBlow: choice.forcefulBlow,
              lastImprovedParry: 0,
              lastManeuver: choice.maneuver,
              successorProbability:
                  attackSuccess * (new Rational.fromInt(noDamageCount, 6)));
      } else {
        for (var m = 0; m < defender.pa; m++) {
          final parrySuccess = new Rational.fromInt(
              (defender.pa -
                      m -
                      choice.feint -
                      defenderPenalty -
                      2 * defenderWounds)
                  .clamp(1, 19),
              20);

          // parry succeeded
          addSuccessor(
              attackerVp: defenderVp,
              defenderVp: attackerVp,
              attackerPenalty: 0,
              defenderPenalty: m,
              attackerWounds: defenderWounds,
              defenderWounds: attackerWounds,
              lastFeint: choice.feint,
              lastForcefulBlow: choice.forcefulBlow,
              lastImprovedParry: m,
              lastManeuver: choice.maneuver,
              successorProbability: attackSuccess * parrySuccess);

          // parry failed
          var noDamageCount = 0;
          for (var die = 1; die <= 6; die++) {
            final s = choice.maneuver.calculateDamage(
                attacker.hp, die, choice.forcefulBlow, defender.ar);
            final wounds = choice.maneuver.calculateWounds(s, defender.wt);
            if (s <= 0)
              noDamageCount++;
            else
              addSuccessor(
                  attackerVp: defenderVp - s,
                  defenderVp: attackerVp,
                  attackerPenalty: m,
                  defenderPenalty: 0,
                  attackerWounds: defenderWounds + wounds,
                  defenderWounds: attackerWounds,
                  lastFeint: choice.feint,
                  lastForcefulBlow: choice.forcefulBlow,
                  lastImprovedParry: m,
                  lastManeuver: choice.maneuver,
                  successorProbability:
                      (_one - parrySuccess) * attackSuccess * _oneSixth);
          }
          // no damage inflicted
          if (noDamageCount > 0)
            addSuccessor(
                attackerVp: defenderVp,
                defenderVp: attackerVp,
                attackerPenalty: m,
                defenderPenalty: 0,
                attackerWounds: defenderWounds,
                defenderWounds: attackerWounds,
                lastFeint: choice.feint,
                lastForcefulBlow: choice.forcefulBlow,
                lastImprovedParry: m,
                lastManeuver: choice.maneuver,
                successorProbability: (_one - parrySuccess) *
                    attackSuccess *
                    (new Rational.fromInt(noDamageCount, 6)));
          if (!allowImprovedParry) break;
        }
      }
      //if (maneuver == Maneuver.preciseThrust) break;
    }

    // angriff: +0+w+f
    // gezielter stich: +4+r/2+f RSignoriert, +1wunde, WS-2
    // todesstoß: +8+r/2+w+f, RSignoriert, +2wunden, WS-2, keine abwehr
    // hammerschlag: +8+w+f, (TP+w)*3, keine abwehr

    return result;
  }

  @override
  String toString() => 'Round $remainingDepth (probability: $probability): '
      '${attacker.name} (vp=$attackerVp, wounds=$attackerWounds) attacks '
      '${defender.name} (vp=$defenderVp, wounds=$defenderWounds)';
}
