#! /usr/bin/env bash

: "${CURL:=curl}";
: "${PS:=ps}";
: "${GREP:=grep}";
: "${BC:=bc}";

: "${DIAL_ID:=4C0028000650564139323920}";
: "${HUB_KEY:=cTpAWYuRpA2zx75Yh961Cg}";
: "${BASE_URL:=http://localhost:5340}";
: "${SLEEP_SECONDS=0.3}";


# Round a float to an integer
round() {
  if [[ "$#" -gt 0 ]]; then
    while [[ "$#" -gt 0 ]]; do
      printf '%.*f\n' 0 "$1";
      shift;
    done
  else
    local x;
    while read -r x; do
      printf '%.*f\n' 0 "$x";
    done
  fi
}


# Sum a set of integers
sum() {
  local _eqn="0";
  if [[ "$#" -gt 0 ]]; then
    while [[ "$#" -gt 0 ]]; do
      _eqn="$_eqn + $1";
      shift;
    done
  else
    while read -r x; do
      _eqn="$_eqn + $x";
    done
  fi
  echo "$_eqn"|$BC -l;
}


# Returns CPU Load as a percentage
get_cpu_load() {
  $PS -eo pcpu|$GREP -v '^\(%CPU\| 0.0\)$'|sum|round;
}

set_cpu_load() {
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
set_cpu_backlight() {
  local -i brightness="${1:-20}";
  $CURL -X GET "$BASE_URL/api/v0/dial/$DIAL_ID/backlight?key=$HUB_KEY&\
red=$brightness&blue=$brightness&green=$brightness";
  echo '' >&2;
}


declare -i prev=0;
declare -i percent;

set_cpu_load 0;
set_cpu_backlight;

while :; do
  percent="$( get_cpu_load; )";
  if [[ "$percent" -ne "$prev" ]]; then
    set_cpu_load "$percent";
  fi
  prev="$percent";
  sleep "${SLEEP_SECONDS}s";
done
