ln -s ~/.dotfiles/.vimrc ~/.vimrc
ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.ycm_extra_conf.py ~/.ycm_extra_conf.py

mkdir -p ~/.config
mkdir -p ~/.vim
ln -s ~/.vimrc ~/.vim/init.vim
ln -s ~/.vim ~/.config/nvim
