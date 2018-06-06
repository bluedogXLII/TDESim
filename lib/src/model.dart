import 'dart:math';
import 'package:rational/rational.dart';
import 'package:meta/meta.dart';

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

  Hero(this.name,
      {@required this.vi,
      @required this.wt,
      @required this.ar,
      @required this.hp,
      @required this.at,
      @required this.pa});
}

class HalfACombatRound {
  final Hero attacker, defender;
  final int attackerVp, defenderVp;
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final int lastFeint, lastForcefulBlow, lastImprovedParry;
  final Rational probability;
  final int depth;

  /// All succeeding combat rounds that have a non-zero chance of happening.
  /// The values of this map are the chances of this transition being taken, in
  /// the range [0, 1].
  Map<HalfACombatRound, Rational> get transitions =>
      _transitions ??= _computeTransitions();
  Map<HalfACombatRound, Rational> _transitions;

  /// Creates a new combat round for a new combat.
  HalfACombatRound(this.attacker, this.defender)
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
        depth = 0;

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
      @required this.probability,
      @required this.depth});

  Map<HalfACombatRound, Rational> _computeTransitions() {
    final result = <HalfACombatRound, Rational>{};

    final attackSuccessProbability = new Rational.fromInt(attacker.at, 20);
    final parryFailureProbability = new Rational.fromInt(20 - defender.pa, 20);
    final hitChance = attackSuccessProbability * parryFailureProbability;
    result[new HalfACombatRound._(
        attacker: defender,
        defender: attacker,
        attackerVp: defenderVp,
        defenderVp: attackerVp,
        attackerPenalty: defenderPenalty,
        defenderPenalty: attackerPenalty,
        attackerWounds: defenderWounds,
        defenderWounds: attackerWounds,
        lastFeint: 0,
        lastForcefulBlow: 0,
        lastImprovedParry: 0,
        probability: probability * _one - hitChance,
        depth: depth + 1)] = _one - hitChance;

    for (var dmg = 1; dmg <= 6; dmg++) {
      result[new HalfACombatRound._(
          attacker: defender,
          defender: attacker,
          attackerVp: max(defenderVp - (dmg - defender.ar + attacker.hp), 0),
          defenderVp: attackerVp,
          attackerPenalty: defenderPenalty,
          defenderPenalty: attackerPenalty,
          attackerWounds: defenderWounds,
          defenderWounds: attackerWounds,
          lastFeint: 0,
          lastForcefulBlow: 0,
          lastImprovedParry: 0,
          probability: probability * hitChance * _oneSixth,
          depth: depth + 1)] = hitChance * _oneSixth;
    }

    return result;
  }

  @override
  String toString() => 'Round $depth (probability: $probability): '
      '${attacker.name} (vp=$attackerVp, wounds=$attackerWounds) attacks '
      '${defender.name} (vp=$defenderVp, wounds=$defenderWounds)';
}
