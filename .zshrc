# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# load plugin manager and oh-my-zsh
source ~/.antigen/antigen.zsh
antigen use oh-my-zsh

# theme
antigen theme romkatv/powerlevel10k
# antigen theme robbyrussell

# antigen is finished
antigen apply

stty -ixon

[ -e ~/.dircolors ] && eval $(dircolors -b ~/.dircolors) || eval $(dircolors -b)

export TERM=xterm-256color

if [ "$TMUX" = "" ]; then tmux attach || tmux new; fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export PATH="$PATH:/usr/local/sbin"
export PATH="$PATH:/usr/local/bin"
export PATH="$PATH:/usr/sbin"
export PATH="$PATH:/usr/bin"
export PATH="$PATH:/sbin"
export PATH="$PATH:/bin"
export PATH="$PATH:/usr/games"
export PATH="$PATH:/usr/local/games"
export PATH="$PATH:/usr/local/bin/lint"
export PATH="$PATH:/usr/local/bin/lint/config"
export PATH="$PATH:/opt/arm-toolchain/bin"
export PATH="$PATH:/opt/XA/Qt-5.4.0/bin"
export PATH="$PATH:/opt/arm-toolchain/bin"
export PATH="$PATH:/opt/gcc-linaro-arm-linux-gnueabihf-raspbian/bin"
# Created by `userpath` on 2021-09-08 09:12:30
export PATH="$PATH:/home/nick/.local/bin"
export PATH="$PATH:/home/nick/.cargo/bin"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
