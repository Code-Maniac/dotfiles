" ---------------------
" General Settings
" ---------------------

set expandtab
set shiftwidth=4
set tabstop=4
set autoindent
set smartindent
set copyindent
set smarttab
set hidden
set signcolumn=yes:2
set relativenumber
set number
set ruler
set termguicolors
set undofile
set spell
set title
set ignorecase
set smartcase
set wildmode=longest:full,full
set showmode
set showcmd
set nowrap
set nowrapscan
set list
set listchars=tab:▸\ ,eol:¬,trail:·
set mouse=a
set scrolloff=8
set sidescrolloff=8
set nojoinspaces
set splitright
set clipboard=unnamedplus
set confirm
set exrc
set backup
set backupdir=~/.local/share/nvim/backup//
set updatetime=300 " reduce time for loading syntax on large files
set redrawtime=10000 " allow more time for loading syntax on large files

" ----------------------------------
" Key maps
" ----------------------------------

let mapleader = ","

" Replace visual selection without copying it
vnoremap <leader>p "_dP

" Switching between windows to emulate what's in tmux
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k
nnoremap <silent> <C-l> <C-w>l

" Force behaviour for Y that is consistent with other capitals
nnoremap Y y$

" Allow gf to open non-existent files
map gf :edit <cfile><cr>

" Open the current file in the default program
nmap <leader>x :!xdg-open %<cr><cr>

" Easy insertion of a trailing ; and , from insert mode
imap ;; <Esc>A;<Esc>
imap ,, <Esc>A,<Esc>

" ----------------------------------
"
"-----------------------------------
