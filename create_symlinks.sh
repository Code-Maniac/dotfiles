ln -s ~/.dotfiles/.vimrc ~/.vimrc
ln -s ~/.dotfiles/.zshrc ~/.zshrc

mkdir -p ~/.config
mkdir -p ~/.vim
ln -s ~/.vimrc ~/.vim/init.vim
ln -s ~/.vim ~/.config/nvim
