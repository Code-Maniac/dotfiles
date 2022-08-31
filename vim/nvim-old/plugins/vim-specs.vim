if has('nvim-0.5')

Plug 'edluffy/specs.nvim'

function SpecsSetup()
lua << EOF
    require('specs').setup { 
        show_jumps  = true,
        min_jump = 10,
        popup = {
            delay_ms = 0, -- delay before popup displays
            inc_ms = 5, -- time increments used for fade/resize effects 
            blend = 10, -- starting blend, between 0-100 (fully transparent), see :h winblend
            width = 30,
            winhl = "PMenu",
            fader = require('specs').pulse_fader,
            resizer = require('specs').shrink_resizer
        },
        ignore_filetypes = {},
        ignore_buftypes = {
            nofile = true,
        },
    }
    require('specs').show_specs()
EOF
endfunction

augroup SpecsSetup
    autocmd!
    autocmd User PlugLoaded call SpecsSetup()
augroup END

endif
