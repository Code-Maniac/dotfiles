# splitrun - run a command with its stderr in a tmux split.
#
#   splitrun [-v|-h] <command> [args...]
#
# stdout stays where you are, so the command behaves normally; stderr goes to a
# new pane. Useful when a build's errors keep scrolling away amongst its output.
#
#   -v  split side by side (default)
#   -h  split top and bottom
#
# Those follow the vim sense of the words, matching the `|` and `-` bindings in
# tmux.conf, and are therefore the opposite way round to tmux's own -h and -v
# flags - which is why the mapping is spelled out rather than passed through.
#
# stderr travels down a fifo rather than being written to the pane's tty: a fifo
# ends when the command closes it, so the reading pane knows the run is over.
splitrun() {
  if [[ -z ${TMUX} ]]; then
    print -u2 "splitrun: not inside tmux"
    return 1
  fi

  local split=-h   # tmux -h is side by side, this function's default -v
  while [[ $1 == -[vh] ]]; do
    [[ $1 == -v ]] && split=-h || split=-v
    shift
  done

  if (( $# == 0 )); then
    print -u2 "usage: splitrun [-v|-h] <command> [args...]"
    return 1
  fi

  local dir
  dir=$(mktemp -d "${TMPDIR:-/tmp}/splitrun.XXXXXX") || return 1
  local fifo=$dir/stderr
  mkfifo $fifo || { rm -rf $dir; return 1 }

  # -d keeps the focus here, where the command is about to run. The pane holds
  # after the stream ends so the errors stay readable rather than closing with
  # the command that produced them.
  local pane
  pane=$(tmux split-window $split -d -P -F '#{pane_id}' \
    "sh -c 'cat ${fifo}; printf \"\\n[stderr ended - enter to close]\"; read _'") || {
    rm -rf $dir
    return 1
  }

  # Opening a fifo for writing blocks until something is reading it, so a pane
  # that failed to start would hang the command rather than failing it.
  local waited=0
  while (( waited < 20 )) && ! tmux list-panes -a -F '#{pane_id}' | grep -qx "$pane"; do
    sleep 0.05
    (( waited++ ))
  done

  # `rc`, not `status`: zsh aliases `status` to `$?`, so a local of that name
  # shadows the special parameter and the exit code is lost.
  "$@" 2>$fifo
  local rc=$?

  rm -rf $dir
  return $rc
}
