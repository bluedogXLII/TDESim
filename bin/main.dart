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
    heroes.add(new Hero(
        hero['name'],
        const TotalStrategy(
            const [Maneuver.normalAttack, Maneuver.preciseThrust]),
        vi: hero['vi'],
        wt: hero['wt'],
        ar: hero['ar'],
        hp: hero['hp'],
        at: hero['at'],
        pa: hero['pa']));
  }
  final tasks = new Queue.of(new HalfACombatRound(heroes[0], heroes[0])
      .successors
      .map((combatRound) => new SimulationTask(combatRound, depth, verbose)));
  final results = <MapEntry<HalfACombatRound, Rational>>[];

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

  // Delete this reference because it is no longer needed and would only
  // increase the data that has to be sent. This is a hack.
  tasks.first.start.discovered.clear();

  await Future.wait(new List.generate(parallelism, runWorker));
  results.sort((a, b) {
    if (a.value < b.value) return -1;
    if (a.value > b.value) return 1;
    return 0;
  });

  watch.stop();
  print('total program runtime: ${watch.elapsed}');

  for (final result in results.reversed) {
    print('with payoff ${result.value.toDouble()}: ${result.key}');
  }
}

/// Explores all possible outcomes of this combat up to `task.depth`. Returns
/// the time it took to build up the state tree.
Rational simulateCombat(SimulationTask task) {
  final watch = new Stopwatch()..start();
  final payoff = task.start.payoff(task.depth);
  watch.stop();
  print('Visited ${task.start.discovered.length} '
      'in ${watch.elapsedMilliseconds}ms');
  return payoff;
}

class SimulationTask {
  SimulationTask(this.start, this.depth, this.verbose);

  final HalfACombatRound start;
  final int depth;
  final bool verbose;
}
