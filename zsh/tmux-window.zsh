# Leaving a window lands on its neighbour rather than window 1.
#
# tmux picks the window it wants when the active one is destroyed, and that is
# window 1 here. Reacting afterwards does not work - by the time pane-exited or
# window-unlinked fires, tmux has already switched away and the closing window's
# index is gone. So this moves first: when the last pane of a window is about to
# exit, select the neighbour, and the window then dies in the background.
#
# The one above by index, falling back to the one below when it was the first.
# Only covers shells exiting normally, which is how windows usually close;
# `prefix &` and kill-window still land wherever tmux decides.
_tmux_select_neighbour_on_exit() {
  [[ -n ${TMUX} && -n ${TMUX_PANE} ]] || return
  (( $+commands[tmux] )) || return

  # a window with other panes in it is not closing
  [[ $(tmux list-panes -t "${TMUX_PANE}" 2>/dev/null | wc -l) -eq 1 ]] || return

  local index
  index=$(tmux display-message -p -t "${TMUX_PANE}" '#{window_index}' 2>/dev/null) || return
  [[ -n ${index} ]] || return

  local -a indices
  indices=(${(f)"$(tmux list-windows -F '#{window_index}' 2>/dev/null)"})
  (( $#indices > 1 )) || return   # the last window: nowhere to go

  local target above below
  for i in ${indices}; do
    (( i < index )) && above=$i
    [[ -z ${below} ]] && (( i > index )) && below=$i
  done

  target=${above:-$below}
  [[ -n ${target} ]] && tmux select-window -t "${target}" 2>/dev/null
}

autoload -Uz add-zsh-hook
add-zsh-hook zshexit _tmux_select_neighbour_on_exit
