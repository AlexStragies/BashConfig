#!/bin/bash
TERM=screen-256color

DEBUG='y' # My Debug Variable
DefaultSessionName='rlx'
NestConf="$HOME/.tmux.nested.conf"

showRun(){ echo $1; shift;
           echo Will run: exec $@;
           test -z $DEBUG || read -n1 -p"Press ENTER";
           exec $@; }

while [ ! -z $1 ] ; do
  case $1 in
    (n|-n) NestMaster='y' ; shift   ;;
    (s)    SNAME=$2       ; shift 2 ;;
    (w)    WNAME=$2       ; shift 2 ;;
    (+d)   DEBUG="y"      ; shift   ;;
    (-d)   unset DEBUG    ; shift   ;;
    (*)    break                    ;;
  esac
done

SNAME=${SNAME:-rlx}
test -z $NestMaster || { TMXOPTS="$TMXOPTS -f $NestConf";
                         SNAME="NEST$SNAME"; unset TMUX; }
TMXOPTS="$TMXOPTS -L $SNAME"
SSNAME="Session $SNAME"
TMX="tmux $TMXOPTS"
TMXNEW="$TMX new-session"
TMXATT="$TMX attach"
TMXOP="new-window $1"

#if ! tmux has -t $SNAME; then
if ! $TMX has -t $SNAME; then
	showRun "$SSNAME not found, creating it: " $TMXNEW -s $SNAME;
else
	echo -n "$SSNAME found: "
	MySESSION=$($TMX ls | grep -E "^$SNAME:.*\(attached\)$")
	echo $MySESSION;
	if [ -z "$MySESSION" ] ; then
		showRun "$SSNAME unattached, seizing it:" $TMXATT -t $SNAME \; $TMXOP
	else
		echo "$SSNAME already attached, finding grouped Sessions:"
		REGEX="group ([^)]*)"
		[[ $MySESSION =~ $REGEX ]]
		GNAME=${BASH_REMATCH[1]}
		GSESSIONS=$($TMUX ls | grep "group $GNAME)" | grep -v $SNAME:)
		echo "$GSESSIONS"
		if [ -z "$GSESSIONS" ]; then
			showRun "No sessions in group with $SNAME found, creating new one:" \
			        $TMXNEW -t $SNAME \; $TMXOP
		else
			FGSESSIONS=$(echo "$GSESSIONS" | grep -v attached )
			if [ -z "$FGSESSIONS" ]; then
				showRun "No free sessions in group $GNAME found, creating new one:" \
				        $TMXNEW -t $SNAME \; $TMXOP
			else
				echo -e "Free grouped Sessions:\n $FGSESSIONS";
				if echo "$FGSESSIONS" | tail -n +2 | grep . > /dev/null; then
					echo "Several detached Sessions found, cleaning up:"
					echo "$FGSESSIONS" | while read SID x ; do
						if [ -z $KEEPSID ]; then
							KEEPSID=${SID%:*};
							echo "Keeping session $KEEPSID for takeover after cleanup"
						else
							echo "Cleaning up old detached session $SID"
							$TMUX kill-session -t ${SID%:}
						fi;
					done
					KEEPSID=$($TMUX ls|grep "group $GNAME)" | grep -v attached);
					KEEPSID=${KEEPSID%: *}
					showRun "Attaching to session $KEEPSID:" \
					        $TMXATT -t $KEEPSID \; $TMXOP
				else
					showRun "Free session ( ${FGSESSIONS%: *} ) found, seizing it:" \
					        $TMXATT -t ${FGSESSIONS%: *} \; $TMXOP
				fi ;
			fi ;
		fi ;
	fi ;
fi
