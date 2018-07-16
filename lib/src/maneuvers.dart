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

  bool get consumesDefensiveAction;
  bool get allowsForcefulBlow;

  int calculatePenalty(int defenderAr);

  int calculateDamage(
      int attackerHp, int attackRoll, int forcefulBlow, int defenderAr);

  int calculateWounds(int rawDmg, int defenderWt);
}

class NormalAttack extends Maneuver {
  const NormalAttack();

  @override
  bool get consumesDefensiveAction => false;

  @override
  bool get allowsForcefulBlow => true;

  @override
  int calculatePenalty(int defenderAr) => 0;

  @override
  int calculateDamage(
          int attackerHp, int attackRoll, int forcefulBlow, int defenderAr) =>
      attackerHp + attackRoll + forcefulBlow - defenderAr;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / defenderWt * 2).floor().clamp(0, 3);
}

class PreciseThrust extends Maneuver {
  const PreciseThrust();

  @override
  bool get consumesDefensiveAction => false;

  @override
  bool get allowsForcefulBlow => false;

  @override
  int calculatePenalty(int defenderAr) => 4 + (defenderAr / 2).round();

  @override
  int calculateDamage(
          int attackerHp, int attackRoll, int forcefulBlow, int defenderAr) =>
      attackerHp + attackRoll;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / (defenderWt - 2) * 2).floor().clamp(0, 3) + 1;
}

class DeadlyThrust extends Maneuver {
  const DeadlyThrust();

  @override
  bool get consumesDefensiveAction => true;

  @override
  bool get allowsForcefulBlow => true;

  @override
  int calculatePenalty(int defenderAr) => 8 + (defenderAr / 2).round();

  @override
  int calculateDamage(
          int attackerHp, int attackRoll, int forcefulBlow, int defenderAr) =>
      attackerHp + attackRoll + forcefulBlow;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / (defenderWt - 2) * 2).floor().clamp(0, 3) + 2;
}

class HammerBlow extends Maneuver {
  const HammerBlow();

  @override
  bool get consumesDefensiveAction => true;

  @override
  bool get allowsForcefulBlow => true;

  @override
  int calculatePenalty(int defenderAr) => 8;

  @override
  int calculateDamage(
          int attackerHp, int attackRoll, int forcefulBlow, int defenderAr) =>
      3 * (attackerHp + attackRoll + forcefulBlow) - defenderAr;

  @override
  int calculateWounds(int rawDmg, int defenderWt) =>
      (rawDmg / defenderWt * 2).floor().clamp(0, 3);
}
