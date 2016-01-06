"
"  VIM CONFIGURATION FILE
"
"  NICK JAYCOCK
"

" PLUGINS
call plug#begin('~/.vim/plugged')
	Plug 'https://github.com/edsono/vim-matchit.git'

	Plug 'valloric/youcompleteme', { 'do':'./install.py --clang-completer'}
	Plug 'rdnetto/YCM-Generator', { 'branch': 'stable' }
	"Plug 'jeaye/color_coded' "can't get this to work currently
	"Plug 'https://github.com/octol/vim-cpp-enchanced-highlight'

	Plug 'junegunn/vim-easy-align'
	Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': 'yes \| ./install' }

	Plug 'easymotion/vim-easymotion'

	Plug 'tpope/vim-surround'
	Plug 'tpope/vim-fugitive'

	Plug 'wincent/Command-T'

	Plug 'Raimondi/delimitMate'

	Plug 'Majutsushi/tagbar'

	Plug 'scrooloose/nerdtree'
	Plug 'scrooloose/nerdcommenter'

	Plug 'unblevable/quick-scope'

	Plug 'https://github.com/Lokaltog/vim-powerline', { 'branch': 'develop' }
call plug#end()
"something something

" APPEARANCE
"syntax enable
"set term=screen-256color
"let g:solarized_termtrans=1
"let g:solarized_termcolors=256
"colorscheme solarized
"colorscheme seoul256
"set background=dark

set nocompatible " Vim rather than Vi
"set term=screen-256color
set t_Co=256

syntax enable
set background=dark
colorscheme solarized

"syntax enable
"colorscheme jellybeans


" colorscheme valloric
set ruler                           " always show cursor position.
set showmode                        " display curent mode.
set showcmd                         " display incomplete commands.
set nu                              " show line numbers.
set undofile                        " stores undo state even when files are closed.
set title                           " show file in titlebar
set showmatch                       " shows matching bracket - briefly jumps to it.

if has("gui_running")               " set fullscreen mode on startup.
    set lines=1200 columns=1200
endif

" DEFAULT TAB STOPS & INDENTING
set tabstop=8                       " tab stops
set softtabstop=8
set shiftwidth=8                    " number of spaces to use for each step of (auto)indent
set noexpandtab
set autoindent
set copyindent
set smarttab
set list
set listchars=tab:▸\ ,eol:¬,trail:~

" ERGONOMICS
set backspace=indent,eol,start      " liberal backspacing in insert mode
set showmatch                       " show matching brackets when hovering

set history=1000                    " many histories
set smartcase
set ttyfast                         " smoother output, they claim

" SEARCH
set ignorecase
set incsearch

" Unicode support
if has("multi_byte")
	if &termencoding == ""
		let &termencoding = &encoding
	endif
	set encoding=utf-8
	setglobal fileencoding=utf-8
	set fileencodings=ucs-bom,utf-8,latin1
endif

" remain in visual mode when >> <<
vnoremap < <gv
vnoremap > >gv

" cycle through commands with arrow keys
"cnoremap <c-j> <down>
"cnoremap <c-k> <up>

" FUNCTION TO TOGGLE BACKGROUND DARK TO LIGHT AND BACK
function! ToggleBackground()
	if &background==dark
		set background=light
	else
		set background=dark
	endif
endfunction
" MAPPINGS
map <F1> :FufFile<CR>
map <F2> :FufBuffer<CR>
map <F3> :FufDir<CR>
map <F4> :TlistOpen<CR>

" map <F5> :NERDTreeToggle<CR>
map <F5> :if &background==dark set background=light else set background=dark endif<CR>
map <F6> :ConqueTerm<Space>
map <F7> :set fileencoding=
map <F8> :set filetype=

"map <F9> 
map <F10> :JekyllPost 
map <F11> :FufFile ~/dev/jostein.be/_posts/<CR>
map <F12> :Gist 

map <C-Space> :!

map <C-t> :tab split<SPACE>
map <C-x> :split<SPACE>
map <C-v> :vsplit<SPACE>

"go to next tab by pressing tab
map <TAB> :tabn<CR>
"go to previous tab by pressing ctrl tab
map <C-TAB> :tabp<CR>

"open fzf
map <C-p> :FZF<CR>
"open NERDTree
map <C-n> :NERDTreeToggle<CR>

"fzf stuff
let g:fzf_action = {
	\ 'ctrl-t': 'tab split',
	\ 'ctrl-x': 'split',
	\ 'ctrl-v': 'vsplit' }

"let g:fzf_layout = { 'down': '~40%' }
let g:fzf_layout = { 'window': 'enew' }

autocmd VimEnter * command! Colors
	\ call fzf#vim#colors({'left': '15%', 'options': '--reverse --margin 30%, 0'})

" YOUCOMPLETEME
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_min_num_identifier_candidate_chars = 4
let g:ycm_extra_conf_globlist = ['~/repos/*']
let g:ycm_filetype_specific_completion_to_disable = {'javascript': 1}

nnoremap <leader>y :YcmForceCompileAndDiagnostics<cr>
nnoremap <leader>g :YcmCompleter GoTo<CR>
nnoremap <leader>pd :YcmCompleter GoToDefinition<CR>
nnoremap <leader>pc :YcmCompleter GoToDeclaration<CR>

" TECHNICAL
set mouse=a
set encoding=utf-8
set fileencoding=utf-8
set termencoding=utf-8

" VIM-Powerline
set laststatus=2
