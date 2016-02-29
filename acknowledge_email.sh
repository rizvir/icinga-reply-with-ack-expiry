#!/bin/bash
# E-mail acknowledge script 
# by RizviR
# The user under which this script is run (=recipient in maildrop) has to be part of the nagioscmd/icingacmd group

FILE=`cat /dev/stdin`
COMMANDFILE="/usr/local/icinga/var/rw/icinga.cmd"
LOGFILE="/tmp/icinga-email-ack.log"

function writelog {
	echo `date +"%b %d %H:%M:%S"` "$1" >> $LOGFILE
}

function writecommand {
	printf "$1" > $COMMANDFILE
}

# Args: $1 = comment
# Output: variables COMMENT and EXPIRE_STAMP will be changed
function comment2expiry() {
	local EXPIRE_STRING=`echo $COMMENT | sed -e 's/^Expire \([^\.]*\)\..*/\1/g'`
	local EXPIRE_STAMP=`date -d "$EXPIRE_STRING" +%s`
	local RETURN="$?"
	writelog "Expire string: $EXPIRE_STRING"
	writelog "Expire stamp: $EXPIRE_STAMP"
	if [[ $RETURN != 0 ]]; then
		# Error. Write to sender
		writelog "Invalid expiry date. Did not acknowledge."
		echo -e "Icinga did not understand your acknowledgment expiry string\nExamples of valid expiry strings (note the period at the end of the string):\nExpire 2012-02-28 15:20.\nExpire now +2 hours.\nExpire wednesday 13:20.\nExpire tomorrow." | mail -s "Acknowledgement expiry error" $HEADER_FROM
		exit 0
	fi
}


# Create a tmp directory to unpack
TMPDIR=`mktemp -d`
if [ $? != 0 ]; then
	writelog "Could not create temporary directory"
	exit 1
fi

OUTFILE=`mktemp`
if [ $? != 0 ]; then
	writelog "Could not create temporary file"
	exit 1
fi

echo -n "$FILE" | ripmime -i - -d $TMPDIR
# Skip "This is a multi-part message"
cat $TMPDIR/textfile0 | head -n 1 | grep -q "^This is a multi-part message in MIME format."
if [ $? == 0 ]; then
	EMAIL="$TMPDIR/textfile1"
else
	if [ -s $TMPDIR/textfile0 ]; then
		EMAIL="$TMPDIR/textfile0"
	else
		EMAIL="$TMPDIR/textfile1"
	fi
fi

HEADER_FROM=`echo -n "$FILE" | grep -m1 "^From:" | sed 's/.*< *//;s/ *>.*//'`
HEADER_SUBJECT=`echo -n "$FILE" | grep -m1 "^Subject:"`
COMMENT=`head -n1 $EMAIL`

echo "$HEADER_SUBJECT" | grep -q "Host Alert"
if [ $? == 0 ]; then
	# This is a host acknowledgement
	lHOST=`cat $EMAIL | grep "Host: " | sed -e 's/.*Host: \(.*\)/\1/g'`
	now=`date +%s`

	if [[ $COMMENT == Expire* ]]; then
		writelog "Expiry date detected in comment: $COMMENT by $HEADER_FROM"
		# This is an expiry host ack:
		# ACKNOWLEDGE_HOST_PROBLEM_EXPIRE;<host_name>;<sticky>;<notify>;<persistent>;<timestamp>;<author>;<comment>
		comment2expiry "$COMMENT"
		# the above function sets $EXPIRE_STAMP
		writecommand "[%lu] ACKNOWLEDGE_HOST_PROBLEM_EXPIRE;$HOST;0;1;0;$EXPIRE_STAMP;$HEADER_FROM;Acknowledged via email by $HEADER_FROM. $COMMENT"
		writelog "Acknowledged host:$HOST expiry:$EXPIRE_STAMP by:$HEADER_FROM comment:$COMMENT"
	else
		# ACKNOWLEDGE_HOST_PROBLEM;<host_name>;<sticky>;<notify>;<persistent>;<author>;<comment>
		writecommand "[%lu] ACKNOWLEDGE_HOST_PROBLEM;$HOST;0;1;0;$HEADER_FROM;Acknowledged via email by $HEADER_FROM. $COMMENT"
		writelog "Acknowledged host:$HOST by:$HEADER_FROM comment:$COMMENT"
	fi

	rm -f $EMAIL
	rm -rf $TMPDIR

	exit 0
fi

echo $HEADER_SUBJECT | grep -q "PROBLEM"
if [ $? == 0 ]; then
	# This is a service ack
	# this only gives the alias: HOST=`echo $HEADER_SUBJECT | sed -e 's/.*PROBLEM: \(.*\)\/.*/\1/g'`
	HOST=`cat $EMAIL | grep "Host: " | sed -e 's/.*Host: \(.*\)/\1/g'`
	SERVICE=`cat $EMAIL | grep "Service: " | sed -e 's/.*Service: \(.*\)/\1/g'`
	# Format for service acknowledgments is:
	# ACKNOWLEDGE_SVC_PROBLEM;<host_name>;<service_description>;<sticky>;<notify>;<persistent>;<author>;<comment>
	now=`date +%s`

	if [[ $COMMENT == Expire* ]]; then
		writelog "Expiry date detected in comment: $COMMENT by $HEADER_FROM"
		# This is an expiry service ack:
		# ACKNOWLEDGE_SVC_PROBLEM_EXPIRE;<host_name>;<service_description>;<sticky>;<notify>;<persistent>;<timestamp>;<author>;<comment>
		comment2expiry "$COMMENT"
		# the above function sets $EXPIRE_STAMP
		writecommand "[%lu] ACKNOWLEDGE_SVC_PROBLEM_EXPIRE;$HOST;$SERVICE;0;1;0;$EXPIRE_STAMP;$HEADER_FROM;Acknowledged via email by $HEADER_FROM. $COMMENT"
		writelog "Acknowledged host:$HOST service:$SERVICE expiry:$EXPIRE_STAMP by:$HEADER_FROM comment:$COMMENT"
	else
		writecommand "[%lu] ACKNOWLEDGE_SVC_PROBLEM;$HOST;$SERVICE;0;1;0;$HEADER_FROM;Acknowledged via email by $HEADER_FROM. $COMMENT"
		writelog "Acknowledged host:$HOST service:$SERVICE by:$HEADER_FROM comment:$COMMENT"
	fi

	rm -f $EMAIL
	rm -rf $TMPDIR

	exit 0
fi


