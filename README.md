# Portal Reloaded LAN co-op launcher

Portal Reloaded co-op over Steam drops after about 2 minutes with a "connection problem"
([Valve bug #471](https://github.com/ValveSoftware/portal2/issues/471), unfixed since 2023).
This launcher connects two PCs on the same home network directly (`sv_lan 1`), so Steam never handles the connection.

It is a single file: **[Play Portal LAN.cmd](Play%20Portal%20LAN.cmd)**. Put it anywhere (the desktop is fine) and double-click it. It finds the game and the other PC by itself.

## How to play
1. Download **Play Portal LAN.cmd** onto both PCs.
2. On the first PC, double-click **Play Portal LAN.cmd**. Nobody is hosting yet, so this PC becomes the host and loads the co-op hub.
3. When the host's map has loaded, double-click **Play Portal LAN.cmd** on the second PC. It finds the host on the network and joins.

Steam still has to be running and logged in on both PCs.

Windows may warn about a downloaded file the first time ("Windows protected your PC"). Click **More info**, then **Run anyway**.

## Options
Run the file from a command prompt with options, or make a shortcut to it and add them to the shortcut's target:
- `-Mode Host`: always host
- `-Mode Join -HostIP 192.168.0.98`: join a specific PC without searching
- `-Map mp_coop_pr_cubes`: host a different map

## What it does
- The `.cmd` is a batch/PowerShell hybrid: the first few lines start PowerShell, which runs the rest of the same file. Nothing else to install.
- Finds the Portal Reloaded install through Steam's registry key and library folders.
- Looks for a host by sending the standard Source server query (A2S_INFO) as a broadcast on UDP 27015.
- Host: launches with `+sv_lan 1 +map mp_coop_start`, plus `sv_cheats 1` and long `mp_wait_for_other_player_*` timeouts.
  Without these, the host quits about 10 seconds after loading if no partner has joined.
  Side effect: achievements are disabled for that session.
- Joiner: launches with `+sv_lan 1 +connect <host IP>`.
- On the host, it checks that Windows Firewall lets UDP traffic in to Portal, and offers to add a rule if not.
- Always launches with `-condebug`, so the game log is in `portalreloaded\console.log`.

## Tested
On a single PC (2026-10-25): finding the game, hosting, the host staying up, and being found on the network all work.
Joining from a second PC and lasting past 2 minutes have not been tested yet.
