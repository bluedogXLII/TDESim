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
      //print(state); //the printing takes too much time
    } else {
      queue.addAll(state.transitions.keys);
    }
  }
  watch.stop();
  print('Visited $visitedStates in ${watch.elapsedMilliseconds}ms');
}
//tested 9.6. on i7-4790, 3,6GHz;
//depth 5: 135/ms   145ms
//depth 6: 179/ms   765ms
//depth 7: 180/ms  5326ms
//depth 8: 151/ms 44533ms
