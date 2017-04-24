#!/bin/sh

set -o nounset
set -o errexit

DEFAULT_NAGIOS_URL="http://localhost/nagios"
DEFAULT_CMD_FILE="/usr/local/nagios/var/rw/nagios.cmd"
DEFAULT_LIMIT="50"
DEFAULT_SPREAD="60"

SEARCH_URI="/cgi-bin/statusjson.cgi?query=servicelist"

if ! which jq >/dev/null 2>&1; then
    printf "ERROR: The 'jq' command is required but missing\n" >&2
    exit 2
fi

if ! which perl >/dev/null 2>&1; then
    printf "ERROR: The 'perl' command is required but missing\n" >&2
    exit 2
fi

usage() {

    MSG="${1:-}"
    EXIT="${2:-0}"

    if [ ! -z "$MSG" ]; then
        printf "%s\n" "$MSG"
        printf "\n"
        exit $EXIT
    fi
    
    printf '%s' "
USAGE:
  nagios_schedule_check.sh [PARAMETERS]

SYNOPSIS:

  Query nagios for services and schedule forced service checks for the results.
  
  This script must be able to access the /cgi-bin/statusjson.cgi script of your
  nagios installation through your web server.
  
  By default, this script schedules the services it can find via the
  SCHEDULE_FORCED_SVC_CHECK external command, writing directly to the nagios
  command_file (see '-c' below). To disable this and print the generated
  SCHEDULE_FORCED_SVC_CHECK external command lines directly to standard out, use
  the '-p' option.
  
  Status messages (the number of hosts & services found, etc.) are printed to
  standard error.

REQUIRED PARAMETERS:

  One or more of the following is required to perform a search for relevant
  services:

  -s SERVICE_DESCR ... Specify service checks by service description
  -S SERVICE_GROUP ... Specify service checks by service group name
  -o HOST ............ Specify service checks on a specific host
  -O HOST_GROUP ...... Specify service checks on a specific host group

OPTIONAL PARAMETERS:

  -d ................. Enable debugging output
  -h ................. Display usage information
  -l LIMIT ........... Specify the maximum number of services to schedule.
                       The default is $DEFAULT_LIMIT. If more services are
                       found than this limit an error is displayed and the
                       script will exit
  -n ................. Dry-Run. Do not actually submit commands
  -t SECONDS ......... The number of seconds over which to spread the
                       scheduled run times. Defaults to $SPREAD.
  -k ................. Display the path for, and do not delete the retreived
                       JSON search results
  -c COMMAND_FILE .... The path to the nagios command file. Defaults to:
                       $CMD_FILE
  -u URL ............. URL where nagios is installed.
                       Defaults to:
                       $NAGIOS_URL
  -p ................. Print the generated commands to send to the nagios
                       command file instead of writing directly to it

CONFIG FILE:

  Any command-line parameters may be specified one per-line in the file
  '.nagios_schedule_check.conf' in your home directory, for example:

    -u https://nagios.prod.internal/nagios4
    -c /var/spool/nagios/nagios.cmd

DEPENDENCIES:

  The 'jq' utility must be installed, see https://stedolan.github.io/jq/

EXAMPLES:

  Schedule service checks for all services in the 'ssl-cert' service group on
  all hosts, for the nagios installation at
  https://nagios.party-time.net/ops/nagios:

    nagios_schedule_check.sh -u 'https://nagios.party-time.net/ops/nagios' -g ssl-cert

  Schedule service checks for the service 'Processes: Collectd' on all hosts:

    nagios_schedule_check.sh -s 'Processes: Nginx'
 
  Schedule service checks for the all services in the service group
  'dns-resolution' on hosts in the group 'web-servers', spreading them out over
  the next 5 minutes (300 seconds): 

    nagios_schedule_check.sh -S dns-resolution -O web-servers -t 300
 
"

    exit $EXIT
}

nice_date() {
    date "+%Y-%m-%dT%H:%M:%S"
}

printf_debug() {
    if [ -n "$DEBUG" ]; then
        printf '[%s nagios_schedule_check#%d' "$(nice_date)" "$$" >&2
        printf '] ' >&2
        printf "$@" >&2
        printf '\n' >&2
    fi
}

DEBUG=""
DRY_RUN=""
LIMIT="$DEFAULT_LIMIT"
NAGIOS_URL="$DEFAULT_NAGIOS_URL"
CMD_FILE="$DEFAULT_CMD_FILE"
SPREAD="$DEFAULT_SPREAD"
KEEP=""
PRINT=""

QUERY_SERVICE=""
QUERY_SERVICE_GROUP=""
QUERY_HOST=""
QUERY_HOST_GROUP=""

config_from_flag() {
    FLAG="$1"
    OPTARG="${2:-}"
    case "${FLAG#-}" in
        h)  usage ;;
        c)  CMD_FILE="$OPTARG" ;;
        d)  DEBUG="1" ;;
        l)  LIMIT="$OPTARG" ;;
        k)  KEEP="1" ;;
        n)  DRY_RUN="1" ;;
        s)  QUERY_SERVICE="$OPTARG" ;;
        S)  QUERY_SERVICE_GROUP="$OPTARG" ;;
        o)  QUERY_HOST="$OPTARG" ;;
        O)  QUERY_HOST_GROUP="$OPTARG" ;;
        p)  PRINT="1" ;;
        t)  SPREAD="$OPTARG" ;;
        u)  NAGIOS_URL="$OPTARG" ;;
        \?) usage "" 1 ;;
    esac
}

if [ -f ~/.nagios_schedule_check.conf ]; then
    ORIG_IFS="$IFS"
    IFS="
"
    for CONF_LINE in $(cat ~/.nagios_schedule_check.conf | perl -lape 's/^\s+|\s+$//g') ; do
        FLAG="$(printf "%s" "$CONF_LINE" | cut -d' ' -f1)"
        OPTARG="$(printf "%s" "$CONF_LINE" | cut -d' ' -f2-)"
        config_from_flag "$FLAG" "${OPTARG:-}"
    done
    IFS="$ORIG_IFS"
fi

while getopts c:do:O:hkl:nps:S:t:u: FLAG; do
    config_from_flag "$FLAG" "${OPTARG:-}"
done

if [ -z "${QUERY_SERVICE}${QUERY_SERVICE_GROUP}${QUERY_HOST}${QUERY_HOST_GROUP}" ]; then
    printf "WARNING: No query parameters were specified with -s, -S, -o, or -O ... all services will be returned\n" >&2
fi

if [ -z "$PRINT" ]; then
    if [ ! -e "$CMD_FILE" ]; then
        printf "ERROR: The specified nagios command file '%s' does not exist\n" "$CMD_FILE" >&2
        exit 2
    fi

    if [ "$(stat -f %T "$CMD_FILE")" != "|" ]; then
        printf "ERROR: The specified nagios command file '%s' is not a pipe. Make sure to use what is specified by 'command_file' in nagios.cfg\n" "$CMD_FILE" >&2
        exit 2
    fi
fi

printf_debug "Service Group: %s" "$QUERY_SERVICE_GROUP"
printf_debug "Service: %s" "$QUERY_SERVICE"
printf_debug "Host Group: %s" "$QUERY_HOST_GROUP"
printf_debug "Host: %s" "$QUERY_HOST"

if [ -n "$QUERY_SERVICE_GROUP" ]; then
    SEARCH_URI="${SEARCH_URI}&servicegroup=${QUERY_SERVICE_GROUP}"
fi
if [ -n "$QUERY_SERVICE" ]; then
    SEARCH_URI="${SEARCH_URI}&servicedescription=${QUERY_SERVICE}"
fi
if [ -n "$QUERY_HOST_GROUP" ]; then
    SEARCH_URI="${SEARCH_URI}&hostgroup=${QUERY_HOST_GROUP}"
fi
if [ -n "$QUERY_HOST" ]; then
    SEARCH_URI="${SEARCH_URI}&hostname=${QUERY_HOST}"
fi

FULL_URL="${NAGIOS_URL}${SEARCH_URI}"
RESULTS_DIR="$(mktemp -d)"
RESULTS_JSON="${RESULTS_DIR}/servicelist.json"

printf_debug "Full URL: %s" "$FULL_URL"

set +o errexit

curl -s -o "${RESULTS_JSON}" "$FULL_URL"

CURL_EXIT=$?

if [ $CURL_EXIT -ne 0 ]; then
    printf "ERROR: curl failed with exit code %s\n" "$CURL_EXIT" >&2
    exit $CURL_EXIT
fi

set -o errexit

printf_debug "Results json: %s" "$RESULTS_JSON"

if ! (cat "$RESULTS_JSON" | jq 'empty' 2>/dev/null) ; then
    printf "ERROR: The query did not return valid JSON\n" >&2
    printf "URL: %s\n" "$FULL_URL" >&2
    printf "Response:\n" >&2
    cat "$RESULTS_JSON" >&2
    exit 2
fi

RESULT_STATUS="$(cat "${RESULTS_JSON}" | jq -r '.result.type_text')"

if [ "$RESULT_STATUS" != "Success" ]; then
    RESULT_MESSAGE="$(cat "${RESULTS_JSON}" | jq -r '.result.message')"
    printf "ERROR: Query did not return success, message is: %s\n" "$RESULT_MESSAGE" >&2
    exit 2
fi

RESULT_HOST_COUNT="$(cat "${RESULTS_JSON}" | jq -r '.data.servicelist|keys|length')"
LONGEST_HOST_NAME="$(cat "${RESULTS_JSON}" | jq -r '.data.servicelist|keys|map(length)|max')"
RESULT_SERVICE_COUNT="$(cat "${RESULTS_JSON}" | jq -r '.data.servicelist|map(.|keys)|flatten|length')"
LONGEST_SERVICE_NAME="$(cat "${RESULTS_JSON}" | jq -r '.data.servicelist|map(.|keys)|flatten|map(length)|max')"

printf "Found %d services across %d hosts\n" "$RESULT_SERVICE_COUNT" "$RESULT_HOST_COUNT" >&2

if [ "$RESULT_SERVICE_COUNT" -gt "$LIMIT" ]; then
    printf "ERROR: Found %d services, %d more than the allowed limit of %d, specify a different limit with -l\n" "$RESULT_SERVICE_COUNT" "$(( $RESULT_SERVICE_COUNT - $LIMIT ))" "$LIMIT" >&2
    exit 1
fi

if [ "$RESULT_HOST_COUNT" -gt 0 ]; then
    printf_debug "Running through results ..."

    printf "%-$(( LONGEST_HOST_NAME + 4 ))s%-$(( LONGEST_SERVICE_NAME + 4 ))s%s\n" "Host" "Service" "Scheduled Time" >&2

    IFS="
"
    cat "${RESULTS_JSON}" | jq -r '.data.servicelist|keys|.[]' | while read HOST ; do 
        printf_debug "Host: %s" "$HOST"
        cat "${RESULTS_JSON}" | jq -r ".data.servicelist[\"${HOST}\"]|keys|.[]" | while read SERVICE ; do 
            NOW="$(date +%s)"
            RAND_DUR="$(jot -r 1 1 "$SPREAD")"
            TS="$(( NOW + RAND_DUR ))"
            CMD="$(printf "[%d] SCHEDULE_FORCED_SVC_CHECK;%s;%s;%s\n" "$NOW" "$HOST" "$SERVICE" "$TS")"
            printf_debug "    Service: %s" "$SERVICE"
            printf_debug "    Now / Dur / TS: %s / %s / %s" "$NOW" "$RAND_DUR" "$TS"
            printf_debug "    Command: %s" "$CMD"
            printf "%-$(( LONGEST_HOST_NAME + 4 ))s%-$(( LONGEST_SERVICE_NAME + 4 ))s%7s\n" "$HOST" "$SERVICE" "+${RAND_DUR}s" >&2
            if [ -n "$PRINT" ]; then
                printf "%s\n" "$CMD"
            else
                if [ -z "$DRY_RUN" ]; then
                    printf "%s\n" "$CMD" > "$CMD_FILE"
                fi
            fi
        done
    done
fi

if [ -z "$KEEP" ]; then
    rm "$RESULTS_JSON"
    rmdir "$RESULTS_DIR"
else
    printf "Retrieved JSON Search Results: %s\n" "$RESULTS_JSON" >&2
fi
