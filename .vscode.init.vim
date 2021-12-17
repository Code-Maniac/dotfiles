call plug#begin('~/.vim/plugged')
	Plug 'tpope/vim-repeat'
	Plug 'tpope/vim-surround'
	Plug 'tpope/vim-commentary'
	Plug 'tpope/vim-unimpaired'
	" Plug 'tpope/vim-ragtag'
	" Plug 'tpope/vim-endwise'
	Plug 'vim-scripts/argtextobj.vim'
	Plug 'AndrewRadev/splitjoin.vim'
call plug#end()

" SET LOCATION OF VIMFILES SWAP, UNDO ETC
set dir=~/.vim/swap//
set undodir=~/.vim/undo//

" remain in visual mode when >> <<
vnoremap < <gv
vnoremap > >gv
