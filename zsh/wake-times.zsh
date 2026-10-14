# check-start / check-week - when the machine started and stopped each day: woke
# from sleep or booted, and went to sleep or shut down. Taken from the journal -
# the kernel's "PM: suspend exit" and "PM: suspend entry" lines, and the boots.
# Sourced from zshrc.

# Every wake, sleep, boot and shutdown from one date up to (not including)
# another, one per line as "<date>T<time> <wake|sleep|boot|shutdown>" in local
# time - so a day's can be picked out by prefix and put in order by sorting.
_power_events() {
  local from=$1 until=$2

  local line stamp
  for line in "${(@f)$(journalctl --since $from --until $until -o short-iso \
      | grep -E 'PM: suspend (entry|exit)')}"; do
    [[ -z $line ]] && continue
    stamp=${line%% *}
    stamp=${stamp%[+-]??:??}
    [[ $line == *'suspend exit'* ]] && print "$stamp wake" || print "$stamp sleep"
  done

  # Each boot's start and shutdown, in microseconds. The shutdown is its last
  # journal entry - except for the current boot, whose last entry is just now.
  # Its first entry is no good for the start: everything logged in the first few
  # seconds, until the switch from the initrd, is stamped before the clock is
  # corrected - an hour out on this machine. A message from well after that
  # (100s, 9 digits of microseconds), less how long the system had been up when
  # it was logged, gives the real start. That is too soon for it to have slept,
  # which uptime here would not count.
  local since=$(( $(date -d $from +%s) * 1000000 ))
  local boot index final early realtime monotonic
  for boot in ${(f)"$(journalctl --list-boots -o json \
      | grep -oE '"index":-?[0-9]+,"boot_id":"[0-9a-f]+","first_entry":[0-9]+,"last_entry":[0-9]+')"}; do
    local -a fields=(${(s:,:)boot})
    index=${fields[1]#*:}
    final=${fields[4]#*:}
    # Over before the period began, so it cannot touch any day in it
    (( index != 0 && final < since )) && continue

    early=$(journalctl -b $index -o json --no-pager | grep -m1 -E '"__MONOTONIC_TIMESTAMP":"[0-9]{9,}"')
    realtime=${${early#*\"__REALTIME_TIMESTAMP\":\"}%%\"*}
    monotonic=${${early#*\"__MONOTONIC_TIMESTAMP\":\"}%%\"*}
    print "$(date -d @$(( (realtime - monotonic) / 1000000 )) +%FT%T) boot"
    if (( index != 0 )); then
      print "$(date -d @$(( final / 1000000 )) +%FT%T) shutdown"
    fi
  done
}

# Prints e.g. 08:50:35 - when the machine first woke from sleep or booted today,
# whichever came first.
check-start() {
  local today=$(date +%F)
  local -a starts
  starts=(${(o)${(M)${(f)"$(_power_events $today $(date -d tomorrow +%F))"}:#${today}T* (wake|boot)}})

  if (( ! ${#starts} )); then
    print -u2 "check-start: no wake from sleep or boot today in the journal"
    return 1
  fi

  print ${${starts[1]%% *}#*T}
}

# Each day of a week, as
#   Monday: <start> - <end>
# where a day starts at its first wake from sleep or boot, whichever came first,
# and ends at its last sleep or shutdown, whichever came last. A day with none of
# these - not used, or older than the journal goes back - shows as None.
# `check-week` is this week, Monday to today, with today ending at the current
# time. `check-week n` is n weeks ago, Monday to Sunday. Reads the whole journal
# rather than only the current boot, as a week may span a reboot.
check-week() {
  local weeks=${1:-0}
  if [[ $weeks != <-> ]]; then
    print -u2 "usage: check-week [weeks ago]"
    return 1
  fi

  local today=$(date +%F)
  local day=$(date -d "today - $(( $(date +%u) - 1 + weeks * 7 )) days" +%F)
  local last=$today
  (( weeks > 0 )) && last=$(date -d "$day + 6 days" +%F)

  local -a events
  events=(${(f)"$(_power_events $day $(date -d "$last + 1 day" +%F))"})

  local -a starts ends
  local start end
  while [[ ! $day > $last ]]; do
    starts=(${(o)${(M)events:#${day}T* (wake|boot)}})
    ends=(${(o)${(M)events:#${day}T* (sleep|shutdown)}})

    if [[ $day != $today ]] && (( ! ${#starts} && ! ${#ends} )); then
      print "$(date -d $day +%A): None"
    else
      start='?'
      (( ${#starts} )) && start=${${starts[1]%% *}#*T}

      if [[ $day == $today ]]; then
        end=$(date +%T)
      else
        end='?'
        (( ${#ends} )) && end=${${ends[-1]%% *}#*T}
      fi

      print "$(date -d $day +%A): $start - $end"
    fi
    day=$(date -d "$day + 1 day" +%F)
  done
}
