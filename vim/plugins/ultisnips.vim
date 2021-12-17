Plug 'Sirver/Ultisnips'
Plug 'honza/vim-snippets'

let g:UltiSnipsExpandTrigger="<c-s>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"

let g:UltiSnipsEditSplit="horizontal"

if has("nvim") 
    let g:UltiSnipsSnippetDir="~/.local/share/nvim/site/plugins/vim-snippets/snippets"
else
    let g:UltiSnipsSnippetDir="~/.vim/plugged/vim-snippets/snippets"
endif

map <F2> :UltiSnipsEdit<CR>
