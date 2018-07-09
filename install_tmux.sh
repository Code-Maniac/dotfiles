#!/bin/bash

sudo apt-get update

sudo apt-get instal -y git automake build-essential pkg-config libevent-dev libncurses5-dev

rm -fr /tmp/tmux

git clone https://github.com/tmux/tmux /tmp/tmux

cd /tmp/tmux

sh autogen.sh

./configure && make

sudo make install

cd -

rm -fr /tmp/tmux
