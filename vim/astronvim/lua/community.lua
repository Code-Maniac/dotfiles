-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- { import = "astrocommunity.pack.lua" }, -- uncomment for Lua LSP/formatting when editing this config
  { import = "astrocommunity.motion.hop-nvim" },
  { import = "astrocommunity.pack.cmake" },
  { import = "astrocommunity.pack.rust" },
  { import = "astrocommunity.debugging.persistent-breakpoints-nvim" },
  -- runs a launch.json configuration's preLaunchTask/postDebugTask from the
  -- project's .vscode/tasks.json, as VS Code does (see plugins/dap.lua)
  { import = "astrocommunity.code-runner.overseer-nvim" },
  -- import/override with your plugins folder
}
