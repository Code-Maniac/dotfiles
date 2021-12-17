if &diff
    " we don't want lsp while in diff or merge
    finish
endif

Plug 'prabirshrestha/async.vim' " required for vim-lsp
Plug 'prabirshrestha/vim-lsp' " Generic Language Protocol client
Plug 'mattn/vim-lsp-settings' " Automatically install and configure language servers
Plug 'lighttiger2505/deoplete-vim-lsp'

let g:deoplete#enable_at_startup=1

inoremap <expr> <tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
