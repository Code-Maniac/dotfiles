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

      command docker ${sub} "${envargs[@]}" "$@"
      ;;
    *)
      command docker "$@"
      ;;
  esac
}
