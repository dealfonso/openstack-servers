#!/bin/bash
OS_CREDENTIALS_FILE=/root/admin-openrc
LOGFILE=/var/log/openstack-servers.log
SERVERS_FILE_PATTERN="/var/log/openstack-servers/openstack-servers"
CONFIG_FILE="/etc/openstack-servers.conf"
MINUTES_BETWEEN_CHECKS=10
ONE_SHOT=false
VERSION=1.0.0

function usage {
	cat <<EOF
Usage: $0 [options]

Options:
	-h, --help			show this help
	-v, --version		show the version
	-l, --log-file		sets the file where to log
	-f, --os-credentials-file
						OpenStack credentials file to be read
	-c, --config		configuration file
	-V, --verbose		verbose mode
	-i, --interval		interval between checks (in minutes)
	-S, --one-shot		one shot mode (run once and exit; implies verbose mode)
EOF
}

function p_info {
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$@"
        echo "$TS - [info] - $OUTPUT"
        [ "$LOGFILE" != "" ] && echo "$TS - [info] - $OUTPUT" >> "$LOGFILE"
}

function p_error {
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$@"
        echo "$TS - [error] - $OUTPUT" >&2
        [ "$LOGFILE" != "" ] && echo "$TS - [error] - $OUTPUT" >> "$LOGFILE"
}
function p_warning {
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$@"
        echo "$TS - [warning] - $OUTPUT" >&2
        [ "$LOGFILE" != "" ] && echo "$TS - [error] - $OUTPUT" >> "$LOGFILE"
}
function p_debug {
        [ "$DEBUG" == "" ] && return 0
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$@"
        echo "$TS - [debug] - $OUTPUT" >&2
        [ "$LOGFILE" != "" ] && echo "$TS - [debug] - $OUTPUT" >> "$LOGFILE"
}

function p_debug_in {
        [ "$DEBUG" == "" ] && return 0
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$(cat - 2>&1)"
        [ "$OUTPUT" == "" ] && return 0
        echo "$TS - [debug] - $OUTPUT" >&2
        [ "$LOGFILE" != "" ] && echo "$TS - [debug] - $OUTPUT" >> "$LOGFILE"
}

function p_error_in {
        local TS=$(date +%F_%T | tr ':' '.')
        local OUTPUT="$(cat - 2>&1)"
        [ "$OUTPUT" == "" ] && return 0
        echo "$TS - [error] - $OUTPUT" >&2
        [ "$LOGFILE" != "" ] && echo "$TS - [error] - $OUTPUT" >> "$LOGFILE"
}
function p_exit {
	local OUTPUT="$1"
	echo "$OUTPUT" >&2
	exit 1
}
function source_file {
	local FILENAME="$1"
	if [ "$FILENAME" == "" ]; then
		p_warning "missing filename"
		return 1
	fi
	if [ ! -e "$FILENAME" ]; then
		p_warning "file \"$FILENAME\" does not exist"
		return 1
	fi
	. "$FILENAME"
	return $?
}

while [ $# -gt 0 ]; do
	case $1 in
		-h|--help)	usage
				exit 0;;
		-v|--version)	echo "$VERSION"
				exit 0;;
		-l|--log-file)	shift
				LOG_FILE="$1";;
		-f|--os-credentials-file)
				shift
				OS_CREDENTIALS_FILE="$1";;
		-c|--config)
				shift
				CONFIG_FILE="$1";;
		-V|--verbose)	DEBUG=1;;
		-i|--internal)	shift
				MINUTES_BETWEEN_CHECKS="$1";;
		-S|--one-shot)	ONE_SHOT=true;;
		*)		p_error "invalid parameter $1"
				exit 1;;
	esac
	shift
done

source_file "$OS_CREDENTIALS_FILE" || p_exit "failed to load credentials file"
source_file "$CONFIG_FILE"

if ! [[ "$MINUTES_BETWEEN_CHECKS" =~ ^[0-9]+$ ]]; then
        echo "internval between checks must be a number"
        exit 1
fi
				
function execute() {
	local TIMESTAMP="$(date +%F_%T | tr -d ':')"
	local CONTROL_FILE="$SERVERS_FILE_PATTERN.csv"
	local DIFFERENT_FILE="$SERVERS_FILE_PATTERN.$TIMESTAMP.csv"

	p_debug "getting the list of servers"
	local SERVERS="$(openstack server list --all-projects -f csv | tail -n +2)"

	if [ $? -ne 0 ]; then
		p_error "failed to get the list of servers"
		return 1
	fi
	p_debug "servers:
$SERVERS"

	local NEED_WRITE=
	if [ ! -e "$CONTROL_FILE" ]; then
        	NEED_WRITE=true
		p_debug "first control file"
	        echo "$SERVERS" > "$DIFFERENT_FILE"
	else
        	if ! diff -q "$CONTROL_FILE" - <<<"$SERVERS" >/dev/null 2>/dev/null; then
			p_debug "differences detected"
                	cp "$CONTROL_FILE" "$DIFFERENT_FILE"
	                NEED_WRITE=true
        	fi
	fi

	[ "$NEED_WRITE" == "true" ] && echo "$SERVERS" > "$CONTROL_FILE"
}

if [ "$ONE_SHOT" == "true" ]; then
	DEBUG=true
	execute
	exit $?
fi

SLEEP_TIME=$((MINUTES_BETWEEN_CHECKS*60))

p_info "starting to monitor the servers"
while true; do
	execute
	p_debug "sleeping $MINUTES_BETWEEN_CHECKS minutes"
	sleep $SLEEP_TIME
done
