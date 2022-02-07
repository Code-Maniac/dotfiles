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

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes

    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif

    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gt <plug>(lsp-type-definition)
    nmap <buffer> K <plug>(lsp-hover)

    let g:lsp_format_sync_timeout = 1000
    " auto format rust and go on write
    autocmd! BufWritePre *.rs,*.go call execute('LspDocumentFormatSync')
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages with a registered server
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END
