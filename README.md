# Deus Ex co-op: HX revived

Play the whole **Deus Ex** (2000) campaign together with friends, over Steam, without
IP addresses or port forwarding.

This builds on **HX**, the Deus Ex co-op mod by Sebastian Kaufel (Hanfling), whose last
build (0.9.89.4) came out in 2019. This repo adds:

- **HXFix**: a separate fix package for HX's co-op bugs (crashes on map changes, the
  ending, cutscenes, conversations, devices, weapons, nanokeys, notes, mission scripts).
  HX itself is not modified or redistributed; the installer downloads it from its
  official build server.
- **HXCoop**: a small Steam relay. The host presses 1, friends press 2, and the game
  connects through Steam's relay network.
- **Automated tests**: every fix has a test that runs real game clients on one PC.

[![Support me on Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/cranebeaker)

## Play in three steps

You need **Deus Ex: Game of the Year Edition** (Steam or GOG) and **Steam** running.

1. Download the latest `DeusEx-Coop-<version>.zip` from
   [Releases](../../releases) and unzip it anywhere.
2. Run **Install.bat**. It finds Deus Ex, downloads HX, installs the fixes and puts a
   **Deus Ex Co-op** shortcut on your desktop.
3. Open **Deus Ex Co-op**. Host: press **1**. Friend: press **2** (it finds you in their
   Steam friends list and joins).

Steam shows you as "playing Spacewar" while connected. That is expected: it is Valve's
free test app, used here to borrow Steam's relay network.

No Steam? Use `Host Co-op (IP).bat` and `Join Co-op (IP).bat` in `Deus Ex\System`, with
UDP ports 7790-7792 forwarded on the host's router or everyone on the same VPN.

## Status

**Beta.** Every fix is covered by automated tests that run real game clients (a listen
host plus 1 or 2 players), including runs through the Steam relay with simulated internet
lag and packet loss, map changes with several players, and a friend's install downloading
the fix package from the host. Found a problem? Tell us in [Issues](../../issues).

What is fixed: see [BUGS.md](BUGS.md) for every bug, its root cause and its test, and
[dist/src/CHANGES.txt](dist/src/CHANGES.txt) for the short version.

Known issues:

- The endgame quote and credits sequence is a stub in HX.
- Stock HX logs harmless "Accessed None" warnings during conversations.

## How it works

- HX turns Deus Ex's single-player logic (conversations, missions, flags, map travel)
  into something its multiplayer netcode can run. Its code is UnrealScript in `HX.u`
  plus native code in `HX.dll`.
- HXFix never rebuilds `HX.u`. It is a new package with subclasses of the broken
  classes, swapped in through HX's own mutator hooks, a game type subclass and player
  class subclasses. Fix modules per subsystem: augs, player, devices, weapons,
  conversations.
- HXCoop creates a friends-only Steam lobby (AppID 480), starts the game, and forwards
  the game's UDP packets over Steam networking messages. Details in the
  [coop-anything playbook](https://github.com/cranebeaker/coop-anything/blob/main/playbook/networking-steam-spacewar.md).

Building and running the tests: [DEVELOPING.md](DEVELOPING.md).

## Part of coop-anything

This is one entry in [coop-anything](https://github.com/cranebeaker/coop-anything), a
community playbook and directory for adding co-op to single-player classics. If your AI
agent helped you fix something here, the playbook explains how to send it back.

## Credits

- **HX** by Sebastian Kaufel (Hanfling): https://builds.hx.hanfling.de/
- Deus Ex by Ion Storm and Eidos. You need your own copy.
- Steam networking via `steam_api.dll` from Steamworks.NET (rlabrecque).

## License

The code in this repository (HXFix, HXCoop, tools) is MIT licensed, see [LICENSE](LICENSE).
HX, Deus Ex and Steam are the property of their owners and are not included.
