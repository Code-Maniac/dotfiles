-- Seamless <C-h/j/k/l> movement between nvim splits and tmux panes.
--
-- The tmux half of this already lives in tmux/tmux.conf: it inspects the pane's
-- foreground process and forwards the key when it looks like vim, otherwise it
-- switches panes itself. Without this plugin nvim received those forwarded keys
-- and did nothing with them, so a pane running nvim swallowed C-hjkl instead of
-- moving anywhere.
--
-- The plugin drives tmux by running the tmux client against $TMUX, which works
-- from inside a container too: the tmux binary is installed there and the socket
-- is bind mounted, with $TMUX and $TMUX_PANE passed in by the docker exec.
--
-- What does *not* cross the boundary is tmux's own guess about what a pane is
-- running. Its is_vim test scrapes the host process list for the pane's tty, and
-- nvim in a container is in another pid namespace with its terminal on the
-- container side of the exec stream, so the host sees `docker` and forwards
-- nothing. The autocmds below fix that by having nvim publish the fact itself as
-- a pane option, which tmux.conf checks before falling back to the ps scrape.

-- -t $TMUX_PANE explicitly, never a bare `set -p`: nvim is not a tmux client, so
-- the server's idea of the "current" pane is whatever the attached client has
-- focused, which is not reliably this one.
local function publish(wait, ...)
  if not (vim.env.TMUX and vim.env.TMUX_PANE) then return end
  local cmd = { "tmux", "set-option", "-p", "-t", vim.env.TMUX_PANE, ... }
  pcall(function()
    local handle = vim.system(cmd, { text = true })
    -- Waited on only where it must be: on the exit path the process is about to
    -- go away, and a detached child can be reaped before it has spoken to the
    -- server, which would leave the option set and that pane forwarding keys
    -- into a shell. Mode changes are frequent, so those fire and forget.
    if wait then handle:wait(1000) end
  end)
end

-- Cleared entirely on exit, rather than set to no, so the pane goes back to
-- tmux's own ps test instead of being pinned to a stale answer.
local function clear() publish(true, "-u", "@is_vim") end

-- Only claim C-hjkl in the modes where the plugin actually binds them: normal
-- and terminal. In insert, visual, select or cmdline nothing is bound, and a
-- forwarded key is worse than useless - C-j arrives in insert mode as a plain LF
-- and inserts a line break. Publishing no in those modes hands the key back to
-- tmux, which switches the pane, matching what happened before nvim started
-- publishing anything at all.
--
-- mode() returns things like "niI" and "nt" for normal-ish states and "no" for
-- operator-pending, so the first character is the test. Terminal mode is "t".
local published
local function sync()
  local first = vim.api.nvim_get_mode().mode:sub(1, 1)
  local want = (first == "n" or first == "t") and "yes" or "no"
  -- Most mode changes do not cross this boundary, so tracking the last published
  -- value keeps this to a couple of processes per insert session rather than one
  -- per keystroke.
  if want == published then return end
  published = want
  publish(false, "@is_vim", want)
end

---@type LazySpec
return {
  "christoomey/vim-tmux-navigator",
  lazy = false,
  init = function()
    local group = vim.api.nvim_create_augroup("tmux_navigator_is_vim", { clear = true })

    -- ModeChanged covers the ordinary editing traffic. VimEnter seeds the first
    -- value, since no mode change has happened yet at startup.
    vim.api.nvim_create_autocmd({ "VimEnter", "ModeChanged" }, {
      group = group,
      desc = "Tell tmux whether this pane's nvim wants C-hjkl",
      callback = sync,
    })

    -- Ctrl-z hands the pane back to the shell, where forwarding C-hjkl would
    -- type control characters at the prompt. `published` is reset so the sync on
    -- resume actually fires rather than being skipped as a no-op.
    vim.api.nvim_create_autocmd("VimSuspend", {
      group = group,
      desc = "Release C-hjkl while suspended",
      callback = function()
        published = nil
        publish(true, "@is_vim", "no")
      end,
    })
    vim.api.nvim_create_autocmd("VimResume", { group = group, callback = sync })

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      desc = "Hand the pane back to tmux's own detection",
      callback = clear,
    })
  end,
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
