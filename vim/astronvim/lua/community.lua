-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- { import = "astrocommunity.pack.lua" }, -- uncomment for Lua LSP/formatting when editing this config
  { import = "astrocommunity.motion.hop-nvim" },
  -- import/override with your plugins folder
}
