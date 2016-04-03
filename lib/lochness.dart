library Scripter_Implementation;

import 'package:egamebook/scripter.dart';
import 'dart:isolate';

import 'package:lochness/lochness_lib.dart';

class ScripterImpl extends Scripter {
  String uid = "net.filiph.lochness.0.0.1";

  /* LIBRARY */

      Game game;

  void populateVarsFromState() {
    vars["game"] = game;
  }
  void extractStateFromVars() {
    game = vars["game"] as Game;
  }
  ScripterImpl() : super() {
    /* PAGES & BLOCKS */
    pageMap[r"""start"""] = new ScripterPage(
      [
          """You have dwelt in the lake called _Loch Ness_ for long enough. For three thousand years you have eluded those pesky humans, watching them from below the water surface, gaining strength. Now, it's time.""",
          """You emerge from the cold lake near the ruins of Castle Urquhart. A small number of foreign looking humans is currently examining the crumbled walls. """,
          """When they see you towering above them, they start screaming and running to the woods. You crush six of them and then round up the rest inside the ruins. You count twelve humans. Not enough to feed the hatchlings, but a good start.""",
          """![Map of the area](img/drumnadrochit-map.jpg)""",
          """In their posession, you find this map of the area. It could prove useful.""",
          [
            null,
          {
            "goto": r"""gameLoop"""          }
        ]
        ]
    );
    pageMap[r"""gameLoop"""] = new ScripterPage(
      [
          () {
  game.run();
        },
          [
            null,
          {
            "goto": r"""gameLoop"""          }
        ]
        ]
    );
    pageMap[r"""endGame"""] = new ScripterPage(
      [
          """The end.""",
          """<p class="meta">Hit restart if you want to play again.</p>"""
          ]
    );
    pageMap[r"""DEBUG"""] = new ScripterPage(
      [
          """ohoho"""
          ]
    );
        firstPage = pageMap[r"""start"""];
  }
  /* INIT */
  void initBlock() {
    game = null;

        game = new Game();
        game.onFinishedGoto = "endGame";

  }
}

// The entry point of the isolate.
void main(List<String> args, SendPort mainIsolatePort) {
  PresenterProxy presenter = new IsolatePresenterProxy(mainIsolatePort);
  Scripter book = new ScripterImpl();
  presenter.setScripter(book);
}
