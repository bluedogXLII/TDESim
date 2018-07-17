import 'package:tde_sim/tde_sim.dart';

void main() {
  final h = new Hero('Kazan',
      const TotalStrategy([Maneuver.normalAttack, Maneuver.preciseThrust]),
      vi: 28, wt: 7, ar: 0, hp: 3, at: 12, pa: 12);
  final combat = new HalfACombatRound(h, h);
  final watch = new Stopwatch()..start();
  var previouslyDiscovered = 0;

  for (var i = 0; i < 8; i++) {
    print('payoff for depth $i: ${combat.payoff(i).toDouble()}');
    print('Discovered ${combat.discovered.length - previouslyDiscovered} '
        'new states in ${watch.elapsedMilliseconds}ms');
    previouslyDiscovered = combat.discovered.length;
  }
}
