# Reaching the host's tmux from inside a container, where its socket cannot be
# bind mounted. Docker Desktop on macOS cannot carry a unix socket across its VM
# boundary, so the socket is bridged over TCP instead: socat publishes it on the
# host, and a second socat inside the container recreates it at the same path.
#
# Only control commands cross the bridge - select-pane, set-option,
# split-window - which is all the tmux integration uses. Attaching passes the
# client's terminal file descriptor over the socket and cannot work over TCP,
# but nothing here attaches.
#
# Sourced from zshrc only where it applies: macOS, inside a container, or when
# DOCKER_TMUX_BRIDGE forces it. The docker wrapper in zsh/docker.zsh uses the
# bridge when this file has defined these functions, and bind mounts otherwise.

: ${DOCKER_TMUX_BRIDGE_PORT:=47291}
# Loopback by default, which is what macOS wants: Docker Desktop forwards
# host.docker.internal to the host's loopback, so nothing is exposed beyond the
# machine. On Linux a container cannot reach the host's loopback, so forcing the
# bridge there needs DOCKER_TMUX_BRIDGE_BIND=0.0.0.0 - which does expose the
# tmux server to the local network, and a tmux socket means running commands in
# your panes. Only worth doing on a trusted network.
: ${DOCKER_TMUX_BRIDGE_BIND:=127.0.0.1}

_tmux_bridge_wanted() {
  [[ -n ${TMUX} ]] || return 1
  (( $+commands[socat] )) || return 1
  [[ ${OSTYPE} == darwin* || -n ${DOCKER_TMUX_BRIDGE:-} ]]
}

# Publishes this session's tmux socket on 127.0.0.1. Idempotent: a probe
# connection decides whether one is already running.
_tmux_bridge_start() {
  local sock=${TMUX%%,*}
  [[ -S ${sock} ]] || return 1
  socat -u /dev/null TCP:127.0.0.1:${DOCKER_TMUX_BRIDGE_PORT} 2>/dev/null && return 0
  socat TCP-LISTEN:${DOCKER_TMUX_BRIDGE_PORT},bind=${DOCKER_TMUX_BRIDGE_BIND},reuseaddr,fork \
    UNIX-CONNECT:${sock} >/dev/null 2>&1 &!
  return 0
}


# Inside a container whose tmux socket is bridged rather than mounted, recreate
# the socket at the path $TMUX names by proxying it to the host's bridge. Runs
# before the publish hook below, which checks for that socket.
if [[ -f /.dockerenv && -n ${TMUX} && -n ${DOCKER_TMUX_BRIDGE_PORT:-} ]] && (( $+commands[socat] )); then
  () {
    local sock=${TMUX%%,*}
    [[ -S ${sock} ]] && return
    mkdir -p ${sock:h} 2>/dev/null
    socat UNIX-LISTEN:${sock},fork,unlink-early \
      TCP-CONNECT:${DOCKER_TMUX_BRIDGE_HOST:-host.docker.internal}:${DOCKER_TMUX_BRIDGE_PORT} \
      >/dev/null 2>&1 &!
    # the guard below wants the socket to exist already
    local i
    for i in {1..20}; do
      [[ -S ${sock} ]] && break
      sleep 0.05
    done
  }
fi
