# HX bug list

Found by source review of HX 0.9.89.4 (six subsystem audits), each claim re-checked against src/Classes
before fixing. Early "Tested" notes in the first table were made on a dedicated server; everything was later covered by live tests with real clients (see below).

## Fixed in HXFix

| Bug | Where | Fix | Tested |
|---|---|---|---|
| Ending conversation never starts, everyone stuck letterboxed at the end | HXMissionEndgame.uc:37 compares "Endgame1" vs upper-case LocalURL | HXFixMissionEndgame (+ skip-to-credits fallback) | script loads on 99_Endgame1 |
| Endgame explosions use never-set `Player` (Accessed None, effects at world origin) | HXMissionEndgame.uc:259 | HXFixMissionEndgame.ExplosionEffects per player | script loads |
| Notes (door codes) wiped on every map change, never sent to late joiners | HXGameInfo.uc:2098 | HXFixNoteStore + RestoreNotes/PostLogin | travel test: note restored on next map |
| Player killed mid-conversation orphans it: NPC untalkable, datalinks stall for the map | HXPlayerPawn.uc:13186 uses never-set conPlay | HXFixGameInfo.Killed aborts Game.ConPlay | builds |
| M09 ship explosions 2x/9x too frequent, flinging players | HXMission09.ShipExplosionEffects | pre-gate to stock odds | script loads |
| M10 Chateau commando ambush never fires (missing `!`) | HXMission10.uc:238 | HXFixMission10.Timer | script loads |
| M02 TenderloinSlaughter inverted (counted unconscious) | HXMission02.uc:361 | HXFixMission02.Timer | script loads |
| IsGoalCompleted ignores its argument (M05 respawn gear, M15 goals) | HXMissionScript.uc:1101 | HXFixMission05/15 | script loads |
| Server browser query can runaway-loop and crash the server | HXUdpServerQuery.uc:444 | HXFixUdpServerQuery (ServerActors) | answers \info\ \players\ \status\ |
| Duplicate player names swap/lose travel inventory | HXGameInfo.uc:695 TODO | unique names + client URL update | builds |
| Player dead at map change arrives at 0 HP with no gear | HXGameInfo.AcceptInventory | respawn in AcceptInventory | builds |

## Fixed by the module pass (Sonnet agents, merged + reviewed build)
Modules: HXFixAugsMutator, HXFixPlayerMutator (+36 HXFix*Player subclasses), HXFixDevicesMutator,
HXFixWeaponsMutator; conversation/mission fixes live in HXFixGameInfo, HXFixConPlay, HXFixDataLink*.

- Muscle aug activation (detects the failed activation and completes it, original aug object kept)
- Listen host: NotifyUp only once per connected player; no cinematic camera for remote pawns on the host
- Conversation choices/skips only by the conversation's player (cinematics skippable by anyone)
- Gibbed players leave a lootable body; partly used charged pickups kept on death
- Respawn item farming stripped; carried decoration restored when its carrier disconnects; rename rules
- Security console sees HX cameras; hack lockout/alarm server side; cameras pick any visible player
- Map exits only accept live players, no-transition soft-lock + 90s timeout; keypad double toggle/host block
- Med/repair bot stuck "in use"; out-of-range computer session closed; multi-player proximity toggles
- Late joiners get interpolation paths replayed
- Weapon mod stats replicated to owners; inventory-screen ammo selection; datalink nanokey IDs
- Forced conversations queue instead of killing another player's; queued datalinks fire trigger events;
  deferred datalink stall safety net; first-person conversation credits/persona/transfers
- Flag replication budget for late campaign; M03 JugHead flag; M04 raid fallback; M05 Trigger None
- Listen spectator count leak; startup message on clients
- Team-wide conversation subtitles: players away from a story conversation get the lines as messages

Not fixed: aug screen "Use Cell" for remote clients (screen uses exact-class FindInventoryType; use the
inventory screen or belt instead). 00_TrainingFinal exit carries items (bNoDelete exit not swappable).

## Live test (listen server + client on one PC, HXFixTestSoak)
15 map changes across missions 1-3 with 2 players, no crash, no client errors. Unique names stable across
travel. Known: a client renamed to Name_2 still gets Name_2 saved into its user ini on exit (cosmetic).
Script warnings only when the soak forces travel mid-conversation.

## Out of reach (native HX.dll)
Travel export, PruneCurrent, conform saves, flag replication internals, HXGameEngine. Likely home of the
listen-server crashes; the dev left `//PreExportClean(); // might fix crash issues` at HXPlayerPawn.uc:1789.

## Live-tested pass (2026-10-16)
Each agent area passed its live tests (listen host + real clients, tools/run_live_test.ps1). Extra fixes found
by live testing: client GC crash on travel (HXFixClientCleanup), dead-at-travel respawn, endgame map name
("NOTHING" LocalURL), M10 re-fire, client nanokey lookup (HXFixNanoKeyInfo), deferred forced conversation
dropped (LastConEndTime gate), Use Cell for remote clients (HXFixCellProxy), training exit bItems.
Full merged-build suite (tools/live_suite.txt, tools/run_live_suite.sh): 42/42 PASS on 2026-10-16.
HXFixTestTrigger first failed because the test teleported the remote into a wall; the placement was fixed and it passed 3/3.

## Second pass (2026-10-16)

| Bug | Root cause | Fix | Test |
|---|---|---|---|
| Game crashes when anyone has the inventory screen open during a map change (host too) or when the game exits | `HXPersonaInventoryObjectBelt.DestroyWindow` calls `hudBelt.AssignWinInv(None)` on the belt of a HUD that is already destroyed | `HXFixPersonaInventoryObjectBelt` only calls it while `hudBelt` is still the current HUD's belt; `HXFixPersonaScreenInventory` uses it, for clients and the listen host (`HXFixClientCleanup`) | HXFixTestInvTravel (control run with stock belt: host crashes); HXFixTestChangeAmmo exit |
| Team nanokeys listed twice in the key ring | our earlier datalink fix stored key IDs in the description slots the key ring prints | IDs in their own replicated list (`HXFixNanoKeyInfo.KeyIDs`) | HXFixTestNanoKey "key listed once" |
| Change Ammo on a client showed the wrong ammo and could send a stale pick back to the server | `AmmoName` is never replicated, only `AmmoType` | screen picks the next ammo from `AmmoType` and sends exactly that; `HXFixWeaponSync` keeps the client's `AmmoName` in step | HXFixTestChangeAmmo (key and button, screen matches server) |
| Mission tests "hung" a client and the host | test bug: `MinPlayers=1` let the host finish and quit while the client was still loading | tests wait for the client | HXFixTestMission 3/3 on M02 and M03 |

Launcher now fails a run when a client crashes or hangs on exit, and prints the crash dialog text
(`tools/crash_text.ps1`). Earlier "no crash" claims based on logs were not reliable: a crashing game never flushes its log.

Still open: a client that is still loading a map when the host quits can hang on close (seen only in that race).

