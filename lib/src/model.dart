class Hero {
  /// vitality: Le
  final int vi;

  /// armor rating: RS
  final int ar;

  /// hit points: TP
  final int hp;

  /// attack value: AT
  final int at;

  /// parry value: PA
  final int pa;

  Hero(this.vi, this.ar, this.hp, this.at, this.pa);
}

class HalfACombatRound {
  final Hero attacker, defender;
  final int attackerVp, defenderVp;
  final int attackerPenalty, defenderPenalty;
  final int attackerWounds, defenderWounds;

  Map<HalfACombatRound, double> get transitions =>
      _transitions ??= _computeTransitions();
  Map<HalfACombatRound, double> _transitions;

  HalfACombatRound(
      this.attacker,
      this.defender,
      this.attackerVp,
      this.defenderVp,
      this.attackerPenalty,
      this.defenderPenalty,
      this.attackerWounds,
      this.defenderWounds);

  Map<HalfACombatRound, double> _computeTransitions() {
    final result = <HalfACombatRound, double>{};

    return result;
  }
}
