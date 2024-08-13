#! /usr/bin/env sh

: "${MPSTAT:=mpstat}";
: "${JQ:=jq}";
: "${CURL:=curl}";

: "${DIAL_ID:=4C0028000650564139323920}";
: "${HUB_KEY:=cTpAWYuRpA2zx75Yh961Cg}";
: "${BASE_URL:=http://localhost:5340}";
: "${SLEEP_SECONDS=0.3}";


# Returns CPU Load as a percentage
get_load() {
  printf '%.*f\n' 0                                                            \
    "$( $MPSTAT -o JSON|
          $JQ '.sysstat.hosts[0].statistics[0]["cpu-load"][0]|.usr + .sys'; )";
}

set_percent() {
  case "${1?You must pass a percentage as an integer}" in
    [0-9]|[1-9][0-9]|100) :; ;;
    *)
      echo "You must pass a percentage as an integer}" >&2;
      return 1;
    ;;
  esac
  echo "Setting Dial to $1%" >&2;
  $CURL -X GET "$BASE_URL/api/v0/dial/$DIAL_ID/set?key=$HUB_KEY&value=$1";
  echo '' >&2;
}

# Set to a brightness ( default 20% )
set_backlight() {
  local -i brightness="${1:-20}";
  $CURL -X GET "$BASE_URL/api/v0/dial/$DIAL_ID/backlight?key=$HUB_KEY&\
red=$brightness&blue=$brightness&green=$brightness";
  echo '' >&2;
}


declare -i prev=0;
declare -i percent;

set_percent 0;
set_backlight;

while :; do
  percent="$( get_load; )";
  if [[ "$percent" -ne "$prev" ]]; then
    set_percent "$percent";
  fi
  prev="$percent";
  sleep "${SLEEP_SECONDS}s";
done
