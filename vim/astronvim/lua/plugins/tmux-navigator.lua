-- Seamless <C-h/j/k/l> movement between nvim splits and tmux panes.
--
-- The tmux half of this already lives in tmux/tmux.conf: it inspects the pane's
-- foreground process and forwards the key when it looks like vim, otherwise it
-- switches panes itself. Without this plugin nvim received those forwarded keys
-- and did nothing with them, so a pane running nvim swallowed C-hjkl instead of
-- moving anywhere.
--
-- Note this only joins up when nvim and the tmux server are on the same side of
-- a container boundary - the plugin drives tmux by running the tmux client
-- against $TMUX.

---@type LazySpec
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (split or tmux pane)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (split or tmux pane)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (split or tmux pane)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (split or tmux pane)" },
  },
}
