" twilight is only supported in nvim 0.5 and higher
if has('nvim-0.5')

Plug 'folke/twilight.nvim'

function TwilightSetup()
lua << EOF
  require("twilight").setup {

  }
EOF
endfunction

augroup TwilightSetup
    autocmd!
    autocmd User PlugLoaded call TwilightSetup()
augroup END

endif
