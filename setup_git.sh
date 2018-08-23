# setup git
cp -r ~/.dotfiles/.git_template ~/.git_template
git config --global init.templatedir "~/.git_template"
# set difftool to vim.
git config --global diff.tool vimdiff
git config --global difftool.prompt false
git config --global alias.diff difftool
git config --global alias.whatadded 'log --diff-filter=A --'
git config --global difftool.vimdiff.cmd 'vim -f -d -c "wincmd l" -c '\''cd "$GIT_PREFIX"'\'' "$LOCAL" "$REMOTE"'
# set mergtool to vimdiff
git config --global merge.tool vimdiff
git config --global merge.conflictstyle diff3
git config --global mergetool.prompt false
