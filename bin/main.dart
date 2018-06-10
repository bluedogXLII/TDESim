import 'dart:collection';
import 'dart:io';
import 'package:args/args.dart';
import 'package:tde_sim/src/model.dart';
import 'package:trotter/trotter.dart';
import 'package:yaml/yaml.dart';

final argParser = new ArgParser()
  ..addOption('depth', abbr: 'd')
  ..addFlag('verbose', abbr: 'v');

void main(List<String> rawArgs) {
  final args = argParser.parse(rawArgs);
  final configFile = args.rest.length == 1 ? args.rest.single : null;
  final depth = args['depth'] != null ? int.tryParse(args['depth']) : null;
  final verbose = args['verbose'] as bool;
  if (configFile == null || depth == null || depth < 1 || verbose == null) {
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

  for (final combination in new Combinations(2, heroes).iterable) {
    simulateCombat(combination[0], combination[1], depth, verbose);
  }
}

void simulateCombat(Hero player1, Hero player2, int depth, bool verbose) {
  final queue = new Queue.of([new HalfACombatRound(player1, player2)]);

  final watch = new Stopwatch()..start();
  var visitedStates = 0;
  while (queue.isNotEmpty) {
    final state = queue.removeFirst();
    visitedStates++;
    if (state.depth == depth) {
      if (verbose) print(state);
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
