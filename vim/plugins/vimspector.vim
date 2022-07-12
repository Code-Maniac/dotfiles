Plug 'puremourning/vimspector'

" from documentation of vimspector HUMAN mode
" F3 = Stop
" F4 = Restart
" F5 = Start / Continue
" F6 = Pause
" F8 = Add Function Breakpoint
" F9 = Toggle Breakpoint
" F10 = Step Over
" F11 = Step Into
" F12 = Setp Out
let g:vimspector_enable_mappings = 'HUMAN'

nmap <Leader>di <Plug>VimspectorBalloonEval
xmap <Leader>di <Plug>VimspectorBalloonEval
