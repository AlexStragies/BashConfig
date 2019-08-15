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
#║ * In the bash profile there is a function to add completions for              ║
#║   * Parameter 1: SSH Hostname - retrieved from '.ssh/config'                  ║
#║   * Parameter 2: Android device serial - retrieved at runtime from adb itself ║
#║                                                                               ║
#║                                                                               ║
#║ Note:                                                                         ║
#║   * This helper is rarely used directly, instead using aliases such as:       ║
#║     alias adb-galaxy-s5="adb-remote-helper.sh mypi 0123456677"                ║
#║     alias adb--mypi="adb-remote-helper.sh mypi any"                           ║
#║   * The bash profile sets up typical completions for 'adb' on all aliases     ║
#║                                                                               ║
#║                                                                               ║
#╟───────────────────────────────────────────────────────────────────────────────╢
#║ Author: Alex Stragies                                                         ║
#╚═══════════════════════════════════════════════════════════════════════════════╝

# Display above documentation when called with '--help', or '-h'
case "$1" in "--help"|"-h") grep    '^#[^ ]........'    $0; exit 1;;
             "--code"|'-c') grep -v '^#[^!]\|^$\|^ *# ' $0; exit 1;; esac

# Check for required first parameter: SSH-Host
[ -z "$1" ] && { echo "ADB-SSH Destination required as \$1"; exit 1; } \
            || { Host=$1 ; shift; }

COMMENT="Starting remote adb server"
ssh $Host adb start-server &&

  COMMENT="Forwarding local Port $Port" &&
  # Generate a (hopefully) unique Port-Number to be used for the port-forward
  # TODO: Can I use a local socket for this?
  Port="3"$(echo $Host | md5sum | tr -d a-z | colrm 5 55) &&
  ssh -fNT -L $Port:0:5037 $Host                          &&

    COMMENT="Determining remote adb server version"          &&
    RemAdbVer="$(ssh $Host adb version)"                     &&
    RemAdbVer=$(echo "$RemAdbVer" | sed -n s-^And.*1.0.--p ) ||

# Here comes the case, where failures from the above will be caught:
{ echo "Error while: $COMMENT"; exit 1; }

# Check, if we have a local binary specific to the remote adb version
[ -e ~/bin/adb-$RemAdbVer ] && AdbExe=~/bin/adb-$RemAdbVer

# Check, if <Device_Serial>, 'any', or nothing was given as next parameter
[ ! -z $1 ] && { [ "$1" != "any" ] && DevID="-s $1" || true; } && shift;

# Run the final composed command
exec ${AdbExe:-adb} -P $Port $DevID "${@:-shell}"
