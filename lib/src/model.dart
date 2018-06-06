import 'package:rational/rational.dart';

class Hero {
  /// vitality: Le
  final int vi;

  ///wound threshold: WS
  final int wt;

  /// armor rating: RS
  final int ar;

  /// hit points: TP
  final int hp;

  /// attack value: AT
  final int at;

  /// parry value: PA
  final int pa;

  Hero(this.vi, this.wt, this.ar, this.hp, this.at, this.pa);
}

class HalfACombatRound {
  final Hero attacker, defender;
  final int attackerVp, defenderVp;
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;
  final int lastFeint, lastForcefulBlow, lastImprovedParry;
  final Rational probability;
  final int depth;

  Map<HalfACombatRound, Rational> get transitions =>
      _transitions ??= _computeTransitions();
  Map<HalfACombatRound, Rational> _transitions;

  HalfACombatRound(
      this.attacker,
      this.defender,
      this.attackerVp,
      this.defenderVp,
      this.attackerPenalty,
      this.defenderPenalty,
      this.attackerWounds,
      this.defenderWounds,
      this.lastFeint,
      this.lastForcefulBlow,
      this.lastImprovedParry,
      this.probability,
      this.depth);

  Map<HalfACombatRound, Rational> _computeTransitions() {
    final result = <HalfACombatRound, Rational>{};

    return result;
  }
}
