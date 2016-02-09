ln -sf ~/.dotfiles/.vimrc ~/.vimrc
ln -sf ~/.dotfiles/.zshrc ~/.zshrc
ln -sf ~/.dotfiles/.ycm_extra_conf.py ~/.ycm_extra_conf.py

mkdir -p ~/.config
mkdir -p ~/.vim
mkdir -p ~/.config/terminator

ln -sf ~/.vimrc ~/.vim/init.vim
ln -sf ~/.vim ~/.config/nvim
ln -sf ~/.dotfiles/.terminator_conf ~/.config/terminator/config
