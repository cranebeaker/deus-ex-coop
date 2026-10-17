Deus Ex co-op (HX + HXFix + HXCoop)
====================================

Play the whole Deus Ex campaign together. HX is the Deus Ex co-op mod by
Sebastian Kaufel (Hanfling); its last build, 0.9.89.4, is downloaded from his
build server during install. HXFix fixes many of its co-op bugs (see
CHANGES.txt). HXCoop connects players through Steam, so nobody needs an IP
address or port forwarding.

You need Deus Ex: Game of the Year Edition (Steam or GOG) and Steam running.

INSTALL (everyone)
  1. Unzip anywhere.
  2. Run Install.bat. It finds Deus Ex by itself (or asks for the folder),
     downloads HX, and adds a "Deus Ex Co-op" shortcut to your desktop.

PLAY
  Host:  open "Deus Ex Co-op", press 1. The game starts on Liberty Island.
  Join:  open "Deus Ex Co-op", press 2. It finds the Steam friend who is
         hosting and starts the game connected to them.
  Continue: open "Deus Ex Co-op", press 3. The game saves by itself when your
         group enters a new map (and the host can type CoopSave in the
         console). Continue starts the host on the last saved map with
         everyone's items, skills, notes, goals and story progress.
  Keep the small HXCoop window open while you play. Close the game to stop.
  Steam shows you as "playing Spacewar": that is normal, it is how the
  connection is made.

WITHOUT STEAM (fallback)
  In Deus Ex\System: "Host Co-op (IP).bat", "Join Co-op (IP).bat" and
  "Continue Co-op (IP).bat".
  The host must forward UDP ports 7790-7792 on their router, or everyone joins
  the same VPN (Tailscale, ZeroTier, Radmin VPN) and uses the host's VPN IP.

PROBLEMS
  "Steam is not running": start Steam and log in first.
  Wrong resolution or fullscreen issues: press Alt+Enter, or change it in the
  game's settings.
  Known issues and the source code: see the project page on GitHub.
