# Make containers render the same as the host terminal.
#
# docker forwards neither TERM nor COLORTERM, so anything interactive inside a
# container gets a bare TERM=xterm - 8 colours by terminfo - and no truecolor
# hint. Neovim then leaves termguicolors off and a truecolor theme degrades onto
# the 256 colour cube. Inject the host's values into `exec` and `run` so the
# usual commands keep working unchanged.
#
# TERM is passed through as-is with one exception: outside tmux kitty sets
# TERM=xterm-kitty, and images do not carry that terminfo entry, which leaves
# ncurses programs worse off than before. xterm-256color is the safe stand-in.
# Inside tmux TERM is screen-256color, which images do carry, so it forwards
# unchanged and stays honest about what the far end actually is.
docker() {
  case ${1:-} in
    exec|run)
      local sub=$1
      shift
      local term=${TERM}
      [[ ${term} == xterm-kitty ]] && term=xterm-256color

      # built as an array: zsh does not word-split unquoted expansions, so
      # "-e TERM=$term" written inline reaches docker as a single argument and
      # is read as an env var named " TERM", which silently does nothing.
      local -a envargs
      [[ -n ${term} ]] && envargs+=(-e "TERM=${term}")
      [[ -n ${COLORTERM} ]] && envargs+=(-e "COLORTERM=${COLORTERM}")

      # $TMUX lets nvim's tmux-navigator inside the container drive the tmux
      # server out here, so C-hjkl crosses the boundary. It names a socket
      # path, so the socket directory has to be visible at the same path in
      # the container - mounted below for `run`. A container started any other
      # way needs the same mount adding, or tmux inside it has nothing to talk
      # to. Host and container are both uid 1000, so the socket permissions
      # line up.
      if [[ -n ${TMUX} ]]; then
        envargs+=(-e "TMUX=${TMUX}" -e "TMUX_PANE=${TMUX_PANE}")
        if [[ ${sub} == run ]]; then
          local tmuxdir=${${TMUX%%,*}:h}
          [[ -d ${tmuxdir} ]] && envargs+=(-v "${tmuxdir}:${tmuxdir}")
        fi
      fi

      command docker ${sub} "${envargs[@]}" "$@"
      ;;
    *)
      command docker "$@"
      ;;
  esac
}

# Publish this pane's container and working directory to tmux, so a split taken
# from inside a container can reopen in that container at that directory.
#
# tmux only sees the host side of a `docker exec` pane: #{pane_current_path} is
# the host cwd from before the container was entered, which is why an ordinary
# split lands there. The information has to come from in here.
#
# Needs the tmux socket to be reachable from inside the container, which is the
# -v mount added above. Outside a container the options are cleared, so a pane
# that exits a container stops advertising one and splits go back to normal.
# The socket test matters inside a container: $TMUX can be forwarded in while
# the socket itself is not mounted, and without it every prompt would fork a
# tmux that fails.
if [[ -n ${TMUX} && -S ${TMUX%%,*} ]] && (( $+commands[tmux] )); then
  _docker_publish_pane() {
    local container="" cwd=""
    if [[ -n ${SDKZ_IMAGE_VERSION:-} ]]; then
      # inside a container the hostname is the container id, which is what
      # `docker exec` out on the host needs to reconnect to it
      container=${HOST}
      cwd=$PWD
    fi

    # this runs on every prompt, so only talk to tmux when something changed
    [[ $container == ${_docker_pane_container-} && $cwd == ${_docker_pane_cwd-} ]] && return
    _docker_pane_container=$container
    _docker_pane_cwd=$cwd

    if [[ -n $container ]]; then
      tmux set-option -p @pane_container "$container" 2>/dev/null
      tmux set-option -p @pane_cwd "$cwd" 2>/dev/null
    else
      tmux set-option -up @pane_container 2>/dev/null
      tmux set-option -up @pane_cwd 2>/dev/null
    fi
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _docker_publish_pane
fi
