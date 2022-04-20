if has('nvim-0.5')

Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

function TelescopeSetup()
lua << EOF
    require('telescope').setup{
      defaults = {
        -- Default configuration for telescope goes here:
        -- config_key = value,
        mappings = {
          i = {
            -- map actions.which_key to <C-h> (default: <C-/>)
            -- actions.which_key shows the mappings for your picker,
            -- e.g. git_{create, delete, ...}_branch for the git_branches picker
            ["<C-h>"] = "which_key"
          }
        }
      },
      pickers = {
        -- Default configuration for builtin pickers goes here:
        -- picker_name = {
        --   picker_config_key = value,
        --   ...
        -- }
        -- Now the picker_config_key will be applied every time you call this
        -- builtin picker
      },
      extensions = {
        -- Your extension configuration goes here:
        -- extension_name = {
        --   extension_config_key = value,
        -- }
        -- please take a look at the readme of the extension you want to configure
      }
    }
EOF

" matches the fzf key bindings as well as possible
nmap <leader>f <cmd>Telescope find_files<cr>
nmap <leader>g <cmd>Telescope live_grep<cr>
nmap <leader>b <cmd>Telescope buffers<cr>
nmap <leader>h <cmd>Telescope help_tags<cr>

endfunction

augroup TelescopeSetup
    autocmd!
    autocmd User PlugLoaded call TelescopeSetup()
augroup END

else

" if we don't have nvim then source fzf instead
source ~/.config/nvim/plugins/fzf.vim

endif
