import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:args/args.dart';
import 'package:isolate/isolate_runner.dart';
import 'package:rational/rational.dart';
import 'package:tde_sim/tde_sim.dart';
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
    heroes.add(new Hero(hero['name'], new ShortSightedStrategy(),
        wt: hero['wt'],
        ar: hero['ar'],
        hp: hero['hp'],
        at: hero['at'],
        pa: hero['pa']));
  }
  final tasks = new Queue.of(new HalfACombatRound(heroes[0], heroes[0], depth)
      .choices
      .map((choice) => new SimulationTask(choice, verbose)));
  final results = <MapEntry<PlayerChoice, Rational>>[];

  Future<void> runWorker([int workerNumber]) async {
    // Short explanation of how isolates communicate:
    // https://japhr.blogspot.com/2016/01/a-naming-convention-for-dart-isolate.html
    // Luckily for us, [IsolateRunner] wraps this functionality in an easier API.
    final runner = await IsolateRunner.spawn();
    while (tasks.isNotEmpty) {
      final task = tasks.removeFirst();
      results.add(
          new MapEntry(task.start, await runner.run(simulateCombat, task)));
    }
    runner.close();
  }

  await Future.wait(new List.generate(parallelism, runWorker));
  results.sort((a, b) {
    if (a.value < b.value) return -1;
    if (a.value > b.value) return 1;
    return 0;
  });

  watch.stop();
  print('total program runtime: ${watch.elapsed}');

  for (final result in results) {
    print('with payoff ${result.value.toDouble()}: ${result.key}');
  }
}

/// Explores all possible outcomes of this combat up to `task.depth`. Prints
/// the time it took to build up the state tree. Returns the best Payoff.
Rational simulateCombat(SimulationTask task) {
  final queue = new Queue.of([task.start]);

  final watch = new Stopwatch()..start();
  var visitedStates = 0;
  while (queue.isNotEmpty) {
    final choice = queue.removeFirst();
    visitedStates++;
    if (choice.turn.remainingDepth == 0) {
      if (task.verbose) print(choice);
    } else {
      queue.addAll(choice.transitions.keys.expand((round) => round.choices));
    }
  }
  watch.stop();
  print('Visited $visitedStates in ${watch.elapsedMilliseconds}ms');
  return task.start.payoff;
}

class SimulationTask {
  SimulationTask(this.start, this.verbose);

  final PlayerChoice start;
  final bool verbose;
}
