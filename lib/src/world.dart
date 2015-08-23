part of lochness;

class Desirability extends FuzzyVariable<num> {
  String name = "Desirability";

  var BadIdea = new FuzzySet.LeftShoulder(0, 0, 30, "BadIdea");
  var Undesirable = new FuzzySet.Triangle(0, 30, 70, "Undesirable");
  var Desirable = new FuzzySet.Triangle(30, 70, 100, "Desirable");
  var Urgent = new FuzzySet.RightShoulder(70, 100, 100, "Urgent");

  Desirability() {
    sets = [BadIdea, Undesirable, Desirable, Urgent];
    init();
  }
}

class FuzzyRatio extends FuzzyVariable<num> {
  String name = "FuzzyRatio";

  var Fraction = new FuzzySet.LeftShoulder(0, 0, 1.0, "Fraction");
  var Even = new FuzzySet.Triangle(0.5, 1.0, 2.0, "Even");
  var Multiple = new FuzzySet.RightShoulder(1.0, 2.0, 2.0, "Multiple");

  FuzzyRatio() {
    sets = [Fraction, Even, Multiple];
    init();
  }
}

class FuzzyAmount extends FuzzyVariable<num> {
  String name = "FuzzyAmount";

  var Low;
  var Medium;
  var High;

  FuzzyAmount(num low, num medium, num high) {
    Low = new FuzzySet.LeftShoulder(low, low, medium, "Low");
    Medium = new FuzzySet.Triangle(low, medium, high, "Medium");
    High = new FuzzySet.RightShoulder(medium, high, high, "High");

    sets = [Low, Medium, High];
    init();
  }
}

//const num MAX_NEIGHBOUR_DISTANCE = 2.5;
const int DEFAULT_NEIGHBORS_COUNT = 2;

const num CHANCE_OF_RECURRING_EVENT = 0.8;
const num CHANCE_OF_ONE_TIME_EVENT = 0.5;

const int DEFAULT_NEW_EGGS_COUNT = 10;

class World {
  World(this.story);

  Storyline story;
  Set<Location> locations = new Set();
  Set<Faction> factions = new Set();
  Set<Monster> monsters = new Set();
  Faction playerFaction;
  Nessie playerMonster;

  /// Main enemy faction.
  Faction peopleFaction;

  bool _initialized = false;

  void removeUnits(Iterable<Unit> units) {
    for (Faction f in factions) {
      f.units.removeWhere((unit) => units.contains(unit));
    }
  }

  /// Initializes some of the member fields of World elements.
  void init() {
    // Get neighbors of locations.
//    final maxNeighborDistanceSquared = pow(MAX_NEIGHBOUR_DISTANCE, 2);
    for (Location loc in locations) {
//      bool isClose(Location other) {
//        if (loc == other) return false;
//        return loc.pos.squaredDistanceTo(other.pos) <=
//            maxNeighborDistanceSquared;
//      }

      int compareDistance(Location a, Location b) {
        return loc.pos.distanceTo(a.pos).compareTo(loc.pos.distanceTo(b.pos));
      }

      List<Location> candidateNeighbors =
          locations.where((l) => l != loc).toList();
      candidateNeighbors.sort(compareDistance);

      loc.neighbors = candidateNeighbors.take(DEFAULT_NEIGHBORS_COUNT).toSet();
    }

    // Make sure all neighbors are reciprocal.
    for (Location loc in locations) {
      for (Location neighbor in loc.neighbors) {
        neighbor.neighbors.add(loc);
      }
    }

//    locations.forEach((loc) {
//      print("$loc > ${loc.neighbors.map((n) => n.toString()).join(', ')}");
//    });

    _initialized = true;
  }

  /// Go one tick.
  void update() {
    if (!_initialized) {
      throw new StateError("After you've set up a World, it must be "
          "initialized through init().");
    }

    story.addParagraph();

    for (var loc in locations) {
      if (loc.hatchingEggs > 0) {
        if (playerFaction.enemies.contains(loc.owner)) {
          story.add("<subject> butcher<s> the eggs near <object>",
              subject: loc.owner, object: loc);
          loc.hatchingEggs = 0;
        } else if (Randomly.tossCoin()) {
          story.add(
              "the eggs near $loc have hatched into ${loc.hatchingEggs} cute little monsters");
          var newUnit = new Hatchlings()
            ..count = loc.hatchingEggs
            ..location = loc
            ..faction = playerFaction;
          story.add("the hatchlings quickly spread into the neigborhood");
          story.add("they will feed on the local populace");
          loc.owner.units.add(newUnit);
          loc.hatchingEggs = 0;
          Unit.consolidateUnits(loc.getFactionUnits(playerFaction), this);
        }
      }
    }

    Set<Hatchlings> toRemove = new Set();
    for (Hatchlings unit
        in playerFaction.units.where((unit) => unit is Hatchlings)) {
      if (unit.starvationRatio(unit.location) > 1.0) {
        story.add("the ${unit.count} hatchlings at ${unit.location} "
            "(pop ${unit.location.population}) are starving");
        story.add("there is not enough people there to eat");
        if (unit.count < 3) {
          story.add("they die");
          toRemove.add(unit);
        } else {
          unit.count = (unit.count * 2 / 3).round();
          story.add(
              "a third of them die, so there is now only ${unit.count} of them");
        }
      }
    }
    removeUnits(toRemove);

    if (playerMonster.hp == 0) return;

    story.addParagraph();

    if (Randomly.saveAgainst(CHANCE_OF_RECURRING_EVENT)) {
      _fireRecurringEvent();
    } else if (Randomly.saveAgainst(CHANCE_OF_ONE_TIME_EVENT)) {
      _fireOneTimeEvent();
    }
    // Random events
    // TODO part of hatchlings goes from occupied town to another (wreaking havoc)
    // TODO one hatchling grows into a monster - sex = more eggs
    // TODO silvestr stalone makes an appearance
    // TODO monster-induced genocide
  }

  void _newUnitRecurringEvent() {
    Faction enemy = Randomly.choose(playerFaction.enemies.toList());
    if (enemy.unitPrototypes.isEmpty) {
      throw new UnimplementedError("$enemy doesn't have unit prototypes");
    }
    List<Location> candidateLocs =
        enemy.getUnoccupiedLocationsNeighboringWithEnemy().toList();
    if (candidateLocs.isEmpty) {
      candidateLocs = enemy.getLocationsNeighboringWithEnemy().toList();
    }
    if (candidateLocs.isEmpty) {
      // No locations neighboring with enemy. Lucky faction!
      return;
    }
    Location loc = Randomly.choose(candidateLocs);

    Unit newUnit = Randomly.choose(enemy.unitPrototypes.toList()).clone();
    newUnit.location = loc;
    newUnit.faction = enemy;
    story.add("${newUnit.count} ${newUnit.name} <has> arrived in <object>",
        subject: newUnit, object: loc);
    enemy.units.add(newUnit);

    Unit.consolidateUnits(loc.getFactionUnits(enemy), this);
  }

  void _newEggsRecurringEvent() {
    story.add("<subject> can feel inside your belly that new eggs are ready",
        subject: playerMonster);
    playerMonster.eggs += DEFAULT_NEW_EGGS_COUNT;
  }

  void _attackCommandRecurringEvent() {
    List<Command> commands =
        getAllCommands(peopleFaction.commandFactories, peopleFaction).toList();

    if (commands.isEmpty) {
      print("No commands for $peopleFaction");
      return;
    }

    sortAccordingToDesirability(commands);

//    print("command: $commands");

    commands.first.execute();
  }

  Function _lastRecurringEvent;

  void _fireRecurringEvent() {
    List<Function> events = [
      _newUnitRecurringEvent,
      _newEggsRecurringEvent,
      _attackCommandRecurringEvent
    ];

    if (_lastRecurringEvent != null) {
      // Do not repeat ourselves.
      events.remove(_lastRecurringEvent);
    }

    Function chosen = Randomly.choose(events);
    chosen();
    _lastRecurringEvent = chosen;
  }

  void _fireOneTimeEvent() {
    print("One time event fired but none implemented.");
    // TODO: add one time events (Mothmen come)
  }
}

class Faction extends Entity {
  Faction(this.w, String name, {pronoun: Pronoun.THEY})
      : super.withOptions(name, pronoun: pronoun, nameIsProperNoun: true);

  final World w;
  Set<Faction> allies = new Set();
  Set<Faction> enemies = new Set();
  Set<Unit> units = new Set();

  Set<Unit> unitPrototypes = new Set();

  Iterable<CommandFactory> commandFactories;

  Iterable<Location> get locations =>
      w.locations.where((loc) => loc.owner == this);

  Iterable<Location> getLocationsNeighboringWithEnemy() {
    return locations.where((loc) =>
        loc.neighbors.any((neighbor) => enemies.contains(neighbor.owner)));
  }

  Iterable<Location> get occupiedLocations =>
      units.map((unit) => unit.location).toSet();

  Iterable<Location> get unoccupiedLocations =>
      locations.toSet().difference(occupiedLocations);

  Iterable<Location> getUnoccupiedLocationsNeighboringWithEnemy() {
    return unoccupiedLocations.where((loc) =>
        loc.neighbors.any((neighbor) => enemies.contains(neighbor.owner)));
  }

  Iterable<Location> getEnemyLocationsNeighboringWithUnits() {
    Iterable<Location> neighboringLocs = units
        .map((unit) => unit.location)
        .toSet()
        .expand((Location loc) => loc.neighbors);
    return neighboringLocs.where((loc) => enemies.contains(loc.owner));
  }

  Iterable<Unit> getAttackUnits(Location loc) {
    return loc.neighbors.expand((loc) => loc.getFactionUnits(this));
  }

  /// Returns a sum of population of all owned locations.
  int getPopulationCount() {
    return locations.fold(0, (prev, loc) => prev + loc.population);
  }

  /// Returns a sum of all unit member counts.
  int getSizeOfArmy() {
    return units.fold(0, (prev, unit) => prev + unit.count);
  }

  num getGlobalStarvationRatio() {
    int population = getPopulationCount();
    if (population == 0) return double.INFINITY;
    int needed = getSizeOfArmy() * MIN_POPULATION_PER_HATCHLING;
    return needed / population;
  }
}

class Location extends Entity {
  Location(this.w, String name)
      : super.withOptions(name, nameIsProperNoun: true) {
    w.locations.add(this);
  }

  final World w;
  Point<num> pos;
  int population = 0;
  int hatchingEggs = 0;
  Faction owner;
  Set<Location> neighbors;

  toString() => name;

  Iterable<Unit> getUnits() {
    Iterable<Unit> units = w.factions.expand((f) => f.units);
    var onlyInThisLocation = units.where((unit) => unit.location == this);
    return onlyInThisLocation;
  }

  Iterable<Monster> getMonsters() {
    var onlyInThisLocation = w.monsters.where((m) => m.location == this);
    return onlyInThisLocation;
  }

  Iterable<Unit> getFactionUnits(Faction f) {
    return getUnits().where((unit) => unit.faction == f);
  }

  Iterable<Monster> getFactionMonsters(Faction f) {
    return getMonsters().where((m) => m.faction == f);
  }

  /// Returns the combined force of [f] stationed at location.
  CombinedForce getFactionCombinedForce(Faction f) {
    return new CombinedForce.from(getFactionUnits(f), getFactionMonsters(f));
  }

  String enumerateFactionUnits(Faction f) {
    return _enumerateUnits(_consolidateUnits(getFactionUnits(f)));
  }

  /// Returns units located in this location that are enemies of [f].
  Iterable<Unit> getEnemyUnits(Faction f) {
    return getUnits().where((unit) => f.enemies.contains(unit.faction));
  }

  /// Returns units located in this location that are enemies of [f].
  Iterable<Monster> getEnemyMonsters(Faction f) {
    return getMonsters().where((m) => f.enemies.contains(m.faction));
  }

  /// Get the combined Force of units that are enemies of [f].
  CombinedForce getEnemyCombinedForce(Faction f) {
    return new CombinedForce.from(getEnemyUnits(f), getEnemyMonsters(f));
  }

  String enumerateEnemyUnits(Faction f) {
    return _enumerateUnits(_consolidateUnits(getEnemyUnits(f)));
  }

  /// Get the strength that this location can raise against faction [f].
  num getCombinedStrengthAgainst(Faction f) {
    return getEnemyCombinedForce(f).combinedStrength;
  }

  bool isNeighborOfFaction(Faction f) {
    if (f == owner) return false;
    return neighbors.any((loc) => loc.owner == f);
  }

  Iterable<Unit> getNeighboringEnemyUnits(Faction f) {
    return neighbors.expand((loc) => loc.getEnemyUnits(f));
  }

  Iterable<Monster> getNeighboringEnemyMonsters(Faction f) {
    return neighbors.expand((loc) => loc.getEnemyMonsters(f));
  }

  CombinedForce getNeighboringEnemyCombinedForce(Faction f) {
    return new CombinedForce.from(
        getNeighboringEnemyUnits(f), getNeighboringEnemyMonsters(f));
  }

  /// Returns units of faction [f] that are available for attack on this
  /// location.
  Iterable<Unit> getNeighboringUnits(Faction f) {
    return neighbors.expand((loc) => loc.getFactionUnits(f));
  }

  /// Returns monsters of faction [f] that are available for attack on this
  /// location.
  Iterable<Monster> getNeighboringMonsters(Faction f) {
    return neighbors.expand((loc) => loc.getFactionMonsters(f));
  }

  /// Returns the combined force of all armies (including monsters)
  /// of [f] available for attack.
  CombinedForce getCombinedForceOfNeighborArmies(Faction f) {
    return new CombinedForce.from(
        getNeighboringUnits(f), getNeighboringMonsters(f));
  }

  /// Returns the combined strength of units that are enemies of [f] and
  /// that are located in a neighboring location.
  num getCombinedStrengthOfNeighbourEnemies(Faction f) {
    var force = getNeighboringEnemyCombinedForce(f);
    return force.combinedStrength;
  }

  /// Returns the combined strength of units of faction [f]
  /// that are located in a neighboring location (available for attack).
  num getCombinedStrengthOfNeighbourArmies(Faction f) {
    var force = getCombinedForceOfNeighborArmies(f);
    return force.combinedStrength;
  }
}

/// Helper function bundles together units and monsters (in area, for example).
class CombinedForce {
  CombinedForce.from(Iterable<Unit> units, Iterable<Monster> monsters) {
    this.units = new Set.from(units);
    this.monsters = new Set.from(monsters);
  }

  Set<Unit> units;
  Set<Monster> monsters;

  num get unitsStrength => units.fold(0, (prev, unit) => prev + unit.strength);
  num get monstersStrength =>
      monsters.where((m) => m.hp > 0).fold(0, (prev, m) => prev + m.strength);

  num get combinedStrength => unitsStrength + monstersStrength;

  /// Takes two combined forces and puts them together.
  CombinedForce combineWith(CombinedForce other) {
    return new CombinedForce.from(iter.concat([units, other.units]),
        iter.concat([monsters, other.monsters]));
  }

  void setLocationToAll(Location loc) {
    units.forEach((unit) => unit.location = loc);
    setLocationToMonsters(loc);
  }

  void setLocationToMonsters(Location loc) {
    monsters.forEach((m) => m.location = loc);
  }

  bool get isEmpty => units.isEmpty && monsters.isEmpty;

  void receiveDamage(Function addLoss, Function addMonsterBlow) {
    bool monsterIsHit =
        Randomly.saveAgainst(monstersStrength / (combinedStrength));
    if (monsterIsHit) {
      Monster m = Randomly.choose(monsters.toList());
      print("$m gets hit");
      m.hp -= 1;
      addMonsterBlow();
    } else {
      // A unit is hit
      Unit damagedUnit = Randomly.choose(units.toList());
      int lost = _hitUnit(damagedUnit);
      addLoss(damagedUnit.name, lost);
      if (damagedUnit.count == 0) {
        damagedUnit.faction.units.remove(damagedUnit);
      }
    }
  }
}

class Unit extends Actor {
  Unit(String type) : super(name: type, pronoun: Pronoun.THEY) {
    this.alreadyMentioned = false;
  }

  Unit.withData(String type, this.count, this.strengthPerMember)
      : super(name: type, pronoun: Pronoun.THEY) {
    this.alreadyMentioned = false;
  }

  Faction faction;

  String get type => name;

  int count = 10;
  num strengthPerMember = 1.0;

  num get strength => count * strengthPerMember;

  Location location;

  /// If units are twice as strong or more, returns 1.0. If they are
  /// half as strong or less, returns -1.0. If units are comparable, returns
  /// 0.
  static num combinedStrengthSupremacy(
      CombinedForce units, CombinedForce others) {
    num unitStrength = units.combinedStrength;
    num otherStrength = others.combinedStrength;
    if (unitStrength > 0 && otherStrength == 0) return 1.0;
    if (unitStrength == 0 && otherStrength > 0) return -1.0;
    if (unitStrength == 0 && otherStrength == 0) return 0.0;
    num ratio = unitStrength / otherStrength;
    if (ratio >= 1.0) {
      return min(ratio - 1.0, 1.0);
    } else {
      return -min(1 / ratio - 1.0, 1.0);
    }
  }

  /// Puts members of units of same type into one, deletes the "emptied" units.
  static void consolidateUnits(Iterable<Unit> units, World w) {
    Set<String> types = units.map((unit) => unit.type).toSet();
    for (String type in types) {
      List<Unit> unitsOfType =
          units.where((unit) => unit.type == type).toList();
      if (unitsOfType.length > 1) {
        Unit first = unitsOfType[0];
        List<Unit> rest = unitsOfType.getRange(1, unitsOfType.length).toList();
        first.count += rest.fold(0, (prev, unit) => prev + unit.count);
        w.removeUnits(rest);
      }
    }
  }

  num starvationRatio(Location loc) => 0.0;

  Unit clone() {
    Unit newUnit = new Unit(name)
      ..faction = faction
      ..count = count
      ..strengthPerMember = strengthPerMember
      ..location = location;
    return newUnit;
  }

  toString() => "$name($count) at $location";
}

class Hatchlings extends Unit {
  Hatchlings() : super("hatchlings");

  @override
  num starvationRatio(Location loc) {
    if (loc.population == 0) return double.INFINITY;
    return this.count * MIN_POPULATION_PER_HATCHLING / loc.population;
  }
}

class Monster extends Actor {
  Monster(World w, String name,
      {bool isPlayer: false, Pronoun pronoun: Pronoun.IT})
      : super(name: name, isPlayer: isPlayer, pronoun: pronoun) {
    w.monsters.add(this);
  }

  Faction faction;
  int hp = 10;
  int strength = 1;
  Location location;

  Iterable<CommandFactory> commandFactories;
}

const int MIN_POPULATION_PER_HATCHLING = 5;

class Nessie extends Monster {
  Nessie(World w)
      : super(w, "Loch Ness monster", isPlayer: true, pronoun: Pronoun.YOU) {
    assert(w.playerMonster == null);
    w.playerMonster = this;
  }

  int eggs;
}

void makeEnemies(Faction a, Faction b) {
  a.enemies.add(b);
  b.enemies.add(a);
}

abstract class Command {
  String get name;
  void execute();
  num computeDesirability();
}

abstract class CommandFactory<T extends Command> {
  CommandFactory(this.w, this.o);

  World w;
  Storyline o;

  /// Generate possible commands that [m] can do.
  Set<T> generatePossibleCommands(Object m);
}

Map<String, int> _consolidateUnits(Iterable<Unit> units) {
  Map<String, int> result = new Map();
  for (Unit unit in units) {
    if (result.containsKey(unit.name)) {
      result[unit.name] += unit.count;
    } else {
      result[unit.name] = unit.count;
    }
  }

  Set<String> toRemove = new Set();
  for (String key in result.keys) {
//    result[key] = (result[key] * percentage).round();
    if (result[key] <= 1) {
      // We don't want to report "you are joined by 1 tanks" or whatever.
      toRemove.add(key);
    }
  }
  toRemove.forEach((key) => result.remove(key));

  return result;
}

String _enumerateUnits(Map<String, int> consolidated) {
  if (consolidated.isEmpty) return null;
  List<String> strs = [];
  consolidated.forEach((key, count) {
    strs.add("$count $key");
  });
  if (strs.length == 1) return strs.single;
  return strs.getRange(0, strs.length - 1).join(", ") + " and " + strs.last;
}

String _enumerateTowns(List<Location> locations) {
  if (locations.length == 1) return locations.single.name;
  return locations
          .getRange(0, locations.length - 1)
          .map((loc) => loc.name)
          .join(", ") +
      " and " +
      locations.last.name;
}

int _hitUnit(Unit unit) {
  int damage = min((unit.count * 0.1).round() + 1, unit.count);
  unit.count -= damage;
  return damage;
}

/// Max losses before army gets withdrawn.
const num MAX_LOSSES_PERCENTAGE = 0.5;

/// Percentage of hits that go to a unit instead of a monster.
const num UNIT_TO_MONSTER_HIT_RATIO = 0.8;

void resolveAttack(World w, Storyline story, Location loc,
    {Monster m, Faction f}) {
  if (m == null &&
      f == null) throw new ArgumentError("Either supply monster or faction");
  if (m != null) f = m.faction;

  bool isMonsterAttack = m != null;

  if (isMonsterAttack) {
    story.add("<subject> attack<s> <object>", subject: m, object: loc);
  }
  List<Unit> attackUnits = f.getAttackUnits(loc).toList();
  if (!isMonsterAttack &&
      attackUnits.isEmpty) throw new StateError("Can't attack with no units.");

  var enumeration = _enumerateUnits(_consolidateUnits(attackUnits));
  if (enumeration != null) {
    String townEnum = _enumerateTowns(
        attackUnits.map((unit) => unit.location).toSet().toList());
    if (isMonsterAttack) {
      story.add("<subject> <is> joined by $enumeration from $townEnum",
          subject: m);
    } else {
      story.add("$enumeration from $townEnum attack <object>",
          subject: f, object: loc);
    }
  }

  CombinedForce attackers;
  if (isMonsterAttack) {
    attackers = new CombinedForce.from(attackUnits, [m]);
  } else {
    attackers = new CombinedForce.from(attackUnits, []);
  }
  num attackerStrength = attackers.combinedStrength;
  CombinedForce defenders = loc.getEnemyCombinedForce(f);
  num defenderStrength = defenders.combinedStrength;
  if (defenderStrength == 0) {
    story.add("there is no resistance");
    if (isMonsterAttack) {
      story.add("with glee, <subject> butcher<s> a couple of terrified locals",
          subject: m);
      if (enumeration != null) {
        story.add("<subject's> abominable army follows suit", subject: m);
      }
    } else {
      story.add("the attackers move in", subject: f);
      if (f == w.peopleFaction) {
        story.add("<subject> start cleaning up the area of filth", subject: f);
      }
    }
    attackers.setLocationToAll(loc);
    Unit.consolidateUnits(loc.getFactionUnits(f), w);
    loc.owner = f;
    story.add("<subject> is now under <objectPronoun's> control",
        subject: loc, object: f);
    return;
  }

  story.add(
      "<subject> encounter<s> ${attackerStrength > defenderStrength ? "some" : "heavy"} resistance",
      subject: isMonsterAttack ? m : f, negative: true);

  Map<String, int> enemyLosses = new Map();

  void addEnemyLoss(String name, int count) {
    enemyLosses[name] = enemyLosses.putIfAbsent(name, () => 0) + count;
  }
  int attackerCountTotal =
      attackUnits.fold(0, (prev, unit) => prev + unit.count);
  Map<String, int> attackerLosses = new Map();

  void addAttackerLoss(String name, int count) {
    attackerLosses[name] = attackerLosses.putIfAbsent(name, () => 0) + count;
  }
  int attackingMonsterBlows = 0;
  void addAttackingMonsterBlow() {
    attackingMonsterBlows++;
  }
  int defendingMonsterBlows = 0;
  void addDefendingMonsterBlow() {
    defendingMonsterBlows++;
  }

  bool attackerHasWon;
  while (true) {
    if (defenders.combinedStrength == 0) {
      attackerHasWon = true;
      break;
    }
    if ((isMonsterAttack && m.hp == 0) ||
        (attackerLosses.isNotEmpty &&
            attackerLosses.values.reduce((a, b) => a + b) >
                attackerCountTotal * MAX_LOSSES_PERCENTAGE)) {
      attackerHasWon = false;
      break;
    }

    bool win = Randomly
        .saveAgainst(attackerStrength / (attackerStrength + defenderStrength));
    if (win) {
      defenders.receiveDamage(addEnemyLoss, addDefendingMonsterBlow);
    } else {
      attackers.receiveDamage(addAttackerLoss, addAttackingMonsterBlow);
    }
  }

  if (attackerLosses.isNotEmpty) {
    story.add("<subject> lose<s> ${_enumerateUnits(attackerLosses)}",
        subject: f);
  }
  if (isMonsterAttack && attackingMonsterBlows > 0) {
    story.add("<subject> receive $attackingMonsterBlows serious blows",
        subject: m);
  }

  if (enemyLosses.isNotEmpty) {
    story.add("<subject> lose<s> ${_enumerateUnits(enemyLosses)}",
        subject: loc.owner);
  }

  if (defendingMonsterBlows > 0) {
    story.add("<subject> receive $defendingMonsterBlows serious blows",
        subject: defenders.monsters.first /* TODO: fix */);
  }

  if (attackerHasWon) {
    if (isMonsterAttack) {
      story.add(
          "after a bit of additional stomping and destruction, <subject> realize<s> <subjectPronoun> win<s>",
          subject: m, positive: true);
      attackers.setLocationToMonsters(loc);
    } else {
      story.add("the attackers secure the area");
      attackers.setLocationToAll(loc);
      Unit.consolidateUnits(loc.getFactionUnits(f), w);
    }
    loc.owner = f;
    story.add("<subject> is now under <objectPronoun's> control",
        subject: loc, object: f);
  } else {
    story.add("after a while, <subject> decide<s> to retreat",
        subject: f, negative: true);
  }

  void reportDeadMonster(Monster monster) {
    if (monster.hp == 0) {
      story.addParagraph();
      story.add("<subject> die<s> from the battle wounds", subject: monster);
    }
  }

  attackers.monsters.forEach(reportDeadMonster);
  defenders.monsters.forEach(reportDeadMonster);
}

class AttackCommand extends Command {
  AttackCommand(this.f, this.w, this.story, this.loc);

  String name = "AttackCommand";
  Faction f;
  Monster m;
  World w;
  Storyline story;
  Location loc;

  @override
  void execute() {
    resolveAttack(w, story, loc, f: f);
  }

  toString() {
//    if (loc.getEnemyUnits(m.faction).isNotEmpty) {
//      return "Take $loc (pop ${loc.population}, ${loc.enumerateEnemyUnits(m.faction)})";
//    }
    return "Take $loc (pop ${loc.population})";
  }

  @override
  num computeDesirability() {
    var go = new Desirability();
    var population = new FuzzyAmount(0, 100, 50000);
    var supremacy = new FuzzyRatio();
    var globalStarvationRatio = new FuzzyRatio();

    var frb = new FuzzyRuleBase();
    frb.addRules([
      population.Low >> go.Undesirable,
      population.Medium >> go.Desirable,
      population.High >> go.Desirable,
      supremacy.Fraction >> go.BadIdea,
      supremacy.Even >> go.Undesirable,
      supremacy.Multiple >> go.Desirable,
      globalStarvationRatio.Fraction >> go.Undesirable,
      globalStarvationRatio.Even >> go.Desirable,
      globalStarvationRatio.Multiple >> go.Urgent,
    ]);

    var output = go.createOutputPlaceholder();

    frb.resolve(
        inputs: [
      population.assign(loc.population),
      supremacy.assign(Unit.combinedStrengthSupremacy(
          loc.getCombinedForceOfNeighborArmies(f),
          loc.getEnemyCombinedForce(f))),
      globalStarvationRatio.assign(f.getGlobalStarvationRatio())
    ],
        outputs: [output]);

    return output.crispValue;
  }
}

class AttackCommandFactory extends CommandFactory<AttackCommand> {
  AttackCommandFactory(World w, Storyline o) : super(w, o);

  @override
  Iterable generatePossibleCommands(Faction f) sync* {
    for (Location loc in f.getEnemyLocationsNeighboringWithUnits()) {
      yield new AttackCommand(f, w, o, loc);
    }
  }
}

class MonsterAttackCommand extends AttackCommand {
  MonsterAttackCommand(Monster m, World w, Storyline story, Location loc)
      : super(m.faction, w, story, loc) {
    this.m = m;
  }

  String name = "MonsterAttackCommand";

  @override
  void execute() {
    resolveAttack(w, story, loc, m: m);
  }

  @override
  toString() {
    if (loc.getEnemyUnits(m.faction).isNotEmpty) {
      return "Take $loc (pop ${loc.population}, ${loc.enumerateEnemyUnits(m.faction)})";
    }
    return "Take $loc (pop ${loc.population})";
  }
}

class MonsterAttackCommandFactory extends CommandFactory<MonsterAttackCommand> {
  MonsterAttackCommandFactory(World w, Storyline o) : super(w, o);

  @override
  Iterable generatePossibleCommands(Monster m) sync* {
    for (Location loc in w.locations.where(
        (loc) => m.faction.enemies.contains(loc.owner) &&
            loc.isNeighborOfFaction(m.faction))) {
      yield new MonsterAttackCommand(m, w, o, loc);
    }
  }
}

class HatchCommand extends Command {
  HatchCommand(this.m, this.w, this.story, this.loc);

  String name = "HatchCommand";
  Nessie m;
  World w;
  Storyline story;
  Location loc;

  @override
  void execute() {
    story.add("<subject> lay<s> <subject's> ${m.eggs} eggs near <object>",
        subject: m, object: loc);
    loc.hatchingEggs += m.eggs;
    m.eggs = 0;
  }

  toString() => "Lay eggs at $loc (pop ${loc.population})";

  @override
  num computeDesirability() {
    Faction f = m.faction;

    var go = new Desirability();
    var locEnemyStrength = new FuzzyAmount(0, 5, 50);
    var locToEnemyRatio = new FuzzyRatio();
    var starvationRatio = new FuzzyRatio();

    var frb = new FuzzyRuleBase();
    frb.addRules([
      locEnemyStrength.Low >> go.Desirable,
      locEnemyStrength.Medium >> go.Undesirable,
      locEnemyStrength.High >> go.BadIdea,
      locToEnemyRatio.Fraction >> go.BadIdea,
      locToEnemyRatio.Even >> go.Desirable,
      locToEnemyRatio.Multiple >> go.Desirable,
      starvationRatio.Fraction >> go.Urgent,
      starvationRatio.Even >> go.Undesirable,
      starvationRatio.Multiple >> go.BadIdea,
    ]);

    var output = go.createOutputPlaceholder();

    num crispStarvationRatio;
    if (loc.population == 0) {
      crispStarvationRatio = double.INFINITY;
    } else {
      crispStarvationRatio =
          m.eggs * MIN_POPULATION_PER_HATCHLING / loc.population;
    }

//    logger.info("to enemy ratio = " + Unit.combinedStrengthRatio(
//          loc.getFactionUnits(f),
//          loc.getNeighboringEnemyUnits(f)).toString());
//    logger.info("enemy strength = " + loc.getCombinedStrengthOfNeighbours(f).toString());

    frb.resolve(
        inputs: [
      locEnemyStrength.assign(loc.getCombinedStrengthOfNeighbourEnemies(f)),
      locToEnemyRatio.assign(Unit.combinedStrengthSupremacy(
          loc.getFactionCombinedForce(f),
          loc.getNeighboringEnemyCombinedForce(f))),
      starvationRatio.assign(crispStarvationRatio)
    ],
        outputs: [output]);

//    print(output.degreesOfTruth);

    return output.crispValue;
  }
}

class HatchCommandFactory extends CommandFactory<HatchCommand> {
  HatchCommandFactory(World w, Storyline o) : super(w, o);

  bool _locationIsValid(Nessie m, Location loc) {
    if (loc.owner != m.faction) return false;
//    if (m.eggs * MIN_POPULATION_PER_EGG > loc.population) return false;
    return true;
  }

  @override
  Iterable generatePossibleCommands(Nessie m) sync* {
    if (m is! Nessie) return;
    if (m.eggs == 0) return;
    for (Location loc in w.locations.where((loc) => _locationIsValid(m, loc))) {
      yield new HatchCommand(m, w, o, loc);
    }
  }
}

class MoveCommand extends Command {
  MoveCommand(this.f, this.w, this.story, this.origin, this.destination);

  String name = "MoveCommand";
  Faction f;
  World w;
  Storyline story;
  Location origin;
  Location destination;

  @override
  void execute() {
    var units = origin.getFactionUnits(f).toSet();
    units.forEach((unit) => unit.location = destination);
    story.addEnumeration("Earth <also> shatters as ", units,
        " from $origin make their way to $destination");
    Unit.consolidateUnits(destination.getFactionUnits(f), w);
    // TODO: consolidate units
  }

  toString() =>
      "Move the ${origin.enumerateFactionUnits(f)} from $origin to $destination (pop ${destination.population})";

  @override
  num computeDesirability() {
    var go = new Desirability();
    var originEnemyStrength = new FuzzyAmount(0, 5, 50);
    var destinationEnemyStrength = new FuzzyAmount(0, 5, 50);
    var destinationSupremacy = new FuzzyAmount(-1.0, 0, 1.0);
    var resultingDestinationSupremacy = new FuzzyAmount(-1.0, 0, 1.0);
    var originStarvation = new FuzzyRatio();
    var destinationStarvation = new FuzzyRatio();

    var frb = new FuzzyRuleBase();
    frb.addRules([
      // Combs
      originEnemyStrength.Low >> go.Undesirable,
      originEnemyStrength.Medium >> go.Undesirable,
      originEnemyStrength.High >> go.BadIdea,
      destinationEnemyStrength.Low >> go.Undesirable,
      destinationEnemyStrength.Medium >> go.Undesirable,
      destinationEnemyStrength.High >> go.Desirable,
      destinationSupremacy.Low >> go.Desirable,
      destinationSupremacy.Medium >> go.Undesirable,
      destinationSupremacy.High >> go.BadIdea,
      resultingDestinationSupremacy.Low >> go.BadIdea,
      resultingDestinationSupremacy.Medium >> go.Desirable,
      resultingDestinationSupremacy.High >> go.Undesirable,
      originStarvation.Fraction >> go.BadIdea,
      originStarvation.Even >> go.Desirable,
      originStarvation.Multiple >> go.Urgent,
      destinationStarvation.Fraction >> go.Desirable,
      destinationStarvation.Even >> go.BadIdea,
      destinationStarvation.Multiple >> go.BadIdea,

      // Old (incomplete) IRC for reference
      //      (originEnemyStrength.High) >> go.BadIdea,
      //      (originEnemyStrength.Low) >> go.Desirable,
      //      (destinationEnemyStrength.Low) >> go.Undesirable,
      //      (destinationSupremacy.Low &
      //              (resultingDestinationSupremacy.Medium |
      //                  resultingDestinationSupremacy.High)) >>
      //          go.Desirable,
      //      (destinationSupremacy.Medium &
      //              ~destinationEnemyStrength.Low &
      //              resultingDestinationSupremacy.High) >>
      //          go.Desirable,
      //      (destinationSupremacy.High) >> go.BadIdea,
      //      (originStarvation.Multiple &
      //              (destinationStarvation.Fraction | destinationStarvation.Even)) >>
      //          go.Urgent,
      //      (destinationStarvation.Multiple) >> go.BadIdea
    ]);

    var output = go.createOutputPlaceholder();

//    print("From $origin to $destination: ");
//    print("- destinationSupremacy: " + Unit.combinedStrengthSupremacy(
//          destination.getFactionUnits(f),
//          destination.getNeighboringEnemyUnits(f)).toString());
//
//    print(destination.getFactionUnits(f).join(", "));
//    print(destination.getNeighboringEnemyUnits(f).join(", "));

    frb.resolve(
        inputs: [
      originEnemyStrength
          .assign(origin.getCombinedStrengthOfNeighbourEnemies(f)),
      destinationEnemyStrength
          .assign(destination.getCombinedStrengthOfNeighbourEnemies(f)),
      destinationSupremacy.assign(Unit.combinedStrengthSupremacy(
          destination.getFactionCombinedForce(f),
          destination.getNeighboringEnemyCombinedForce(f))),
      resultingDestinationSupremacy.assign(Unit.combinedStrengthSupremacy(origin
              .getFactionCombinedForce(f)
              .combineWith(destination.getFactionCombinedForce(f)),
          destination.getNeighboringEnemyCombinedForce(f))),
      originStarvation.assign(
          origin.getFactionUnits(f).where((u) => u is Hatchlings).single
              .starvationRatio(origin)),
      destinationStarvation.assign(
          origin.getFactionUnits(f).where((u) => u is Hatchlings).single
              .starvationRatio(destination))
    ],
        outputs: [output]);

    return output.crispValue;
  }
}

class MoveCommandFactory extends CommandFactory<MoveCommand> {
  MoveCommandFactory(World w, Storyline o) : super(w, o);

  @override
  Iterable generatePossibleCommands(Monster m) sync* {
    Faction f = m.faction;
    Iterable<Location> locationsWithUnits =
        w.locations.where((loc) => f.units.any((unit) => unit.location == loc));

    for (Location origin in locationsWithUnits) {
      for (Location destination
          in w.locations.where((loc) => loc != origin && loc.owner == f)) {
        yield new MoveCommand(f, w, o, origin, destination);
      }
    }
  }
}

/// Generate all commands that [m] can take. [m] is either a Monster or
/// a Faction.
Iterable<Command> getAllCommands(
    Iterable<CommandFactory> factories, Object m) sync* {
  for (var factory in factories) {
    for (Command c in factory.generatePossibleCommands(m)) {
      yield c;
    }
  }
}

void sortAccordingToDesirability(List<Command> commands) {
  commands.sort((Command a, Command b) =>
      -a.computeDesirability().compareTo(b.computeDesirability()));
}

void sortAccordingToName(List<Command> commands) {
  commands.sort((Command a, Command b) => a.name.compareTo(b.name));
}

const int MAX_COMMANDS = 8;
const int MAX_COMMANDS_OF_SAME_TYPE = 3;

List<Command> sortAndWeedOutCommands(Iterable<Command> commands) {
  List<Command> lst = commands.toList();
  sortAccordingToDesirability(lst);
  List<Command> toRemove = [];
  Map<String, int> counters = new Map();
  for (Command c in lst) {
    counters[c.name] = counters.putIfAbsent(c.name, () => 0) + 1;
    if (counters[c.name] > MAX_COMMANDS_OF_SAME_TYPE) {
      toRemove.add(c);
    }
  }
  toRemove.forEach((c) => lst.remove(c));
  lst = lst.take(MAX_COMMANDS).toList();
  sortAccordingToName(lst);
  return lst;
}
