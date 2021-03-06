import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:tde_sim/tde_sim.dart';
import 'package:yaml/yaml.dart';

final argParser = new ArgParser()..addOption('depth', abbr: 'd');

final verbose = false;

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

  final h1 = config['heroes'][1];
  final h2 = config['heroes'][1];

  final hero1 = new Hero(h1['name'], new AllAttacks(),
      wt: h1['wt'], ar: h1['ar'], hp: h1['hp'], at: h1['at'], pa: h1['pa']);
  final hero2 = new Hero(h2['name'], new AllAttacks(),
      wt: h2['wt'], ar: h2['ar'], hp: h2['hp'], at: h2['at'], pa: h2['pa']);

  final combat = new CombatTurn(hero1, hero2);
  var iterationStart = watch.elapsed;
  var alreadyDiscovered = 0;
  var oldDuplicates = 0;

  print('attacker: ${combat.attacker}');
  print('defender: ${combat.defender}');

  for (var i = 1; i <= depth; i++) {
    final bestPayoff = combat.bestChoice(i).payoff(i).toDouble();
    final absMaxPayoff =
        max(bestPayoff.abs(), combat.worstChoice(i).payoff(i).toDouble().abs());
    print('========================================');
    print('========================================');
    print(
        'Payoff of the root node for depth $i: $bestPayoff for ${combat.bestChoice(i)}');
    if (verbose) {
      print('Calcuating ${combat.discovered.length - alreadyDiscovered} '
          'new states required '
          '${(watch.elapsed - iterationStart).inMilliseconds}ms');
      print('skipped ${duplicates - oldDuplicates} duplicates');
      print('----------------------------------------');
      for (var choice in combat.choices) {
        final currentPayoff = choice.payoff(i).toDouble();
        print('( ${choice.maneuver.toString().padLeft(14)}, '
            '${choice.forcefulBlow.toString().padLeft(2)}, '
            '${choice.feint.toString().padLeft(2)} ): '
            '${currentPayoff.toDouble().toStringAsFixed(3).padLeft(7).padRight(8)}' +
            '|'
                .padLeft(
                    -(currentPayoff / absMaxPayoff * 30)
                            .round()
                            .toInt()
                            .clamp(-30, 0) +
                        1,
                    '-')
                .padLeft(31)
                .padRight(
                    (currentPayoff / absMaxPayoff * 30)
                            .round()
                            .toInt()
                            .clamp(0, 30) +
                        31,
                    '-')
                .padRight(61));
      }
    }
    alreadyDiscovered = combat.discovered.length;
    iterationStart = watch.elapsed;
    oldDuplicates = duplicates;
  }

  watch.stop();
  print('total program runtime: ${watch.elapsed}');
}
