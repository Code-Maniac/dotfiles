# Helpers for managing virtualenvs kept together in ~/.venvs.
# Sourced from zshrc. Tab completion for `venv` lives in zsh/completions/_venv.

# activate a venv from ~/.venvs by name, e.g. `venv west`
venv() {
  local root=$HOME/.venvs
  local -a available
  available=($root/*(/N:t))

  if [[ -z $1 ]]; then
    print -u2 "usage: venv <name>"
    print -u2 "available: ${available[*]}"
    return 1
  fi

  local activate=$root/$1/bin/activate
  if [[ ! -f $activate ]]; then
    print -u2 "venv: no venv named '$1' in $root"
    print -u2 "available: ${available[*]}"
    return 1
  fi

  # drop any active venv first so PATH doesn't stack
  (( $+functions[deactivate] )) && deactivate

  source $activate
}

# create a venv in ~/.venvs and activate it, e.g. `venv-new myproj [python3.13]`
# pass -r <requirements.txt> to pip install into it before activating
venv-new() {
  local root=$HOME/.venvs
  local -a reqopt

  # -D strips the parsed options out of $@, -E allows them either side of <name>
  if ! zparseopts -D -E -- r:=reqopt; then
    print -u2 "usage: venv-new [-r requirements.txt] <name> [python]"
    return 1
  fi
  local req=${reqopt[2]}

  if [[ -z $1 ]]; then
    print -u2 "usage: venv-new [-r requirements.txt] <name> [python]"
    return 1
  fi

  # checked before anything is created, so a typo doesn't leave a stray venv
  if [[ -n $req && ! -r $req ]]; then
    print -u2 "venv-new: no such requirements file: $req"
    return 1
  fi

  local target=$root/$1
  if [[ -e $target ]]; then
    print -u2 "venv-new: '$1' already exists — activate it with: venv $1"
    return 1
  fi

  local py=${2:-python3}
  if ! (( $+commands[$py] )) && [[ ! -x $py ]]; then
    print -u2 "venv-new: no such interpreter: $py"
    return 1
  fi

  $py -m venv $target || return 1
  print "created $target ($($target/bin/python --version))"

  if [[ -n $req ]]; then
    print "installing from $req"
    if ! $target/bin/pip install -r $req; then
      print -u2 "venv-new: pip install failed. The venv was kept — fix $req and"
      print -u2 "retry with: venv $1 && pip install -r $req"
      return 1
    fi
  fi

  venv $1
}
