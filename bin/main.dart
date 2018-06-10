import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:args/args.dart';
import 'package:isolate/isolate_runner.dart';
import 'package:tde_sim/src/model.dart';
import 'package:trotter/trotter.dart';
import 'package:yaml/yaml.dart';

final argParser = new ArgParser()
  ..addOption('depth', abbr: 'd')
  ..addOption('parallelism', abbr: 'p', defaultsTo: '1')
  ..addFlag('verbose', abbr: 'v');

void main(List<String> rawArgs) async {
  final watch = new Stopwatch()..start();

  final args = argParser.parse(rawArgs);
  final configFile = args.rest.length == 1 ? args.rest.single : null;
  final depth = args['depth'] != null ? int.tryParse(args['depth']) : null;
  final parallelism =
      args['parallelism'] != null ? int.tryParse(args['parallelism']) : null;
  final verbose = args['verbose'] as bool;
  if (configFile == null ||
      depth == null ||
      depth < 1 ||
      parallelism == null ||
      parallelism < 1 ||
      verbose == null) {
    print('usage: dart main.dart [options] <config.yaml>');
    print('options:');
    print(argParser.usage);
    return;
  }

  dynamic config;
  try {
    config = loadYaml(new File(configFile).readAsStringSync(),
        sourceUrl: configFile);
  } on FileSystemException catch (e) {
    print('error while reading the config file: $e');
    return;
  }

  final heroes = <Hero>[];
  for (final hero in config['heroes']) {
    assert(hero is Map<String, dynamic>);
    heroes.add(new Hero(hero['name'],
        vi: hero['vi'],
        wt: hero['wt'],
        ar: hero['ar'],
        hp: hero['hp'],
        at: hero['at'],
        pa: hero['pa']));
  }
  final tasks = new Queue.of(new Combinations(2, heroes).iterable.map(
      (combination) =>
          new SimulationTask(combination[0], combination[1], depth, verbose)));
  final results = <Duration>[];

  Future<void> runWorker([int workerNumber]) async {
    // Short explanation of how isolates communicate:
    // https://japhr.blogspot.com/2016/01/a-naming-convention-for-dart-isolate.html
    // Luckily for us, [IsolateRunner] wraps this functionality in an easier API.
    final runner = await IsolateRunner.spawn();
    while (tasks.isNotEmpty) {
      results.add(await runner.run(simulateCombat, tasks.removeFirst()));
    }
    runner.close();
  }

  await Future.wait(new List.generate(parallelism, runWorker));
  watch.stop();
  print('individual durations: $results, '
      'total: ${results.reduce((a, b) => a + b)}');
  print('total program runtime: ${watch.elapsed}');
}

/// Explores all possible outcomes of this combat up to `task.depth`. Returns
/// the time it took to build up the state tree.
Duration simulateCombat(SimulationTask task) {
  final queue = new Queue.of(
      [new HalfACombatRound(task.initialAttacker, task.initialDefender)]);

  final watch = new Stopwatch()..start();
  var visitedStates = 0;
  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    visitedStates++;
    if (state.depth == task.depth) {
      if (task.verbose) print(state);
    } else {
      queue.addAll(state.transitions.keys);
    }
  }
  watch.stop();
  print('Visited $visitedStates in ${watch.elapsedMilliseconds}ms');
  return watch.elapsed;
}

class SimulationTask {
  SimulationTask(
      this.initialAttacker, this.initialDefender, this.depth, this.verbose);

  final Hero initialAttacker;
  final Hero initialDefender;
  final int depth;
  final bool verbose;
}
//tested 9.6. on i7-4790, 3,6GHz;
//depth 5: 135/ms   145ms
//depth 6: 179/ms   765ms
//depth 7: 180/ms  5326ms
//depth 8: 151/ms 44533ms
