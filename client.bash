#! /usr/bin/env bash
# ============================================================================ #
#
#
#
# ---------------------------------------------------------------------------- #

set -eu;
set -o pipefail;


# ---------------------------------------------------------------------------- #

_as_me="client.bash";

_version="0.1.0";

_usage_msg="USAGE: $_as_me [OPTIONS...] 
VU Client application used to feed system information to digital dials.
";

_help_msg="$_usage_msg


OPTIONS
  -h,--help         Print help message to STDOUT.
  -u,--usage        Print usage message to STDOUT.
  -v,--version      Print version information to STDOUT.

ENVIRONMENT
  BASE_URL          Base URL of Hub unit. ( default: http://localhost:5340 )
  BRIGHTNESS        Brightness level for dial backlights. ( 0-100 default: 20 )
  SLEEP_SECONDS     Number of seconds to wait between updates. ( default: 0.3 )
  HUB_KEY           API key for VU Hub unit. ( default: cTpAWYuRpA2zx75Yh961Cg )
  GREP              Command used as \`grep' executable.
  REALPATH          Command used as \`realpath' executable.
  CURL              Command used as \`curl' executable.
  BC                Command used as \`bc' executable.
  PS                Command used as \`ps' executable.
  NVIDIA_SMI        Command used as \`nvidia-smi' executable.
  SENSORS           Command used as \`sensors' executable.
  JQ                Command used as \`jq' executable.
";


# ---------------------------------------------------------------------------- #

usage() {
  if [[ "${1:-}" = "-f" ]]; then
    echo "$_help_msg";
  else
    echo "$_usage_msg";
  fi
}


# ---------------------------------------------------------------------------- #

# Constants
readonly ID_CPU_LOAD='4C0028000650564139323920';
readonly ID_CPU_TEMP='360044000650564139323920';
readonly ID_GPU_TEMP='1C0028000650564139323920';
readonly ID_RAM_LOAD='75002D000650564139323920';


# ---------------------------------------------------------------------------- #

# Default Options
: "${BASE_URL:=http://localhost:5340}";
: "${HUB_KEY:=cTpAWYuRpA2zx75Yh961Cg}";
: "${BRIGHTNESS:=20}";
: "${SLEEP_SECONDS:=0.3}";


# ---------------------------------------------------------------------------- #

# @BEGIN_INJECT_UTILS@
: "${GREP:=grep}";
: "${REALPATH:=realpath}";
: "${CURL:=curl}";
: "${BC:=bc}";
: "${PS:=ps}";
: "${NVIDIA_SMI:=nvidia-smi}";
: "${SENSORS:=sensors}";
: "${JQ:=jq}";


# ---------------------------------------------------------------------------- #

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    # Split short options such as `-abc' -> `-a -b -c'
    -[^-]?*)
      _arg="$1";
      declare -a _args;
      _args=();
      shift;
      _i=1;
      while [[ "$_i" -lt "${#_arg}" ]]; do
        _args+=( "-${_arg:$_i:1}" );
        _i="$(( _i + 1 ))";
      done
      set -- "${_args[@]}" "$@";
      unset _arg _args _i;
      continue;
    ;;
    --*=*)
      _arg="$1";
      shift;
      set -- "${_arg%%=*}" "${_arg#*=}" "$@";
      unset _arg;
      continue;
    ;;
    -u|--usage)    usage;    exit 0; ;;
    -h|--help)     usage -f; exit 0; ;;
    -v|--version)  echo "$_version"; exit 0; ;;
    --) shift; break; ;;
    -?|--*)
      echo "$_as_me: Unrecognized option: '$1'" >&2;
      usage -f >&2;
      exit 1;
    ;;
    *)
      echo "$_as_me: Unexpected argument(s) '$*'" >&2;
      usage -f >&2;
      exit 1;
    ;;
  esac
  shift;
done


# ---------------------------------------------------------------------------- #

# Round a float to an integer.
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


# ---------------------------------------------------------------------------- #

# Sum a set of integers.
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


# ---------------------------------------------------------------------------- #

# Limit temperatures between 20-100 C and then map them to a 0-100 scale.
temp_to_percent() {
  local -i _temp;
  if [[ "$#" -gt 0 ]]; then
    _temp="$1";
  else
    read -r _temp;
  fi
  local -i _clamped;
  _clamped="$(( _temp - 20 ))";
  if [[ "$_clamped" -gt 80 ]]; then
    _clamped=80;
  fi
  local -i _scaled;
  _scaled="$( $BC <<< "$_clamped * 1.25"|round; )";
  echo "$_scaled";
}


# ---------------------------------------------------------------------------- #

# set_backlight DIAL-ID [PERCENT]
# -------------------------------
# Set to a brightness for a dial.
set_backlight() {
  local -i _brightness;
  _brightness="${2:-$BRIGHTNESS}";
  $CURL -X GET "$BASE_URL/api/v0/dial/$1/backlight?key=$HUB_KEY&\
red=$_brightness&blue=$_brightness&green=$_brightness";
  echo '' >&2;  # Clear STDERR
}


# ---------------------------------------------------------------------------- #

# set_backlight_red DIAL-ID [PERCENT]
# -----------------------------------
# Set to a brightness to the color red for a dial.
set_backlight_red() {
  local -i _brightness;
  _brightness="${2:-$BRIGHTNESS}";
  $CURL -X GET "$BASE_URL/api/v0/dial/$1/backlight?key=$HUB_KEY&\
red=$_brightness&blue=0&green=0";
  echo '' >&2;  # Clear STDERR
}


# ---------------------------------------------------------------------------- #

# set_dial DIAL-ID PERCENT
# ------------------------
# Set a dial's arm to an integer value 0-100.
set_dial() {
  case "${2?You must pass a percentage as an integer}" in
    [0-9]|[1-9][0-9]|100) :; ;;
    *)
      echo "You must pass a percentage as an integer" >&2;
      return 1;
    ;;
  esac
  echo "Setting Dial $1 to $2%" >&2;
  $CURL -X GET "$BASE_URL/api/v0/dial/$1/set?key=$HUB_KEY&value=$2";
  echo '' >&2;
}


# ---------------------------------------------------------------------------- #

# Returns GPU Temperature in Celsius.
get_gpu_temp() {
  $NVIDIA_SMI --query-gpu=temperature.gpu --format=csv,noheader;
}

_prev_gpu_temp=0;
handle_gpu_temp() {
  local -i _percent;
  _percent="$( get_gpu_temp|temp_to_percent; )";
  if [[ "$_prev_gpu_temp" -ne "$_percent" ]]; then
    set_dial "$ID_GPU_TEMP" "$_percent";
    if [[ "$_percent" -ge 90 ]] && [[ "$_prev_gpu_temp" -lt 90 ]]; then
      set_backlight_red "$ID_GPU_TEMP";
    elif [[ "$_percent" -lt 90 ]] && [[ "$_prev_gpu_temp" -ge 90 ]]; then
      set_backlight "$ID_GPU_TEMP";
    elif [[ "$_prev_gpu_temp" -eq 0 ]]; then
      set_backlight "$ID_GPU_TEMP";
    fi
    _prev_gpu_temp="$_percent";
  fi
}


# ---------------------------------------------------------------------------- #

# Returns CPU Temperature in Celsius.
get_cpu_temp() {
  $SENSORS -j|$JQ '.["k10temp-pci-00c3"].Tctl.temp1_input'|round;
}

_prev_cpu_temp=0;
handle_cpu_temp() {
  local -i _percent;
  _percent="$( get_cpu_temp|temp_to_percent; )";
  if [[ "$_prev_cpu_temp" -ne "$_percent" ]]; then
    set_dial "$ID_CPU_TEMP" "$_percent";
    if [[ "$_percent" -ge 90 ]] && [[ "$_prev_cpu_temp" -lt 90 ]]; then
      set_backlight_red "$ID_CPU_TEMP";
    elif [[ "$_percent" -lt 90 ]] && [[ "$_prev_cpu_temp" -ge 90 ]]; then
      set_backlight "$ID_CPU_TEMP";
    elif [[ "$_prev_cpu_temp" -eq 0 ]]; then
      set_backlight "$ID_CPU_TEMP";
    fi
    _prev_cpu_temp="$_percent";
  fi
}


# ---------------------------------------------------------------------------- #

# Returns CPU Load as a percentage
get_cpu_load() {
  $PS -eo pcpu|$GREP -v '^\(%CPU\| 0.0\)$'|sum|round;
}

_prev_cpu_load=0;
handle_cpu_load() {
  local -i _percent;
  _percent="$( get_cpu_load; )";
  if [[ "$_prev_cpu_load" -ne "$_percent" ]]; then
    set_dial "$ID_CPU_LOAD" "$_percent";
    if [[ "$_percent" -ge 90 ]] && [[ "$_prev_cpu_load" -lt 90 ]]; then
      set_backlight_red "$ID_CPU_LOAD";
    elif [[ "$_percent" -lt 90 ]] && [[ "$_prev_cpu_load" -ge 90 ]]; then
      set_backlight "$ID_CPU_LOAD";
    elif [[ "$_prev_cpu_load" -eq 0 ]]; then
      set_backlight "$ID_CPU_LOAD";
    fi
    _prev_cpu_load="$_percent";
  fi
}


# ---------------------------------------------------------------------------- #

# Get RAM usage/load as a percent of total available.
# For my box this represents 0-64Gb but if I upgrade that later all I need to
# do is update the dial's image.
get_ram_percent() {
  local -i _total_kb;
  local -i _avail_kb;
  local -i _used_kb;
  while read -r line; do
    case "$line" in
      MemTotal:*)
        line="${line% kB}";
        _total_kb="${line##* }";
      ;;
      MemFree:*)
        :;
      ;;
      MemAvailable:*)
        line="${line% kB}";
        _avail_kb="${line##* }";
        break;
      ;;
      *) break; ;;  # Unreachable
    esac
  done < /proc/meminfo
  _used_kb="$(( _total_kb - _avail_kb ))";
  $BC -l <<< "$_used_kb / $_total_kb * 100.0"|round;
}

_prev_ram_load=0;
handle_ram_load() {
  local -i _percent;
  _percent="$( get_ram_percent; )";
  if [[ "$_prev_ram_load" -ne "$_percent" ]]; then
    set_dial "$ID_RAM_LOAD" "$_percent";
    if [[ "$_percent" -ge 90 ]] && [[ "$_prev_ram_load" -lt 90 ]]; then
      set_backlight_red "$ID_RAM_LOAD";
    elif [[ "$_percent" -lt 90 ]] && [[ "$_prev_ram_load" -ge 90 ]]; then
      set_backlight "$ID_RAM_LOAD";
    elif [[ "$_prev_ram_load" -eq 0 ]]; then
      set_backlight "$ID_RAM_LOAD";
    fi
    _prev_ram_load="$_percent";
  fi
}


# ---------------------------------------------------------------------------- #

main() {
  while :; do
    handle_cpu_load;
    handle_cpu_temp;
    handle_gpu_temp;
    handle_ram_load;
    sleep "$SLEEP_SECONDS";
  done
}


# ---------------------------------------------------------------------------- #

main;
exit;


# ---------------------------------------------------------------------------- #
#
#
#
# ============================================================================ #
