# op - Open Project: a new tmux window named after the project, started in it.
#
#   op [--west] [--splits] <name>
#
# On the host the project is ~/projects/<name>, the same place p looks.
#
# Inside the SDKZ container it is a directory under the workspace's apps folder,
# then its modules folder, the first that has one winning. --west instead looks
# the name up amongst every project in the resolved west manifest - zephyr, hal
# modules and the rest, not just the workspace's own apps and modules.
#
# The window is named with -n, which also turns automatic-rename off for it, so
# the name stays the project rather than becoming whatever runs in it. Host
# windows get a 🏠 in front and container windows a 🐳, so the two stand apart in
# the status bar.
#
# --splits lays the window out as the | and - bindings in tmux.conf would: a side
# by side split, then the new right hand pane split top and bottom, all three in
# the project. Focus goes back to the full height pane on the left.
#
# Inside the container the tmux server is the host's, so a window opened with -c
# would start a host shell at a path that only exists in here. Instead the window
# runs `docker exec` back into this container at the project directory, as
# tmux/docker-split -w does. The hostname is the container id, as in docker.zsh.
op() {
  local west=0 splits=0 name=""
  while (( $# )); do
    case $1 in
      --west)   west=1 ;;
      --splits) splits=1 ;;
      -h|--help)
        print "usage: op [--west] [--splits] <name>"
        print "  host       open ~/projects/<name>"
        print "  container  open apps/<name>, else modules/<name>"
        print "  --west     container only: any project in the west manifest"
        print "  --splits   also split the window | and then -"
        return 0
        ;;
      -*) print -u2 "op: unknown option '$1'"; return 1 ;;
      *)  name=$1 ;;
    esac
    shift
  done

  if [[ -z $name ]]; then
    print -u2 "usage: op [--west] [--splits] <name>"
    return 1
  fi
  if [[ -z ${TMUX} ]]; then
    print -u2 "op: not inside tmux"
    return 1
  fi

  # how each pane is started: in the directory on the host, by a command that
  # re-enters the container inside it
  local dir="" label="🏠 $name"
  local -a start
  if [[ -z ${SDKZ_IMAGE_VERSION:-} ]]; then
    if (( west )); then
      print -u2 "op: --west only applies inside the sdkz container"
      return 1
    fi
    dir=~/projects/$name
    if [[ ! -d $dir ]]; then
      print -u2 "op: no such project '$name' in ~/projects"
      return 1
    fi
    start=(-c "$dir")
  else
    if (( west )); then
      # --all so a project that is inactive but cloned is still found; one that
      # was never cloned has no directory, which is reported below.
      local line
      for line in ${(f)"$(west list --all -f '{name} {abspath}' 2>/dev/null)"}; do
        [[ ${line%% *} == $name ]] && { dir=${line#* }; break }
      done
      if [[ -z $dir ]]; then
        print -u2 "op: no project '$name' in the west manifest"
        return 1
      fi
      if [[ ! -d $dir ]]; then
        print -u2 "op: west project '$name' is not cloned at $dir"
        return 1
      fi
    else
      local root
      for root in "$(vt-apps-dir 2>/dev/null)" "$(vt-modules-dir 2>/dev/null)"; do
        [[ -n $root && -d $root/$name ]] && { dir=$root/$name; break }
      done
      if [[ -z $dir ]]; then
        print -u2 "op: no app or module '$name' (try --west for other west projects)"
        return 1
      fi
    fi

    # (q) because tmux hands this string to the host's sh
    label="🐳 $name"
    start=("docker exec -it -e TERM -e COLORTERM -e TMUX -e TMUX_PANE -w ${(q)dir} ${(q)HOST} zsh")
  fi

  # Pane ids rather than relative targets, so each split lands in the pane meant
  # for it whatever the focus is doing in between.
  local main right
  main=$(tmux new-window -P -F '#{pane_id}' -n "$label" $start) || return
  (( splits )) || return 0

  right=$(tmux split-window -h -P -F '#{pane_id}' -t "$main" $start) || return
  tmux split-window -v -t "$right" $start || return
  tmux select-pane -t "$main"
}
