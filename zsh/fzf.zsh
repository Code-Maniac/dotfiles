# if fzf not installed then return
if ! hash fzf &> /dev/null
then
  return
fi

# define functions
function do-fzf {
  (files=$(${FZF_COMMAND})
  if [ "$?" -eq 0 ];
  then
    nvim ${files}
  fi)
}

# define some functions for using fzf
# find is for finding files by name
function fzf-find-files {
  FZF_DEFAULT_COMMAND="rg --files --hidden"
  do-fzf
}

function fzf-find-all-files {
  FZF_DEFAULT_COMMAND="rg --files --hidden --no-ignore"
  do-fzf
}

function fzf-find-git-files {
  if git status &> /dev/null
  then
    toplevelabs=$(git rev-parse --show-toplevel)
    toplevel=$(realpath --relative-to=. ${toplevelabs})
    gitfiles=$(git ls-tree --full-tree -r HEAD | awk -v toplevel=${toplevel} '{print toplevel "/" $NF}')

    files=$(echo ${gitfiles} | ${FZF_COMMAND})

    if [ "$?" -eq 0 ];
    then
      nvim ${files}
    fi
  else
    echo "Not in a git repo"
  fi
}

function fzf-docker-run {
  if ! hash docker &> /dev/null
  then
    echo "Docker is not installed"
    return
  fi

  image=$(docker image list | awk 'NR!=1 {print $1}' | grep -v "<none>")
  selectedimage=$(echo ${image} | ${FZF_COMMAND})

  if [ "$?" -eq 0 ];
  then
    docker run -it ${selectedimage}
  fi
}

# set stuff based on os
if [[ ${OSTYPE} == 'darwin'* ]]; then
  FZF_COMMAND=fzf-tmux
elif grep -q Microsoft /proc/version; then
  FZF_COMMAND=fzf
else
  FZF_COMMAND=fzf

  # on ubuntu bat is called batcat
  if hash batcat &> /dev/null
  then
    alias bat='batcat'
  fi
fi

if hash bat &> /dev/null
then
  FZF_PREVIEW='bat --color=always --style=grid --line-range :300 {}'
else
  FZF_PREVIEW='less'
fi

export FZF_DEFAULT_OPTS=" \
  --height=40% \
  --layout=reverse \
  --info=inline \
  --border \
  --margin=1 \
  --preview '${FZF_PREVIEW}' \
  --preview-window right"

export BAT_THEME="Dracula"

# add keybindings for the above functions
bindkey -s '^f' 'fzf-find-files^M'
bindkey -s '^s' 'fzf-find-all-files^M'
bindkey -s '^g' 'fzf-find-git-files^M'
bindkey -s '^t' 'fzf-docker-run^M'

# make fzf-tmux default to 80%,80% window
alias fzf-tmux="fzf-tmux -p 80%,80%"
