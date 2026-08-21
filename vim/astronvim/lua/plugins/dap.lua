-- Debug adapters and configurations.
--
-- gdb 14+ implements DAP itself, so there is no adapter to download - with the
-- caveat that it is implemented in Python, and a gdb built without Python
-- silently lacks it. The system gdb has it; the Zephyr SDK's arm-zephyr-eabi-gdb
-- does not, which is why the remote configuration uses gdb-multiarch.
--
-- On ordering: mason-nvim-dap registers codelldb for c, cpp and rust, and it
-- does so after nvim-dap's load hooks - so anything registered from a load hook
-- alone gets overwritten. Everything here is registered through `setup`, called
-- both from the load hook and from mason's own codelldb handler, and it puts
-- these configurations in front of whatever is already there.

--------------------------------------------------------------------------------
-- finding something to debug
--------------------------------------------------------------------------------

-- Where build output tends to land, relative to the cwd. "" is the cwd itself,
-- for a bare `gcc -g -o thing thing.c`.
local roots = { "", "build", "build/zephyr", "target/debug", "target/release", "out", "bin" }

-- Never launchable, or never the thing you meant. .exe is deliberately absent:
-- that is what Zephyr calls a native_sim binary.
local not_a_program = {
  so = true, a = true, o = true, d = true, elf = true, hex = true, bin = true,
  map = true, py = true, sh = true, cmake = true, json = true, txt = true, md = true,
}

local function is_program(path, name)
  return vim.fn.executable(path) == 1 and not not_a_program[vim.fn.fnamemodify(name, ":e")]
end
local function is_elf(_, name) return vim.fn.fnamemodify(name, ":e") == "elf" end
local function is_native_sim(path, name)
  return name == "zephyr.exe" and vim.fn.executable(path) == 1
end

-- Files directly under each root, newest first so whatever was just built sorts
-- to the top. One level per root, not recursive.
local function candidates(match)
  local seen, found = {}, {}
  for _, root in ipairs(roots) do
    local dir = vim.fs.normalize(vim.fn.getcwd() .. "/" .. root)
    pcall(function()
      for name, kind in vim.fs.dir(dir) do
        local path = dir .. "/" .. name
        if kind == "file" and not seen[path] and match(path, name) then
          seen[path] = true
          found[#found + 1] = { path = path, mtime = vim.fn.getftime(path) }
        end
      end
    end)
  end
  table.sort(found, function(a, b) return a.mtime > b.mtime end)
  return vim.tbl_map(function(entry) return entry.path end, found)
end

-- Anything executable under a directory tree, skipping CMake's own scaffolding,
-- for build directories that nest binaries in subdirectories.
local function candidates_under(dir)
  local found = vim.fs.find(function(name, path)
    return not path:match "/CMakeFiles" and is_program(path .. "/" .. name, name)
  end, { path = dir, type = "file", limit = math.huge })
  table.sort(found, function(a, b) return vim.fn.getftime(a) > vim.fn.getftime(b) end)
  return found
end

-- Ask, but only when there is a choice. nvim-dap evaluates these inside a
-- coroutine, so the picker yields rather than blocking.
local function choose(list, label)
  if #list == 1 then return list[1] end
  if #list == 0 then return nil end
  local co = coroutine.running()
  local cwd = vim.fn.getcwd()
  vim.ui.select(list, {
    prompt = label,
    format_item = function(item)
      local text = type(item) == "table" and item.label or item
      return (text:gsub("^" .. vim.pesc(cwd) .. "/", ""))
    end,
  }, function(choice) coroutine.resume(co, choice) end)
  return coroutine.yield()
end

local function pick(match, label)
  return function()
    local found = candidates(match)
    if #found == 0 then return vim.fn.input(label .. ": ", vim.fn.getcwd() .. "/", "file") end
    return choose(found, label)
  end
end

--------------------------------------------------------------------------------
-- cmake presets
--------------------------------------------------------------------------------

local function run(cmd)
  local out = vim.fn.systemlist(cmd)
  return vim.v.shell_error == 0, out
end

-- cmake applies each preset's `condition`, so this only lists presets usable on
-- this machine - the Visual Studio ones are absent on Linux, for instance.
local function configure_presets()
  local ok, out = run { "cmake", "--list-presets=configure" }
  if not ok then return {} end
  local presets = {}
  for _, line in ipairs(out) do
    local name, description = line:match '^%s*"([^"]+)"%s*%-%s*(.+)$'
    if not name then name = line:match '^%s*"([^"]+)"%s*$' end
    if name then
      presets[#presets + 1] = { name = name, label = description and (name .. "  - " .. description) or name }
    end
  end
  return presets
end

-- binaryDir comes from the preset file rather than being guessed, with the two
-- macros that matter expanded. Presets inherit, so a preset without its own
-- binaryDir falls back through `inherits`.
local function preset_binary_dir(preset_name)
  local source_dir = vim.fn.getcwd()
  local by_name = {}
  for _, file in ipairs { "CMakePresets.json", "CMakeUserPresets.json" } do
    local path = source_dir .. "/" .. file
    if vim.fn.filereadable(path) == 1 then
      local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
      if ok then
        for _, preset in ipairs(data.configurePresets or {}) do by_name[preset.name] = preset end
      end
    end
  end

  local seen = {}
  local function resolve(name)
    local preset = by_name[name]
    if not preset or seen[name] then return nil end
    seen[name] = true
    if preset.binaryDir then return preset.binaryDir end
    local inherits = preset.inherits
    if type(inherits) == "string" then inherits = { inherits } end
    for _, parent in ipairs(inherits or {}) do
      local found = resolve(parent)
      if found then return found end
    end
  end

  local dir = resolve(preset_name)
  if not dir then return source_dir .. "/build" end
  dir = dir:gsub("%${sourceDir}", source_dir):gsub("%${presetName}", preset_name)
  return vim.fs.normalize(dir)
end

-- A build preset paired with this configure preset, if the project defines one.
local function build_preset_for(configure_preset)
  local ok, out = run { "cmake", "--list-presets=build" }
  if not ok then return nil end
  local names = {}
  for _, line in ipairs(out) do
    local name = line:match '^%s*"([^"]+)"'
    if name then names[#names + 1] = name end
  end
  local path = vim.fn.getcwd() .. "/CMakePresets.json"
  if vim.fn.filereadable(path) == 1 then
    local decoded, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if decoded then
      for _, preset in ipairs(data.buildPresets or {}) do
        if preset.configurePreset == configure_preset and vim.tbl_contains(names, preset.name) then
          return preset.name
        end
      end
    end
  end
  return nil
end

-- Configure when the build tree is missing, and also when the source root's
-- compile_commands.json symlink points somewhere other than this preset's build
-- directory. Projects that link the database in do it at configure time, so
-- re-configuring is what keeps clangd showing the same -D flags as the binary
-- being stepped through. Only a symlink counts: a copied database - Zephyr's
-- exported one, say - is nobody else's business here.
local function needs_configure(binary_dir)
  if vim.fn.filereadable(binary_dir .. "/CMakeCache.txt") == 0 then return true end

  local link = vim.fn.getcwd() .. "/compile_commands.json"
  local stat = vim.uv.fs_lstat(link)
  if stat and stat.type == "link" then
    return not vim.startswith(vim.fn.resolve(link), binary_dir .. "/")
  end
  return false
end

local function cmake_preset_program()
  vim.cmd "wall"

  local presets = configure_presets()
  if #presets == 0 then
    error "no usable CMake configure presets here (cmake --list-presets=configure came back empty)"
  end

  local chosen = choose(presets, "CMake preset")
  if not chosen then error "no preset chosen" end
  local name = chosen.name

  local binary_dir = preset_binary_dir(name)

  if needs_configure(binary_dir) then
    local ok, out = run { "cmake", "--preset", name }
    if not ok then error("cmake --preset " .. name .. " failed:\n" .. table.concat(out, "\n")) end
  end

  local build_preset = build_preset_for(name)
  local cmd = build_preset and { "cmake", "--build", "--preset", build_preset }
    or { "cmake", "--build", binary_dir }
  local ok, out = run(cmd)
  if not ok then error(table.concat(cmd, " ") .. " failed:\n" .. table.concat(out, "\n")) end

  local found = candidates_under(binary_dir)
  if #found == 0 then error("nothing executable under " .. binary_dir) end
  return choose(found, "binary from " .. name)
end

--------------------------------------------------------------------------------
-- rust
--------------------------------------------------------------------------------

-- `cargo build --message-format=json` reports the executable it produced, so the
-- binary never has to be guessed - which matters most for tests, whose binaries
-- land in target/debug/deps/<name>-<hash>.
local function cargo_built(args, label)
  return function()
    vim.cmd "wall"
    local ok, out = run(vim.list_extend({ "cargo", "build", "--message-format=json" }, args))
    if not ok then error(label .. " failed:\n" .. table.concat(out, "\n")) end

    local exes = {}
    for _, line in ipairs(out) do
      local decoded, msg = pcall(vim.json.decode, line)
      if decoded and msg.reason == "compiler-artifact" and type(msg.executable) == "string" then
        exes[#exes + 1] = msg.executable
      end
    end
    if #exes == 0 then error(label .. " produced no executable") end
    return choose(exes, label)
  end
end

--------------------------------------------------------------------------------
-- registration
--------------------------------------------------------------------------------

local function c_configurations()
  return {
    {
      name = "Launch executable",
      type = "gdb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = pick(is_program, "executable to debug"),
      stopAtBeginningOfMainSubprogram = false,
    },
    {
      name = "Build and debug a CMake preset",
      type = "gdb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = cmake_preset_program,
    },
    {
      name = "Launch zephyr.exe (native_sim)",
      type = "gdb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = pick(is_native_sim, "native_sim binary"),
    },
    {
      -- pair with a gdbserver: `pyocd gdbserver`, JLinkGDBServer, or
      -- `west build -t debugserver` under qemu
      name = "Attach to gdbserver (localhost:3333)",
      type = "gdb_remote",
      request = "attach",
      target = "localhost:3333",
      program = pick(is_elf, "elf with the symbols"),
    },
  }
end

local function rust_configurations()
  return {
    {
      name = "cargo build, then debug",
      type = "codelldb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = cargo_built({}, "cargo build"),
    },
    {
      name = "cargo build --tests, then debug",
      type = "codelldb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = cargo_built({ "--tests" }, "cargo build --tests"),
    },
  }
end

-- Idempotent, because this runs from two places and whichever goes last wins.
local function setup()
  local dap = require "dap"

  dap.adapters.gdb = {
    type = "executable",
    command = "gdb",
    args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
  }
  -- the same adapter against a gdb that knows non-host architectures
  dap.adapters.gdb_remote =
    vim.tbl_extend("force", dap.adapters.gdb, { command = "gdb-multiarch" })

  local function prepend(filetype, mine)
    local existing = dap.configurations[filetype] or {}
    if existing[1] and existing[1].name == mine[1].name then return end
    dap.configurations[filetype] = vim.list_extend(mine, existing)
  end

  prepend("c", c_configurations())
  dap.configurations.cpp = dap.configurations.c
  prepend("rust", rust_configurations())
end

---@type LazySpec
return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    -- Alt+letter, mirroring the VS Code keybindings: d/e debug and execute,
    -- n next, s step in, o step out, k kill, b breakpoint. Normal mode only -
    -- a terminal without CSI-u support sends Alt as an Esc prefix, which in
    -- insert mode would leave insert and run the letter as a command.
    keys = {
      -- dap.continue starts a session when none is running and continues a
      -- stopped one, so VS Code's two keys collapse onto one function here
      { "<M-d>", function() require("dap").continue() end, desc = "Debug: start / continue" },
      { "<M-e>", function() require("dap").continue() end, desc = "Debug: start / continue" },
      { "<M-n>", function() require("dap").step_over() end, desc = "Debug: step over" },
      { "<M-s>", function() require("dap").step_into() end, desc = "Debug: step into" },
      { "<M-o>", function() require("dap").step_out() end, desc = "Debug: step out" },
      { "<M-k>", function() require("dap").terminate() end, desc = "Debug: stop" },
      {
        "<M-b>",
        function()
          -- the persistent toggle, so breakpoints survive restarts
          local ok, persistent = pcall(require, "persistent-breakpoints.api")
          if ok then persistent.toggle_breakpoint() else require("dap").toggle_breakpoint() end
        end,
        desc = "Debug: toggle breakpoint (persistent)",
      },
    },
    init = function() require("astrocore").on_load("nvim-dap", setup) end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = function(_, opts)
      opts.handlers = opts.handlers or {}
      -- codelldb claims c, cpp and rust, and does it after the load hook above
      opts.handlers.codelldb = function(config)
        require("mason-nvim-dap").default_setup(config)
        setup()
      end
    end,
  },
}
