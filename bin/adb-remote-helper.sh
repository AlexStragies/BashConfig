#!/bin/sh
#╔═══════════════════════════════════════════════════════════════════════════════╗
#║ adb-remote-helper.sh - Connection helper for remote ADB devices via SSH+USB   ║
#╠═══════════════════════════════════════════════════════════════════════════════╣
#║                                                                               ║
#║ Usage: $0 <SSH-Host> [<Optional_ADB_SERIAL>] [<Optional_CMD>]                 ║
#║                                                                               ║
#╟───────────────────────────────────────────────────────────────────────────────╢
#║                                                                               ║
#║ This wrapper will tunnel over SSH an ADB-Client session to a remote device,   ║
#║                                                                               ║
#║ * Depending on the remote ADB version, a different client binary can be       ║
#║     used to avoid an adb version mismatch.                                    ║
#║     These need to be placed as '~/bin/adb-<2-Digit-ADB-Ver>'                  ║
#║     If present, they take precendence over the system-provided binaries.      ║
#║ * If several remote devices are connected, an ADB SERIAL# is required as $2   ║
#║ * If no remote command is specified, 'shell' will be executed.                ║
#║ * ssh gets no parameters apart from hostname($1), so setup '~/.ssh/config'    ║
#║                                                                               ║
#╟───────────────────────────────────────────────────────────────────────────────╢
#║ Author: Alex Stragies                                                         ║
#╚═══════════════════════════════════════════════════════════════════════════════╝

# Check for required first parameter: SSH-Host
[ -z "$1" ] && { echo "ADB-SSH Destination required as \$1"; exit 1; }

# Generate a (hopefully) unique Port-Number to be used for the port-porward
# TODO: Can I use a local socket for this?
Port="3"$(echo $1 | md5sum | tr -d a-z | colrm 5 55)

# Start a remote adb-server
ssh $1 adb start-server     || { echo "Error: Can't contact $1 by SSH";exit 1; }

# Setup port forwarding to the remote adb-server
# TODO: Can I use a local socket for this?
ssh -fNT -L $Port:0:5037 $1 || { echo "Error: Can't contact $1 by SSH";exit 1; }

# Determine remote adb server version
RemAdbVer=$(ssh $1 adb version | sed -n s-^And.*1.0.--p )
shift

# Check, if <Device_Serial>, 'any', or nothing was given as $2
[ ! -z $1 ] && { [ "$1" != "any" ] && DevID="-s $1" || true; } && shift;

# Check, if we have a local binary specific to the remote adb version
[ -e ~/bin/adb-$RemAdbVer ] && AdbExe=~/bin/adb-$RemAdbVer

# Run the final composed command
${AdbExe:-adb} -P $Port $DevID "${@:-shell}"
