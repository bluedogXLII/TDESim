import 'dart:collection';
import 'package:tde_sim/src/model.dart';

/// Evaluate **all** states up until this depth.
const int depth = 7;

void main() {
  final player1 =
      new Hero('Kazan', vi: 28, wt: 7, ar: 0, hp: 3, at: 12, pa: 12);
  final player2 =
      new Hero('Nazak', vi: 28, wt: 7, ar: 0, hp: 3, at: 12, pa: 12);
  final queue = new Queue.of([new HalfACombatRound(player1, player2)]);

  final watch = new Stopwatch()..start();
  var visitedStates = 0;
  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    //print(state);
    visitedStates++;
    if (state.depth == depth) {
      print(state);
    } else {
      queue.addAll(state.transitions.keys);
    }
  }
  watch.stop();
  print('Visited $visitedStates in ${watch.elapsedMilliseconds}ms');
}
