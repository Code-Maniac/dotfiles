" zen-mode is only supported on nvim 0.5 and higher
if has('nvim-0.5')

Plug 'folke/zen-mode.nvim'

function ZenModeSetup()
lua << EOF
    require("zen-mode").setup {

    }
EOF
endfunction

augroup ZenModeSetup
    autocmd!
    autocmd User PlugLoaded call ZenModeSetup()
augroup END

nnoremap <silent>z :ZenMode<CR>

endif

