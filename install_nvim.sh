#!/bin/bash

echo "Remove existing /tmp/neovim"
sudo rm -rf /tmp/neovim

echo "Installing neovim prerequisites"
sudo apt-get install -y git ninja-build gettext libtool autoconf automake cmake g++ pkg-config unzip

echo "Cloning neovim repository from github."
git clone https://github.com/neovim/neovim /tmp/neovim

cd /tmp/neovim

echo "Make neovim"
make
sudo make install

sudo rm -rf /tmp/neovim

sudo apt-get -y install python-dev python3-dev python-pip python-pip3

sudo pip install neovim
sudo pip3 install neovim
