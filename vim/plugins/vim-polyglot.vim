Plug 'sheerun/vim-polyglot'

" If the current file .txt file contains "CMakeLists" in the filename then
" assume it's a cmake file even if it's not called "CMakeLists.txt"
au VimEnter *.txt if expand("%:t") =~ ".*CMakeLists.*" | set syntax=cmake | set filetype=cmake | endif
