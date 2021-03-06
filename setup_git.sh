# setup git
cp -r ~/.dotfiles/.git_template ~/.git_template
git config --global init.templatedir "~/.git_template"
# set editor to vim.
git config --global core.editor "vim"
# set mergtool to vimdiff
git config --global merge.tool vimdiff
git config --global merge.conflictstyle diff3
git config --global mergetool.prompt true
# set difftool to vim.
git config --global diff.tool vimdiff
git config --global difftool.prompt true
git config --global difftool.vimdiff.cmd "vimdiff -R $LOCAL -c ':se noreadonly' $REMOTE"
git config --global alias.d difftool
git config --global alias.whatadded 'log --diff-filter=A --'
git config --global alias.l 'log --graph'
git config --global difftool.vimdiff.cmd 'vim -f -d -c "wincmd l" -c '\''cd "$GIT_PREFIX"'\'' "$LOCAL" "$REMOTE"'
# set log graph alias
git config --global alias.lgb "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset%n' --abbrev-commit --date=relative --branches"
git config --global alias.fl "log --oneline --graph --all --decorate --abbrev-commit"
