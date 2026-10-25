<#
Portal Reloaded LAN co-op launcher.

Works around the Portal 2 engine bug that drops Steam co-op after ~2 minutes
(https://github.com/ValveSoftware/portal2/issues/471) by connecting the two PCs
directly over the home network with sv_lan 1, so Steam never carries the game.

Run it on both PCs. The first PC to run it hosts; the second finds the host on
the network and joins. Override with -Mode Host / -Mode Join [-HostIP x.x.x.x].
#>
param(
    [ValidateSet('Auto', 'Host', 'Join')][string]$Mode = 'Auto',
    [string]$HostIP,
    [string]$Map = 'mp_coop_start'
)
$ErrorActionPreference = 'Stop'
$AppId = 1255980
trap { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

function Find-Game {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = "${env:ProgramFiles(x86)}\Steam" }
    $steam = $steam -replace '/', '\'
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $libs += Select-String $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in $libs | Select-Object -Unique) {
        $acf = Join-Path $lib "steamapps\appmanifest_$AppId.acf"
        if (-not (Test-Path $acf)) { continue }
        $dir = (Select-String $acf -Pattern '"installdir"\s+"([^"]+)"').Matches[0].Groups[1].Value
        $game = Join-Path $lib "steamapps\common\$dir"
        if (Test-Path "$game\portal2.exe") { return [pscustomobject]@{ Steam = $steam; Game = $game } }
    }
    throw "Portal Reloaded not found in any Steam library. Is it installed?"
}

function Get-BroadcastAddresses {
    $out = @('255.255.255.255')
    foreach ($a in Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue) {
        if ($a.IPAddress -like '127.*' -or $a.IPAddress -like '169.254.*' -or $a.PrefixLength -ge 31) { continue }
        $ip = [Net.IPAddress]::Parse($a.IPAddress).GetAddressBytes()
        $out += (0..3 | ForEach-Object {
            $bits = [Math]::Max(0, [Math]::Min(8, $a.PrefixLength - 8 * $_))
            $ip[$_] -bor ((0xFF -shr $bits) -band 0xFF)
        }) -join '.'
    }
    $out | Select-Object -Unique
}

# Asks the network for Source servers (A2S_INFO) and returns Portal Reloaded ones.
function Find-Hosts([int]$TimeoutMs = 3000) {
    $udp = New-Object Net.Sockets.UdpClient
    $udp.EnableBroadcast = $true
    $udp.Client.ReceiveTimeout = 500
    $query = [byte[]](0xFF, 0xFF, 0xFF, 0xFF, 0x54) + [Text.Encoding]::ASCII.GetBytes('Source Engine Query') + [byte[]](0)
    foreach ($b in Get-BroadcastAddresses) {
        try { [void]$udp.Send($query, $query.Length, (New-Object Net.IPEndPoint ([Net.IPAddress]::Parse($b)), 27015)) } catch {}
    }
    $found = @{}
    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    while ((Get-Date) -lt $deadline) {
        $from = New-Object Net.IPEndPoint ([Net.IPAddress]::Any), 0
        try { $r = $udp.Receive([ref]$from) } catch { continue }
        if ($r.Length -lt 6) { continue }
        if ($r[4] -eq 0x41) {
            # Server wants the challenge echoed back before it answers.
            $q = $query + $r[5..8]; [void]$udp.Send($q, $q.Length, $from); continue
        }
        if ($r[4] -ne 0x49) { continue }
        $s = [Text.Encoding]::UTF8.GetString($r, 6, $r.Length - 6).Split([char]0)
        if ($s[2] -eq 'portalreloaded') {
            $found[$from.Address.ToString()] = [pscustomobject]@{ IP = $from.Address.ToString(); Name = $s[0]; Map = $s[1] }
        }
    }
    $udp.Close()
    $found.Values
}

function Test-FirewallRule($exe) {
    $rules = (netsh advfirewall firewall show rule name=all dir=in verbose) -join "`n"
    foreach ($block in $rules -split '(?=Rule Name:)') {
        if ($block -match [regex]::Escape($exe) -and $block -match 'Action:\s+Allow' -and $block -match 'Enabled:\s+Yes' -and $block -match 'Protocol:\s+(UDP|Any)') { return $true }
    }
    $false
}

function Start-Portal($info, [string[]]$gameArgs) {
    $all = @('-applaunch', $AppId, '-condebug') + $gameArgs
    Write-Host "Launching: portal2.exe $($gameArgs -join ' ')" -ForegroundColor DarkGray
    Start-Process (Join-Path $info.Steam 'steam.exe') -ArgumentList $all
}

$info = Find-Game
Write-Host "Portal Reloaded found: $($info.Game)" -ForegroundColor Green

if (Get-Process portal2 -ErrorAction SilentlyContinue) {
    $a = Read-Host 'Portal is already running and has to restart. Close it now? [Y/n]'
    if ($a -match '^[nN]') { return }
    Stop-Process -Name portal2 -Force
    Start-Sleep 3
}

if ($Mode -eq 'Join' -and $HostIP) {
    $target = $HostIP
} else {
    Write-Host 'Looking for a Portal Reloaded host on the network...'
    $hosts = @(Find-Hosts)
    if ($hosts.Count -gt 0) {
        $target = $hosts[0].IP
        Write-Host "Found host $($hosts[0].Name) at $target (map $($hosts[0].Map))" -ForegroundColor Green
    } elseif ($Mode -eq 'Join') {
        throw 'No host found. Start the launcher on the other PC first, or pass -HostIP.'
    }
}

if ($Mode -eq 'Host' -or -not $target) {
    if (-not (Test-FirewallRule (Join-Path $info.Game 'portal2.exe'))) {
        Write-Host 'Windows Firewall has no rule letting the other PC reach Portal on this PC.' -ForegroundColor Yellow
        $a = Read-Host 'Add one now? (asks for admin) [Y/n]'
        if ($a -notmatch '^[nN]') {
            $exe = Join-Path $info.Game 'portal2.exe'
            Start-Process netsh -Verb RunAs -Wait -ArgumentList "advfirewall firewall add rule name=`"Portal Reloaded LAN`" dir=in action=allow program=`"$exe`" protocol=UDP"
        }
    }
    # The cheat cvars stop the host from quitting when no partner has joined within ~10 s.
    Start-Portal $info @('+sv_cheats', '1', '+sv_lan', '1',
        '+mp_wait_for_other_player_notconnecting_timeout', '9999',
        '+mp_wait_for_other_player_timeout', '9999', '+map', $Map)
    Write-Host ''
    Write-Host 'You are the HOST. Once the map has loaded, run this launcher on the other PC.' -ForegroundColor Cyan
} else {
    Start-Portal $info @('+sv_lan', '1', '+connect', $target)
    Write-Host ''
    Write-Host "You are JOINING $target." -ForegroundColor Cyan
}
Write-Host "If something goes wrong, the game log is: $(Join-Path $info.Game 'portalreloaded\console.log')"
