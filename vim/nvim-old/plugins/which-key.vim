" which-key is only supported on nvim 0.5 and higher
if has('nvim-0.5')

Plug 'folke/which-key.nvim'

function WhichKeySetup()
lua << EOF
    require("which-key").setup {

    }
EOF
endfunction

augroup WhichKeySetup
    autocmd!
    autocmd User PlugLoaded call WhichKeySetup()
augroup END

nnoremap <silent><space> :WhichKey<CR>
set timeoutlen=500

endif

