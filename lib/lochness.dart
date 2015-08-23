// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library lochness;

import 'dart:math';
import 'package:quiver/iterables.dart' as iter;
import "package:fuzzylogic/fuzzylogic.dart";
import 'package:lochness/libraries/storyline.dart';
export 'package:lochness/libraries/storyline.dart';
import 'package:lochness/libraries/randomly.dart';
import 'package:lochness/libraries/loopedevent.dart';
import 'package:egamebook/scripter.dart';

part 'src/world.dart';

class Game extends LoopedEvent {
  Storyline story;
  World w;
  Nessie player;

  Game() {
    setup();
  }

  void setup() {
    story = storyline;
    w = new World(story);

    var people = new Faction(w, "humans")
      ..unitPrototypes.addAll([
        new Unit.withData("survivalists", 4, 0.2),
        new Unit.withData("police officers", 6, 0.2),
        new Unit.withData("soldiers", 12, 0.4),
        new Unit.withData("soldiers", 34, 0.4),
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
      ..pos = new Point(433, 227)
      ..population = 12
      ..owner = nessies;

    var drumnadrochit = new Location(w, "Drumnadrochit")
      ..pos = new Point(413, 215)
      ..population = 813
      ..owner = people;

    new Location(w, "Abriachan")
      ..pos = new Point(468, 155)
      ..population = 120
      ..owner = people;

    var struy = new Location(w, "Struy")
      ..pos = new Point(297, 99)
      ..population = 62
      ..owner = people;

    new Location(w, "Lochend")
      ..pos = new Point(515, 126)
      ..population = 26
      ..owner = people;

    var dochgarroch = new Location(w, "Dochgarroch")
      ..pos = new Point(534, 98)
      ..population = 205
      ..owner = people;

    new Location(w, "Bunchrew")
      ..pos = new Point(534, 45)
      ..population = 130
      ..owner = people;

    new Location(w, "Kirkhill")
      ..pos = new Point(467, 47)
      ..population = 1672
      ..owner = people;

    new Location(w, "Beauly")
      ..pos = new Point(433, 35)
      ..population = 1130
      ..owner = people;

    new Location(w, "Kilmorack")
      ..pos = new Point(397, 55)
      ..population = 231
      ..owner = people;

    new Location(w, "Cannich")
      ..pos = new Point(226, 197)
      ..population = 192
      ..owner = people;

    new Location(w, "Tomich")
      ..pos = new Point(197, 235)
      ..population = 71
      ..owner = people;

    new Location(w, "Invermoriston")
      ..pos = new Point(319, 351)
      ..population = 196
      ..owner = people;

    new Location(w, "Fort Augustus")
      ..pos = new Point(274, 435)
      ..population = 646
      ..owner = people;

    var inverness = new Location(w, "Inverness Center")
      ..pos = new Point(586, 40)
      ..population = 40000
      ..owner = people;

    var invernessSouth = new Location(w, "Inverness South")
      ..pos = new Point(578, 77)
      ..population = 5000
      ..owner = people;

    var invernessPolice = new Unit("police officers")
      ..faction = people
      ..location = inverness
      ..count = 50
      ..strengthPerMember = 0.2;
    people.units.add(invernessPolice);

    var dochgarrochHunters = new Unit("hunters")
      ..faction = people
      ..location = dochgarroch
      ..count = 6
      ..strengthPerMember = 0.2;
    people.units.add(dochgarrochHunters);

    var drumnadrochitPolice = new Unit("police officers")
      ..faction = people
      ..location = drumnadrochit
      ..count = 8
      ..strengthPerMember = 0.2;
    people.units.add(drumnadrochitPolice);

    player = new Nessie(w)
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
  }

  update() {
    if (player.hp == 0) {
      finished = true;
      return;
    }
    // Get actions
    Map<int, Command> options = new Map<int, Command>();
    var commands = getAllCommands(player.commandFactories, player);
    commands = sortAndWeedOutCommands(commands);
    if (commands.isEmpty) {
      finished = true;
    }
    for (var action in commands) {
      //[${action.computeDesirability().round()}]
      choice("${action}", script: () {
        action.execute();
        w.update();
      });
    }
  }
}
