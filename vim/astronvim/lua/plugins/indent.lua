-- Per-language indentation, with .clang-format taken as the source of truth
-- for C-family files.
--
-- Rather than parsing .clang-format ourselves, we shell out to
-- `clang-format -style=file --dump-config`, which resolves `BasedOnStyle`
-- inheritance for us. Zephyr's .clang-format, for example, never mentions
-- TabWidth -- it inherits 8 from LLVM -- so a naive YAML parse would miss it.

-- Fallback indentation per filetype, used when no .clang-format applies.
local by_filetype = {
  lua = { expandtab = true, shiftwidth = 2 },
  python = { expandtab = true, shiftwidth = 4 },
  sh = { expandtab = true, shiftwidth = 2 },
  zsh = { expandtab = true, shiftwidth = 2 },
  yaml = { expandtab = true, shiftwidth = 2 },
  json = { expandtab = true, shiftwidth = 2 },
  javascript = { expandtab = true, shiftwidth = 2 },
  typescript = { expandtab = true, shiftwidth = 2 },
  html = { expandtab = true, shiftwidth = 2 },
  css = { expandtab = true, shiftwidth = 2 },
  rust = { expandtab = true, shiftwidth = 4 },
  go = { expandtab = false, shiftwidth = 4, tabstop = 4 },
  make = { expandtab = false, shiftwidth = 8, tabstop = 8 },
}

-- Filetypes whose indentation we source from .clang-format.
local clang_filetypes = {
  c = true,
  cpp = true,
  objc = true,
  objcpp = true,
  cuda = true,
  proto = true,
}

-- Resolved config keyed by the directory holding the .clang-format, so we run
-- at most one subprocess per project rather than one per buffer. `false` is
-- cached for failures to avoid retrying a broken config on every open.
local cache = {}

---@return table|nil indentation settings derived from the nearest .clang-format
local function clang_format_indent(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" or vim.bo[bufnr].buftype ~= "" then return nil end

  local found = vim.fs.find(".clang-format", { path = vim.fs.dirname(file), upward = true })[1]
  if not found then return nil end

  local root = vim.fs.dirname(found)
  if cache[root] ~= nil then return cache[root] or nil end

  local ok, res = pcall(function()
    return vim
      .system({ "clang-format", "-style=file", "--dump-config" }, { cwd = root, text = true })
      :wait(2000)
  end)
  if not ok or res.code ~= 0 or not res.stdout then
    cache[root] = false
    return nil
  end

  local conf = {}
  for line in res.stdout:gmatch "[^\n]+" do
    local key, value = line:match "^(%w+):%s*(%S+)"
    if key then conf[key] = value end
  end

  local indent_width = tonumber(conf.IndentWidth)
  if not indent_width then
    cache[root] = false
    return nil
  end

  -- UseTab: Never is the only value that means "spaces only". ForIndentation,
  -- ForContinuationAndIndentation, AlignWithSpaces and Always all emit real
  -- tab characters for indentation, so expandtab must be off.
  local use_tab = conf.UseTab or "Never"
  local expandtab = use_tab == "Never"
  local tab_width = tonumber(conf.TabWidth) or indent_width

  local settings = {
    expandtab = expandtab,
    shiftwidth = indent_width,
    tabstop = tab_width,
    -- With tabs, softtabstop must be 0 or the Tab key inserts spaces that
    -- don't line up with the tabstop grid.
    softtabstop = expandtab and indent_width or 0,
  }

  cache[root] = settings
  return settings
end

local function apply(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local ft = vim.bo[bufnr].filetype

  local settings = clang_filetypes[ft] and clang_format_indent(bufnr) or by_filetype[ft]
  if not settings then return end

  for opt, value in pairs(settings) do
    vim.bo[bufnr][opt] = value
  end
  -- shiftwidth defaults to tabstop when the caller only specified one
  if settings.shiftwidth and not settings.tabstop and settings.expandtab then
    vim.bo[bufnr].tabstop = settings.shiftwidth
    vim.bo[bufnr].softtabstop = settings.shiftwidth
  end
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  opts = {
    commands = {
      IndentReload = {
        function()
          -- Clear in place rather than reassigning, so the upvalue captured by
          -- clang_format_indent still refers to this table.
          for key in pairs(cache) do
            cache[key] = nil
          end
          local count = 0
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
              apply(buf)
              count = count + 1
            end
          end
          vim.notify(
            ("Indent settings reloaded (%d buffer%s)"):format(count, count == 1 and "" or "s"),
            vim.log.levels.INFO
          )
        end,
        desc = "Re-read .clang-format and re-apply indentation",
      },
    },
    autocmds = {
      user_indent = {
        {
          event = "FileType",
          desc = "Set indentation from .clang-format or per-filetype defaults",
          callback = function(args)
            -- Deferred so this lands *after* guess-indent.nvim, which also
            -- writes these options during buffer setup and would otherwise win.
            vim.schedule(function() apply(args.buf) end)
          end,
        },
      },
    },
  },
}
