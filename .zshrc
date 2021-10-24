# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="/opt/homebrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/bin/lint:/usr/local/bin/lint/config:/opt/arm-toolchain/bin:/opt/XA/Qt-5.4.0/bin:/opt/arm-toolchain/bin"

# load plugin manager and oh-my-zsh
source ~/.antigen/antigen.zsh
antigen use oh-my-zsh

# theme
antigen theme romkatv/powerlevel10k

# antigen is finished
antigen apply

#instead of using cp use rsync instead.
alias cp="rsync -avz"

# if [ "$TMUX" = "" ]; then tmux attach || tmux new; fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
