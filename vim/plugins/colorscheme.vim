Plug 'rafi/awesome-vim-colorschemes'
Plug 'dracula/vim', { 'as': 'dracula' }

let g:dracula_colorterm = 0
augroup DraculaOverrides
    autocmd!
    autocmd ColorScheme dracula highlight DraculaBoundary ctermbg=none guibg=none
    autocmd ColorScheme dracula highlight DraculaDiffDelete ctermbg=none guibg=none
    autocmd ColorScheme dracula highlight DraculaComment cterm=italic gui=italic
    autocmd User PlugLoaded ++nested colorscheme dracula
augroup end
