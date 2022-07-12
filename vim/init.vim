" -----------------------------------------------------------------------------
" General Settings
" -----------------------------------------------------------------------------
set expandtab
set shiftwidth=4
set tabstop=4
set autoindent
set smartindent
set copyindent
set smarttab
set hidden
set relativenumber
set number
set ruler
set termguicolors
set undofile
set nospell
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
set cc=80
set mouse=a
set scrolloff=8
set sidescrolloff=8
set nojoinspaces
set splitright
set clipboard^=unnamed,unnamedplus
set confirm
set exrc
set backup
set backupdir=~/.local/share/nvim/backup//
set updatetime=300 " reduce time for loading syntax on large files
set redrawtime=10000 " allow more time for loading syntax on large files
" make the vim cursor much more visible by showing it in a crosshair - helpful
" when using lsp or other plugins to jump around different files
set cursorcolumn
set cursorline

" add additional / take away unwanted format options
au VimEnter * set formatoptions+=pn | set formatoptions-=o

" -----------------------------------------------------------------------------
" Key maps
" -----------------------------------------------------------------------------

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

" Increament and decrement the number under the cursor
nnoremap + <C-a>
nnoremap - <C-x>

" -----------------------------------------------------------------------------
" Plugins
" -----------------------------------------------------------------------------

" Automatically install vim-plug if it isn't already
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin(data_dir . '/plugins')

source ~/.config/nvim/plugins/colorscheme.vim
source ~/.config/nvim/plugins/vim-airline.vim
source ~/.config/nvim/plugins/vim-devicons.vim
" source ~/.config/nvim/plugins/vim-specs.vim

source ~/.config/nvim/plugins/vim-easymotion.vim
source ~/.config/nvim/plugins/vim-tmux-navigator.vim
source ~/.config/nvim/plugins/fzf.vim
" source ~/.config/nvim/plugins/telescope.vim " NOTE: WIP
source ~/.config/nvim/plugins/which-key.vim
source ~/.config/nvim/plugins/zen-mode.vim
source ~/.config/nvim/plugins/twilight.vim
source ~/.config/nvim/plugins/nerdtree.vim

source ~/.config/nvim/plugins/vim-repeat.vim
source ~/.config/nvim/plugins/vim-surround.vim
source ~/.config/nvim/plugins/vim-ragtag.vim
source ~/.config/nvim/plugins/vim-fugitive.vim
source ~/.config/nvim/plugins/vim-conflicted.vim
source ~/.config/nvim/plugins/vim-commentary.vim
source ~/.config/nvim/plugins/vim-endwise.vim
source ~/.config/nvim/plugins/vim-abolish.vim
source ~/.config/nvim/plugins/vim-unimpaired.vim
source ~/.config/nvim/plugins/vim-afterimage.vim
source ~/.config/nvim/plugins/vim-dispatch.vim
source ~/.config/nvim/plugins/vim-eunuch.vim
source ~/.config/nvim/plugins/argtextobj.vim
source ~/.config/nvim/plugins/splitjoin.vim
source ~/.config/nvim/plugins/vim-closetag.vim
source ~/.config/nvim/plugins/vim-pasta.vim
source ~/.config/nvim/plugins/delimitmate.vim
source ~/.config/nvim/plugins/todo-comments.vim

source ~/.config/nvim/plugins/vim-polyglot.vim
source ~/.config/nvim/plugins/vim-bitbake.vim
source ~/.config/nvim/plugins/deoplete.vim
source ~/.config/nvim/plugins/lsp.vim
source ~/.config/nvim/plugins/ultisnips.vim

source ~/.config/nvim/plugins/markdown-preview.vim

source ~/.config/nvim/plugins/vimspector.vim

" add time tracking with wakatime
source ~/.config/nvim/plugins/wakatime.vim

call plug#end()

doautocmd User PlugLoaded

" ------------------------------------------------------------------------------
" Miscellaneous
" ------------------------------------------------------------------------------

" delete trailing whitespace on write in certain filetypes
autocmd BufWritePre *.c,*.cpp,*.h,*.hpp :%s/\s\+$//e

" go back to the line we were on when we last closed the file unless it's git
" commit
if !&diff
    autocmd BufReadPost * if &filetype !=# 'gitcommit' | if line("'\'") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif
