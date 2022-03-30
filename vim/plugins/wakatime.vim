if !empty(glob("~/.wakatime.cfg"))
    Plug 'wakatime/vim-wakatime'
else
    echo "No wakatime configuration detected!"
endif

