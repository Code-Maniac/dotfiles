-- ANSI colour escape snippets for shell scripts.
--
-- Type RED, accept the completion, and get \033[31m…\033[0m with the cursor
-- between the two - the reset is included because forgetting it is what leaves a
-- terminal stained for the rest of the session. blink.cmp surfaces LuaSnip as a
-- source, so these appear in the normal completion menu.
--
-- Naming follows the long-circulating bash colour gist:
--
--   RED       plain              \033[31m
--   BRED      bold               \033[1;31m
--   URED      underlined         \033[4;31m
--   IRED      high intensity     \033[91m
--   BIRED     bold high int.     \033[1;91m
--   BG_RED    background         \033[41m
--   BG_IRED   high int. bg       \033[101m
--
-- BG_ keeps its underscore on purpose. Without it, BGREEN (bold green) and
-- BGGREEN (background green) differ by one character while meaning entirely
-- different things, which is a silent-mistake generator. The gist writes these
-- as On_Red for the same reason.
--
-- Note I is intensity here, not italic - again following the gist. ITALIC is
-- spelled out.
--
-- Scoped to shell filetypes deliberately. The triggers are ordinary words - RED,
-- BLUE, BOLD - and offering them in every buffer would put noise in front of real
-- completions everywhere for the sake of the few files that want an escape
-- sequence. A *.bash file may be detected as either `bash` or `sh` depending on
-- its contents, so both are registered.
--
-- \033 rather than \e: \e is a bashism, understood by bash's $'...' and
-- `echo -e` but not by POSIX sh, whereas \033 is handled by printf(1)
-- everywhere. It is also the form used in the statusline's Config.toml.

local FILETYPES = { "sh", "bash", "zsh" }

-- The eight ANSI colours in canonical SGR order. Every family below is an offset
-- from this list, so the numbers stay derived rather than typed out.
local COLOURS = { "BLACK", "RED", "GREEN", "YELLOW", "BLUE", "MAGENTA", "CYAN", "WHITE" }

-- prefix, SGR builder given the 0-7 colour offset, description template.
local VARIANTS = {
  { "", function(n) return tostring(30 + n) end, "%s" },
  { "B", function(n) return "1;" .. (30 + n) end, "bold %s" },
  { "U", function(n) return "4;" .. (30 + n) end, "underlined %s" },
  { "I", function(n) return tostring(90 + n) end, "high intensity %s" },
  { "BI", function(n) return "1;" .. (90 + n) end, "bold high intensity %s" },
  { "BG_", function(n) return tostring(40 + n) end, "%s background" },
  { "BG_I", function(n) return tostring(100 + n) end, "high intensity %s background" },
}

-- Attributes that style a run of text, so they wrap it like the colours do.
local WRAPPING_ATTRIBUTES = {
  { "BOLD", 1, "bold" },
  { "DIM", 2, "faint" },
  { "ITALIC", 3, "italic" },
  { "UNDERLINE", 4, "underline" },
  { "BLINK", 5, "blink, usually ignored" },
  { "REVERSE", 7, "swap foreground and background" },
  { "HIDDEN", 8, "concealed, usually ignored" },
  { "STRIKE", 9, "strikethrough" },
}

-- Codes that are an endpoint rather than a style: wrapping them in a reset would
-- be nonsense, so these insert bare.
local BARE_ATTRIBUTES = {
  { "RESET", 0, "reset all attributes" },
  { "DEFAULT", 39, "default foreground" },
  { "BG_DEFAULT", 49, "default background" },
}

local RESET = "\\033[0m"

local function escape(params) return "\\033[" .. params .. "m" end

-- Built fresh on each call: LuaSnip takes ownership of the snippet objects it is
-- given, so the same table must not be handed to more than one filetype.
local function build()
  local ls = require "luasnip"
  local s, t, i = ls.snippet, ls.text_node, ls.insert_node

  local out = {}
  local function add(snippet) out[#out + 1] = snippet end

  -- Wrapping form: sequence, a stop for the text, then the reset. i(1) rather
  -- than i(0) so the final tab lands after the reset instead of stranding the
  -- cursor inside the coloured run.
  local function wrapping(trig, params, description)
    add(s(
      { trig = trig, desc = escape(params) .. "…" .. RESET .. "  " .. description },
      { t(escape(params)), i(1), t(RESET) }
    ))
  end

  local function bare(trig, params, description)
    add(s({ trig = trig, desc = escape(params) .. "  " .. description }, t(escape(params))))
  end

  for _, attribute in ipairs(WRAPPING_ATTRIBUTES) do
    wrapping(attribute[1], tostring(attribute[2]), attribute[3])
  end
  for _, attribute in ipairs(BARE_ATTRIBUTES) do
    bare(attribute[1], tostring(attribute[2]), attribute[3])
  end

  for index, colour in ipairs(COLOURS) do
    local offset = index - 1
    for _, variant in ipairs(VARIANTS) do
      local prefix, params, description = variant[1], variant[2], variant[3]
      wrapping(prefix .. colour, params(offset), description:format(colour:lower()))
    end
  end

  -- Parametrised forms, where the numbers cannot be baked in. The truecolour one
  -- is the shape the statusline's Config.toml uses, e.g. \033[38;2;137;180;250m.
  -- Tab order is the numbers first, then the text, then out past the reset.
  local function parametrised(trig, prefix, label, description)
    add(s(
      { trig = trig, desc = "\\033[" .. label .. "m…" .. RESET .. "  " .. description },
      { t("\\033[" .. prefix), i(1, "n"), t "m", i(2), t(RESET) }
    ))
  end
  parametrised("FG256", "38;5;", "38;5;N", "256-colour foreground")
  parametrised("BG256", "48;5;", "48;5;N", "256-colour background")

  local function truecolour(trig, prefix, label, description)
    add(s(
      { trig = trig, desc = "\\033[" .. label .. "m…" .. RESET .. "  " .. description },
      { t("\\033[" .. prefix), i(1, "r"), t ";", i(2, "g"), t ";", i(3, "b"), t "m", i(4), t(RESET) }
    ))
  end
  truecolour("FGRGB", "38;2;", "38;2;R;G;B", "truecolour foreground")
  truecolour("BGRGB", "48;2;", "48;2;R;G;B", "truecolour background")

  return out
end

local registered = false

local function setup()
  if registered then return end
  local ok, ls = pcall(require, "luasnip")
  if not ok then return end
  registered = true
  for _, filetype in ipairs(FILETYPES) do
    ls.add_snippets(filetype, build())
  end
end

-- A FileType autocmd rather than a LuaSnip spec hook. lazy.nvim treats `init`
-- and `config` as last-wins when two specs name the same plugin, so adding
-- either to a LuaSnip spec here would silently clobber AstroNvim's own - which
-- is exactly what happened on the first attempt: the snippets never registered.
-- Going through FileType also means nothing is built until a shell file is
-- actually opened, and by then LuaSnip has finished its own setup.
vim.api.nvim_create_autocmd("FileType", {
  pattern = FILETYPES,
  group = vim.api.nvim_create_augroup("ansi_snippets", { clear = true }),
  desc = "Register ANSI colour snippets for shell filetypes",
  callback = setup,
})

-- No plugin spec of its own: this only adds snippets to a LuaSnip that AstroNvim
-- already installs.
---@type LazySpec
return {}
