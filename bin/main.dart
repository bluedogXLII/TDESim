import 'dart:io';

import 'package:args/args.dart';
import 'package:tde_sim/tde_sim.dart';
import 'package:yaml/yaml.dart';

final argParser = new ArgParser()..addOption('depth', abbr: 'd');

void main(List<String> rawArgs) async {
  final watch = new Stopwatch()..start();

  final args = argParser.parse(rawArgs);
  final configFile = args.rest.length == 1 ? args.rest.single : null;
  final depth = args['depth'] != null ? int.tryParse(args['depth']) : null;
  if (configFile == null || depth == null || depth < 1) {
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
    heroes.add(new Hero(hero['name'], new AllAttacks(),
        wt: hero['wt'],
        ar: hero['ar'],
        hp: hero['hp'],
        at: hero['at'],
        pa: hero['pa']));
  }

  final combat = new CombatTurn(heroes[0], heroes[0]);
  var iterationStart = watch.elapsed;
  var alreadyDiscovered = 0;
  var oldDuplicates = 0;
  for (var i = 1; i <= depth; i++) {
    print(
        'Payoff of the root node for depth $i: ${combat.payoff(i).toDouble()}');
    print('Calcuating ${combat.discovered.length - alreadyDiscovered} '
        'new states required '
        '${(watch.elapsed - iterationStart).inMilliseconds}ms');
    print('skipped ${duplicates - oldDuplicates} duplicates');
    alreadyDiscovered = combat.discovered.length;
    iterationStart = watch.elapsed;
    oldDuplicates = duplicates;
  }

  watch.stop();
  print('total program runtime: ${watch.elapsed}');
}
