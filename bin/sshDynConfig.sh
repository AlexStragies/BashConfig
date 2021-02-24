#!/bin/sh

# The purpose of ths file is to be included in a `match exec` statement near
# the beginning of the `~/.ssh/config`. It generates needed ssh configuration
# on the fly in some circumstances, e.g. for "dynamic" hostnames.

# To use, insert these 3 lines before the "host *" defaults section:
###############################################################################
#Match !final exec "~/.ssh/dyncfg.sh %n"
#        Include cfgtmp_late_*
#Match !final exec "find ~/.ssh -maxdepth 1 -type f -name cfgtmp_late_%n -delete"
###############################################################################
# These lines call this script to create dynamic config, if needed,
# then read it, and finally delete it:

# Then manually call this script once after every update with $1 '--install':
# TODO put this in a post-git-pull hook of some sort
SOURCEURL="github.com/AlexStragies/BashConfig/tree/master/bin/sshDynConfig.sh" # For --install
test "$1" = '--install' && sed -e '1s|.*|&\n# Minified, full: '$SOURCEURL'|' \
  -e '1,2p;/^ *#\|^$\|--install/d;s/ \+# .*//' $0 > ~/.ssh/dyncfg.sh && exit 0; 

# Dynamic ssh configuration enables a few neat tricks:
# * This avoids many repettitive lines in config
# * 
# TODO document this more

# Debug stuff, will be deleted after the script is "complete"
echo -n "PPID: $PPID : " >> /tmp/logfilessh
cat /proc/$PPID/cmdline | tr '\0' ' ' >> /tmp/logfilessh
echo "" >> /tmp/logfilessh
env >> /tmp/logfilessh

H=$1 # Hostname given as first parameter

case $H in (*---*) # An Alias
  # Aliases are semanticly inert, but correct ssh_config syntax
  #  -> This means, they show up in your tab-completions for `ssh`!
  # Host aliasdef some---name real.hostname--method--value
  # Example for running an adb remote command to a specifc device id:
  # Host aliasdef acme---tablet livingroom.home--adb--8370edaf345
  T=$(sed -n "s/^Host aliasDef $H *//p" ~/.ssh/config*) # Attempt to lookup
  test -n "$T" && H="$T" # If alias was found, use expanded "hostname"
  ;;
esac

echo "H: $H"
CMD=${H#*--} # Attempt to extract command and args from hostname, if given
echo "CMD: $CMD"

# Todo: make following `test` call "better"
if test -n "$CMD" -a "$H" != "$CMD"; then   # If embedded command is found
  case $CMD in (*--*)                       # Command has Parameters!
    # TODO: Make the next few lines "better"
    PARMS=${CMD#*--} CMD=${CMD%%--*};       # Extract up to 4 Parameters
    echo "PARMS: $PARMS"
    P1=${PARMS%%--*} PARMS=${PARMS#*--} P2=${PARMS%%--*} PARMS=${PARMS#*--}
    P3=${PARMS%%--*} PARMS=${PARMS#*--} P4=${PARMS%%--*} PARMS=${PARMS#*--}
    echo "P1: $P1 P2: $P2 P3: $P3" ;
    test "$P4" = "$P3" && P4=""
    test "$P3" = "$P2" && P3=""
    test "$P2" = "$P1" && P2=""
  esac
  H=${H%%--*}               # Extract hostname part from compound spec
  O="\tHostName $H\n"       # This gets written into the temp config fragment
  O="$O\tHostKeyAlias $H\n"
  case $CMD in
    # Android Devices: Uses remote adb command to connect to android devices
    # Parameters: 1(optional): Android Device ID, default is any/first device
    # TODO: enable other commands as `shell` with P2
    adb)
      if test -z "$P1";
        then O="$O\tRemoteCommand adb        \${LC_ADB_CMD:-shell}\n";
	else O="$O\tRemoteCommand adb -s $P1 \${LC_ADB_CMD:-shell}\n"
      fi
      O="$O\tSendEnv LC_ADB_CMD\n"
      ;;
    # Serial ports: Uses remote `cu` command to connect
    # Parameters: 1(optional): DeviceName /dev/tty$2, default "S0"
    #             2(optional): Speed/100, $1 is then not optional, default 1152
    # TODO: change cu command to runtime detection of available methods
    ser)
      if test -z $P1;
        then O="$O\tSetEnv LC_SER_PORT=/dev/ttyS0\n"
        else O="$O\tSetEnv LC_SER_PORT=/dev/tty$P1\n"
      fi
      if test -z $P2;
        then O="$O\tSetEnv LC_SER_SPEED=115200\n"
        else O="$O\tSetEnv LC_SER_SPEED=${P2}00\n"
      fi
      O="$O\tRemoteCommand cu -l \$LC_SER_PORT \$LC_SER_SPEED\n"
      ;;
    # tmux: attempt to find or create a tmux session to attach to
    # TODO. Sessionname as parameter
    tmux)
      O="$O\tRemoteCommand tmux has-session && tmux attach-session || tmux\n"
      ;;
    # IMPI TODO
    ipmi)
      O="$O\tRemoteCommand IPMICOMMAND TODO\n"
      ;;
  esac
  O="$O\tRequestTTY force\n"
fi

CFGSTART="Match originalhost $1\n"
CFGSTART="Host $1\n"
BUF=""

# Check for dedicated ssh keys per destination (sub)domains:
# This will prioritze long hostname matches, then ED25519 keys over RSA
while test "$H" != "$P" ; do # Each following loop pass will chop dotted part.
  test -e "~/.ssh/cfg_$H" && BUF1="${BUF1}Include cfg_$H\n";
  K=ed25519 F=id_$K.$H;
  test -e "$HOME/.ssh/$F.pub" && BUF2="$BUF2\tIdentityFile $HOME/.ssh/$F\n" ;
  K=rsa F=id_$K.$H;
  test -e "$HOME/.ssh/$F.pub" && BUF2="$BUF2\tIdentityFile $HOME/.ssh/$F\n" ;
  P=$H H="${H#*.}";
done

test -n "$BUF1" && BUF="$BUF1"
test -n "$BUF2" -o -n "$O" && BUF="${BUF}$CFGSTART$O$BUF2"

# The following line seems to have bugs
test -n "$BUF" && { echo "$BUF" > ~/.ssh/cfgtmp_late_$1; echo "$BUF"; }  || exit 1

