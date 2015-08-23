// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';
import 'package:logging/logging.dart';

import 'package:lochness/lochness.dart';

main(List<String> arguments) {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });

  var story = new Storyline();

  var w = new World(story);

  var people = new Faction(w, "people")
    ..unitPrototypes.addAll([
      new Unit.withData("survivalists", 4, 0.2),
      new Unit.withData("police officers", 6, 0.2),
      new Unit.withData("soldiers", 12, 0.4),
      new Unit.withData("commandos", 5, 1.0),
      new Unit.withData("tanks", 3, 2.0),
    ]);
  w.peopleFaction = people;
  people.commandFactories = [new AttackCommandFactory(w, story)];

  var nessies = new Faction(w, "Nessie monsters", pronoun: Pronoun.YOU);
  w.playerFaction = nessies;

  makeEnemies(people, nessies);
  w.factions.addAll([people, nessies]);

  var loch = new Location(w, "Urquhart Castle")
    ..pos = new Point(57.3234416, -4.4424368)
    ..population = 12
    ..owner = nessies;

  var drumnadrochit = new Location(w, "Drumnadrochit")
    ..pos = new Point(57.3295768, -4.4848815)
    ..population = 813
    ..owner = people;

  var balnain = new Location(w, "Balnain")
    ..pos = new Point(57.3369235, -4.575195)
    ..population = 300
    ..owner = people;

  var lenie = new Location(w, "Lenie")
    ..pos = new Point(57.3091273, -4.4663843)
    ..population = 53
    ..owner = people;

  var struy = new Location(w, "Struy")
    ..pos = new Point(57.4218087, -4.6655394)
    ..population = 62
    ..owner = people;

  var abriachan = new Location(w, "Abriachan")
    ..pos = new Point(57.3846345, -4.403417)
    ..population = 120
    ..owner = people;

  var inverness = new Location(w, "Inverness Center")
    ..pos = new Point(57.4775242, -4.2203537)
    ..population = 40000
    ..owner = people;

  var invernessSouth = new Location(w, "Inverness South")
    ..pos = new Point(57.4701856, -4.2420219)
    ..population = 5000
    ..owner = people;

//  w.locations.addAll([loch, drumnadrochit, balnain, lenie, struy, abriachan, inverness]);

  var invernessPolice = new Unit("police officers")
    ..faction = people
    ..location = inverness
    ..count = 50
    ..strengthPerMember = 0.2;
  people.units.add(invernessPolice);

  var player = new Nessie(w)
    ..faction = nessies
    ..location = loch
    ..strength = 3
    ..eggs = 10;
  player.commandFactories = [
    new MonsterAttackCommandFactory(w, story),
    new HatchCommandFactory(w, story),
    new MoveCommandFactory(w, story)
  ];

  w.init();

  while (true) {
    // Get actions
    Map<int, Command> options = new Map<int, Command>();
    int index = 1;
    var commands = getAllCommands(player.commandFactories, player);
    commands = sortAndWeedOutCommands(commands);
    for (var action in commands) {
      options[index] = action;
      index++;
    }

    for (int i = 1; i < index; i++) {
      print("$i) [${options[i].computeDesirability().round()}] ${options[i]}");
    }

    String input = stdin.readLineSync();

    int chosen;
    try {
      chosen = int.parse(input);
    } on FormatException catch (e) {
      break;
    }

    options[chosen].execute();
    w.update();
    print(story);
    story.clear();
  }
}
