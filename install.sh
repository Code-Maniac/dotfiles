#!/bin/sh
# install fonts for vim powerline.
echo "Installing powerline fonts."
rm -rf ./fonts
git clone https://github.com/powerline/fonts
cd fonts
./install.sh
cd ..
rm -rf ./fonts

echo "Creating symlinks to dotfiles."
# create symlinks for the dotfiles and directories.
ln -sf ~/.dotfiles/.vimrc ~/.vimrc
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/.ycm_extra_conf.py ~/.ycm_extra_conf.py
# ln -sf ~/.dotfiles/.gdbinit ~/.gdbinit
ln -sf ~/.dotfiles/.Xmodmap ~/.Xmodmap
ln -sf ~/.dotfiles/.dircolors ~/.dircolors

echo "Creating symlinks to directories."
mkdir -p ~/.config
mkdir -p ~/.vim
mkdir -p ~/.vim/swap
mkdir -p ~/.vim/undo
mkdir -p ~/.config/terminator

ln -sf ~/.vimrc ~/.vim/init.vim
ln -sf ~/.vim ~/.config/nvim
ln -sf ~/.dotfiles/.terminator_conf ~/.config/terminator/config
ln -sf ~/.dotfiles/.tmux.conf ~/.tmux.conf

cp -r ~/.dotfiles/.git_template ~/.git_template
git config --global init.templatedir "~/.git_template"

echo "Installing oh-my-zsh"
# install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

echo "Installing vim,tmux,zsh plugin managers."
# install plugin managers for vim, tmux and zsh.
# vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
	http://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# antigen
git clone https://github.com/zsh-users/antigen.git ~/.antigen
