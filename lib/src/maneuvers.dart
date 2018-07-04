abstract class Maneuver {
  const Maneuver();

  static const Maneuver normalAttack = const NormalAttack();
  static const Maneuver preciseThrust = const PreciseThrust();
  static const Maneuver deadlyThrust = const DeadlyThrust();
  static const Maneuver hammerBlow = const HammerBlow();

  static const List<Maneuver> values = const [
    normalAttack,
    preciseThrust,
    deadlyThrust,
    hammerBlow
  ];

  int calculatePenalty(int defenderAr);

  int calculateDamage(int attackerHp, int attackRoll, int w, int defenderAr);

  int calculateWounds(int rawDmg, int defenderWt);
}

class NormalAttack extends Maneuver {
  const NormalAttack();

  @override
  int calculatePenalty(int defenderAr) => 0;

  @override
  int calculateDamage(int attackerHp, int attackRoll, int w, int defenderAr) =>
      attackerHp + attackRoll + w - defenderAr;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / defenderWt * 2).floor().clamp(0, 3);
}

class PreciseThrust extends Maneuver {
  const PreciseThrust();

  @override
  int calculatePenalty(int defenderAr) => 4 + (defenderAr / 2).round();

  @override
  int calculateDamage(int attackerHp, int attackRoll, int w, int defenderAr) =>
      attackerHp + attackRoll;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / (defenderWt - 2) * 2).floor().clamp(0, 3) + 1;
}

class DeadlyThrust extends Maneuver {
  const DeadlyThrust();

  @override
  int calculatePenalty(int defenderAr) => 8 + (defenderAr / 2).round();

  @override
  int calculateDamage(int attackerHp, int attackRoll, int w, int defenderAr) =>
      attackerHp + attackRoll + w;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / (defenderWt - 2) * 2).floor().clamp(0, 3) + 2;
}

class HammerBlow extends Maneuver {
  const HammerBlow();

  @override
  int calculatePenalty(int defenderAr) => 8;

  @override
  int calculateDamage(int attackerHp, int attackRoll, int w, int defenderAr) =>
      3 * (attackerHp + attackRoll + w) - defenderAr;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / defenderWt * 2).floor().clamp(0, 3);
}
