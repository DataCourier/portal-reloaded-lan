# Portal Reloaded LAN co-op launcher

Portal Reloaded co-op over Steam drops after about 2 minutes with a "connection problem"
([Valve bug #471](https://github.com/ValveSoftware/portal2/issues/471), unfixed since 2023).
This launcher connects two PCs on the same home network directly (`sv_lan 1`), so Steam never handles the connection.

Download one file and double-click it. It can go anywhere, like the desktop or Downloads, and needs no setup:
- **Play Portal LAN.cmd**: two PCs on the same home network. It finds the game and the other PC by itself.
- **Play Portal Split.cmd**: split screen on one PC. Player 2 needs a controller. Achievements are off in split screen.

Both files are the same script. The file name decides the mode, so renaming a copy (for example "Play Portal Split (1).cmd" from a second download) still works.

## How to play over LAN
1. Download **Play Portal LAN.cmd** onto both PCs.
2. On the first PC, double-click **Play Portal LAN.cmd**. Nobody is hosting yet, so this PC becomes the host and loads the co-op hub.
3. When the host's map has loaded, double-click **Play Portal LAN.cmd** on the second PC. It finds the host on the network and joins.

Steam still has to be running and logged in on both PCs.

Windows may warn about a downloaded file the first time ("Windows protected your PC"). Click **More info**, then **Run anyway**.

## Options
Run the file from a command prompt with options, or make a shortcut to it and add them to the shortcut's target:
- `-Mode Host`: always host
- `-Mode Join -HostIP 192.168.0.98`: join a specific PC without searching
- `-Mode Split`: split screen, the same as running **Play Portal Split.cmd**
- `-Map mp_coop_pr_cubes`: host a different map (also works for split screen)

An explicit `-Mode` overrides the file name.

## What it does
- The `.cmd` is a batch/PowerShell hybrid: the first few lines start PowerShell, which runs the rest of the same file. Nothing else to install.
- Finds the Portal Reloaded install through Steam's registry key and library folders.
- Looks for a host by sending the standard Source server query (A2S_INFO) as a broadcast on UDP 27015.
  If nothing answers (some firewalls drop replies to a broadcast), it asks every address on the local network directly.
- Host: launches with `+sv_lan 1 +map mp_coop_start`, plus `sv_cheats 1` and long `mp_wait_for_other_player_*` timeouts.
  Without these, the host quits about 10 seconds after loading if no partner has joined.
  Side effect: achievements are disabled for that session.
- Joiner: launches with `+sv_lan 1 +connect <host IP>`.
- On the host, it checks that Windows Firewall lets UDP traffic in to Portal, and offers to add a rule if not.
- Always launches with `-condebug`, so the game log is in `portalreloaded\console.log`.

## Tested
On a single PC (2026-10-25): finding the game, hosting, the host staying up, and being found on the network all work.
The single-file `.cmd` was run on Windows 10 from a folder with a space in its path, with LF line endings as published. Both host mode and "no host found" work, and options are passed through.
Two PCs on a home network (2026-10-25): connected for 30+ minutes across three maps with no drop. Over Steam, the same two PCs dropped after about 2 minutes.
Finding the host works in both directions, including from a PC whose firewall drops broadcast replies (it falls back to asking each address directly).
