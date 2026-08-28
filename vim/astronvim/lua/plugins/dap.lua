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

-- The CMake presets build into build-<preset>/ rather than build/, so their
-- zephyr directories are found rather than listed: one more preset in the json
-- should not need a matching edit here.
local function preset_roots()
  local found = {}
  for _, dir in ipairs(vim.fn.glob(vim.fn.getcwd() .. "/build-*/zephyr", false, true)) do
    found[#found + 1] = vim.fn.fnamemodify(dir, ":.")
  end
  return found
end

-- Files directly under each root, newest first so whatever was just built sorts
-- to the top. One level per root, not recursive.
local function candidates(match)
  local seen, found = {}, {}
  for _, root in ipairs(vim.list_extend(vim.list_slice(roots, 1, #roots), preset_roots())) do
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

-- The same, for the elf a gdbserver wants. A cross-built target produces nothing
-- the host can launch, so `candidates_under` comes back empty there and the elf
-- is the only thing worth handing to a debugger. Zephyr links more than once:
-- zephyr_pre0.elf and friends are intermediate passes, not the image on the chip.
local function elves_under(dir)
  local found = vim.fs.find(function(name, path)
    return not path:match "/CMakeFiles"
      and vim.fn.fnamemodify(name, ":e") == "elf"
      and not name:match "^zephyr_pre%d"
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
-- running commands
--------------------------------------------------------------------------------

-- Instant queries only - listing presets, reading a cache. `vim.fn.systemlist`
-- blocks the event loop until the child exits, so anything that compiles goes
-- through `run_windowed` instead.
local function run(cmd)
  local out = vim.fn.systemlist(cmd)
  return vim.v.shell_error == 0, out
end

-- Zephyr compiles with -fdiagnostics-color=always, so gcc colours its output
-- even into a pipe. Left in, the escapes show up as litter in the window and
-- stop errorformat matching in the quickfix list.
local function clean(line) return (line:gsub("\27%[[%d;?]*%a", ""):gsub("\r", "")) end

-- A scratch float, opened without focus so it never steals the cursor or the
-- keys dap is about to want back.
local function output_window(label)
  local width = math.min(140, math.floor(vim.o.columns * 0.9))
  local height = math.max(10, math.floor(vim.o.lines * 0.6))
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2 - 1),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. label .. " ",
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end

  -- appended to rather than replaced, and the cursor dragged along behind it:
  -- the window is unfocused, so nothing else moves the cursor, and a window
  -- whose cursor sits on line 1 shows the head of the build for its whole run
  local function append(new)
    if #new == 0 or not vim.api.nvim_buf_is_valid(buf) then return end
    local blank = vim.api.nvim_buf_line_count(buf) == 1
      and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
    vim.api.nvim_buf_set_lines(buf, blank and 0 or -1, -1, false, new)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, desc = "close build output" })
  return append, close
end

-- jobstart splits on newlines, but the first element of each chunk continues the
-- previous chunk's last element and the last element is always incomplete - so
-- the tail has to be held over, and flushed once the stream ends.
local function line_reader(sink)
  local held = ""
  local function on_data(_, data)
    if not data then return end
    data[1] = held .. (data[1] or "")
    held = table.remove(data) or ""
    sink(data)
  end
  local function flush()
    if held ~= "" then
      sink { held }
      held = ""
    end
  end
  return on_data, flush
end

-- Anything that compiles: run as a job with its output streaming into a float,
-- and the calling coroutine resumed once it exits. nvim-dap resolves `program`
-- inside a coroutine - the property `choose` already relies on to show a picker
-- - so yielding here leaves the editor responsive for the whole build instead of
-- freezing it until the build happens to finish.
--
-- Deliberately not a terminal: a pty hard-wraps at the window width, and a
-- wrapped gcc diagnostic is one errorformat can no longer parse.
local function run_windowed(cmd, label)
  local co = coroutine.running()
  if not co then return run(cmd) end

  local append, close = output_window(label)
  local out = {}

  local function sink(new)
    local stripped = {}
    for _, line in ipairs(new) do
      stripped[#stripped + 1] = clean(line)
    end
    vim.list_extend(out, stripped)
    append(stripped)
  end

  local on_stdout, flush_stdout = line_reader(sink)
  local on_stderr, flush_stderr = line_reader(sink)

  local job = vim.fn.jobstart(cmd, {
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = function(_, code)
      flush_stdout()
      flush_stderr()
      -- left open on failure: the log is the point
      if code == 0 then close() end
      coroutine.resume(co, code)
    end,
  })

  -- on_exit never fires for a job that failed to start, so nothing would ever
  -- come back to resume the yield below
  if job <= 0 then
    close()
    error("could not start: " .. table.concat(cmd, " "))
  end

  return coroutine.yield() == 0, out
end

-- A whole failed build is far too much for a notification - 90 lines and 16kB
-- for one failed Zephyr build - and it opens with progress, so the part worth
-- reading is past wherever the notifier stops. The log stays on screen in the
-- window; the diagnostics go to the quickfix list, where errorformat can parse
-- them and <CR> jumps to the file. The raised error is one line.
local function build_failed(label, out)
  vim.fn.setqflist({}, "r", { title = label, lines = out })
  local valid = vim.tbl_filter(function(item) return item.valid == 1 end, vim.fn.getqflist())
  if #valid > 0 then
    return string.format("%s failed - %d in the quickfix list (:copen)", label, #valid)
  end
  return label .. " failed - output is in the window"
end

--------------------------------------------------------------------------------
-- cmake presets
--------------------------------------------------------------------------------

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

-- The build presets paired with this configure preset, in file order, each with
-- the targets it names. Cross-checked against cmake's own list, so a preset that
-- `condition` rules out on this machine is left out.
local function build_presets_for(configure_preset)
  local ok, out = run { "cmake", "--list-presets=build" }
  if not ok then return {} end
  local available = {}
  for _, line in ipairs(out) do
    local name = line:match '^%s*"([^"]+)"'
    if name then available[name] = true end
  end

  local found = {}
  local path = vim.fn.getcwd() .. "/CMakePresets.json"
  if vim.fn.filereadable(path) == 1 then
    local decoded, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if decoded then
      for _, preset in ipairs(data.buildPresets or {}) do
        if preset.configurePreset == configure_preset and available[preset.name] then
          -- the schema allows a bare string as well as a list
          local targets = preset.targets or {}
          if type(targets) == "string" then targets = { targets } end
          found[#found + 1] = { name = preset.name, targets = targets }
        end
      end
    end
  end
  return found
end

-- Zephyr's `pristine` target empties the build directory, cache included, so a
-- preset naming it is a wipe rather than a build: never the one to build with,
-- and the only one worth offering as "start from scratch".
local function is_pristine(preset) return vim.tbl_contains(preset.targets, "pristine") end

-- A build preset paired with this configure preset, if the project defines one.
-- The one that builds is the one naming no targets of its own: a preset carrying
-- an explicit target list is a step - pristine, flash - and not the build. Going
-- by position instead would make this depend on the order of the json.
local function build_preset_for(configure_preset)
  for _, preset in ipairs(build_presets_for(configure_preset)) do
    if #preset.targets == 0 then return preset.name end
  end
  return nil
end

local function pristine_preset_for(configure_preset)
  for _, preset in ipairs(build_presets_for(configure_preset)) do
    if is_pristine(preset) then return preset.name end
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

-- Choose a preset and build it, then hand back the directory it built into. What
-- is worth debugging in there depends on the target, so the callers below decide.
local function cmake_preset_build()
  vim.cmd "wall"

  local presets = configure_presets()
  if #presets == 0 then
    error "no usable CMake configure presets here (cmake --list-presets=configure came back empty)"
  end

  local chosen = choose(presets, "CMake preset")
  if not chosen then error "no preset chosen" end
  local name = chosen.name

  local binary_dir = preset_binary_dir(name)

  -- Pristine is offered as a modifier on the chosen preset rather than as its own
  -- entry in the list above: it wipes the tree and leaves nothing built, so it
  -- only means anything as the first half of a from-scratch build. Nothing
  -- configured yet means nothing to wipe, so there is no question to ask.
  local pristine = pristine_preset_for(name)
  if pristine and vim.fn.filereadable(binary_dir .. "/CMakeCache.txt") == 1 then
    local how = choose({
      { name = "incremental", label = "incremental build" },
      { name = "pristine", label = "pristine first (" .. pristine .. ")" },
    }, "build " .. name)
    if not how then error "no build mode chosen" end
    if how.name == "pristine" then
      local ok, out = run_windowed({ "cmake", "--build", "--preset", pristine }, pristine)
      if not ok then error(build_failed(pristine, out)) end
      -- the wipe took CMakeCache.txt with it, so needs_configure now says yes
    end
  end

  if needs_configure(binary_dir) then
    local label = "cmake --preset " .. name
    local ok, out = run_windowed({ "cmake", "--preset", name }, label)
    if not ok then error(build_failed(label, out)) end
  end

  local build_preset = build_preset_for(name)
  local cmd = build_preset and { "cmake", "--build", "--preset", build_preset }
    or { "cmake", "--build", binary_dir }
  local label = table.concat(cmd, " ")
  local ok, out = run_windowed(cmd, label)
  if not ok then error(build_failed(label, out)) end

  return binary_dir, name
end

-- For a launch: something the host can actually run.
local function cmake_preset_program()
  local binary_dir, name = cmake_preset_build()
  local found = candidates_under(binary_dir)
  if #found == 0 then
    error(string.format(
      "nothing launchable under %s - a cross-built target has no host binary, use the gdbserver configuration",
      binary_dir
    ))
  end
  return choose(found, "binary from " .. name)
end

-- For an attach: the elf holding the symbols for whatever is already on the chip.
local function cmake_preset_elf()
  local binary_dir, name = cmake_preset_build()
  local found = elves_under(binary_dir)
  if #found == 0 then error("no elf under " .. binary_dir) end
  return choose(found, "elf from " .. name)
end

--------------------------------------------------------------------------------
-- on-target: build, flash, then attach
--------------------------------------------------------------------------------

local GDB_PORT = 3333

-- The flash step among a configure preset's build presets: the one naming a
-- target with "flash" in it - `target-flash-step` here, which drives west-flash.
-- `build_preset_for` picks the preset naming *no* targets, so the two never
-- collide.
local function flash_preset_for(configure_preset)
  for _, preset in ipairs(build_presets_for(configure_preset)) do
    for _, target in ipairs(preset.targets) do
      if target:lower():find("flash", 1, true) then return preset.name end
    end
  end
  return nil
end

-- LinkServer's progress lines. It reaches "Target Ready" once the probe is
-- connected, the flash device is identified and the gdb stub is listening. It
-- also announces its own teardown, which is what distinguishes a stub that died
-- early from one that is merely slow to come up.
-- LinkServer prints "Pc: (100) Target Ready" once it is serving, but that line is
-- not what is waited on. west pipes LinkServer's output, and with a pipe rather
-- than a tty on the far end nothing flushes promptly: measured here, port 3333
-- was accepting connections while only 44 of the eventual 104 lines had arrived,
-- the readiness line among the missing ones. Waiting for it leaves the window
-- sitting open until the timeout even though the stub is up.
--
-- The port is polled instead. It is the thing that actually has to be true before
-- gdb can attach, and it cannot be buffered.
--
-- Its teardown line is still watched, because that arrives on the way out when
-- the pipe is flushed and it distinguishes a stub that died from one still coming
-- up.
local CLOSED = "has closed"
local POLL_MS = 400
local READY_TIMEOUT_MS = 90000
-- Empirical, and the reason is in the poll below: the port appears before the
-- stub can serve gdb.
local SETTLE_MS = 2000

local server = { job = nil }

-- A stub may already be listening because one was started by hand in another
-- pane, and only one process can hold the port regardless.
local function server_listening()
  local ok = run { "sh", "-c", string.format("ss -ltn 2>/dev/null | grep -q ':%d '", GDB_PORT) }
  return ok
end

local function stop_server()
  if not server.job then return end
  pcall(vim.fn.jobstop, server.job)
  server.job = nil
end

-- Started as a bare job rather than through run_windowed, which waits for the
-- command to exit - this one is meant to outlive the call and run for the whole
-- session. The calling coroutine is resumed as soon as LinkServer reports the
-- target ready, so the attach cannot race the stub coming up.
--
-- The board's runners.yaml sets `debug-runner: jlink` while flash-runner is
-- linkserver, so the build system's own `debugserver` target would start the
-- wrong server entirely. The runner is named explicitly here.
local function start_server(build_dir)
  local co = coroutine.running()
  local label = "west debugserver --runner linkserver"
  local append, close = output_window(label)
  local settled = false

  local function settle(ok, reason)
    if settled then return end
    settled = true
    -- Left open on failure: the log is the only account of why the probe or the
    -- stub would not come up.
    if ok then close() end
    coroutine.resume(co, ok, reason)
  end

  local function sink(new)
    local stripped = {}
    for _, line in ipairs(new) do
      stripped[#stripped + 1] = clean(line)
    end
    append(stripped)
    for _, line in ipairs(stripped) do
      if line:find(CLOSED, 1, true) then settle(false, "the gdb stub closed before it was ready") end
    end
  end

  local on_stdout, flush_stdout = line_reader(sink)
  local on_stderr, flush_stderr = line_reader(sink)

  -- Expect this window to stall partway through LinkServer's startup and only
  -- fill in when the process ends: see the note on buffering above. `stdbuf -oL`
  -- was tried and changes nothing, so LinkServer is not buffering through libc
  -- stdio and LD_PRELOAD cannot reach it - do not re-add it.
  server.job = vim.fn.jobstart({
    "west", "debugserver", "--runner", "linkserver", "--build-dir", build_dir,
  }, {
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = function(_, code)
      flush_stdout()
      flush_stderr()
      server.job = nil
      settle(false, "west debugserver exited with " .. code)
    end,
  })

  if server.job <= 0 then
    close()
    error("could not start " .. label)
  end

  -- Polled rather than connected to: opening a socket to test the stub would look
  -- to LinkServer like a gdb client arriving and immediately leaving, and it shuts
  -- down when its client disconnects. `ss` only reads the kernel's listen table.
  --
  -- The timeout matters as much as the poll. A probe that enumerates but will not
  -- connect leaves the stub alive and silent, and with nothing to resume the
  -- coroutine the whole thing would appear to have hung.
  local waited = 0
  local function poll()
    if settled then return end
    if server_listening() then
      -- The listening socket is necessary but not sufficient. LinkServer's front
      -- end accepts the connection before its backend (crt_emu_cm_redlink) can
      -- answer the gdb protocol, and attaching inside that window half-connects:
      -- qSupported comes back with a literal "timeout", vMustReplyEmpty fails,
      -- monitor commands are rejected as unsupported, and the session ends up with
      -- no target at all. Reproduced by attaching immediately after the port
      -- appeared. There is no earlier signal to wait on - LinkServer's own
      -- progress output, "Target Ready" included, is only produced in response to
      -- a client attaching, so it cannot precede the attach - hence a settle
      -- delay rather than a landmark.
      return vim.defer_fn(function() settle(true) end, SETTLE_MS)
    end
    waited = waited + POLL_MS
    if waited >= READY_TIMEOUT_MS then
      return settle(false, string.format("%s never opened port %d", label, GDB_PORT))
    end
    vim.defer_fn(poll, POLL_MS)
  end
  vim.defer_fn(poll, POLL_MS)

  local ok, reason = coroutine.yield()
  if not ok then
    stop_server()
    error(reason .. " - output is in the window")
  end
end

-- One configuration for the whole cycle: build the preset, flash what it built,
-- bring the stub up, and hand back the elf for the attach. The order matters -
-- flashing resets the part, so the stub is started after it, not before.
local function target_session()
  local binary_dir, name = cmake_preset_build()

  local flash = flash_preset_for(name)
  local cmd = flash and { "cmake", "--build", "--preset", flash }
    or { "cmake", "--build", binary_dir, "--target", "flash" }
  local label = table.concat(cmd, " ")
  local ok, out = run_windowed(cmd, label)
  if not ok then error(build_failed(label, out)) end

  if not server_listening() then start_server(binary_dir) end

  local found = elves_under(binary_dir)
  if #found == 0 then error("no elf under " .. binary_dir) end
  return choose(found, "elf from " .. name)
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

    -- built once in the window with cargo's ordinary human-readable output, then
    -- asked again for the machine-readable artifact list. The second call
    -- compiles nothing - cargo still reports `executable` for crates it finds
    -- fresh - so it costs a freshness check rather than a rebuild.
    local built, log = run_windowed(vim.list_extend({ "cargo", "build" }, args), label)
    if not built then error(build_failed(label, log)) end

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
      -- The whole cycle, unattended: pick a preset, build it, flash the part,
      -- start the LinkServer stub and attach to it. Nothing else needs to be
      -- running first. The two configurations below stay for the cases this
      -- does not cover - a server already up, or an image someone else flashed.
      name = "Build, flash and debug on target (LinkServer)",
      type = "gdb_remote",
      request = "attach",
      target = "localhost:" .. GDB_PORT,
      program = target_session,
    },
    {
      -- Build for the board, then attach to whatever is serving it. Start the
      -- server first, in its own terminal: `west debugserver` uses the board's
      -- default runner - linkserver on vt_rt1160, which listens on 3333, as do
      -- `west debugserver --runner pyocd` and pyocd's own gdbserver. Note
      -- JLinkGDBServer defaults to 2331 instead.
      name = "Build a CMake preset, then attach to gdbserver (localhost:3333)",
      type = "gdb_remote",
      request = "attach",
      target = "localhost:3333",
      program = cmake_preset_elf,
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
    args = {
      "--interpreter=dap",
      "--eval-command", "set print pretty on",
      -- Cortex-M peripheral registers sit outside anything the elf describes, and
      -- gdb refuses to read memory it has no section for. Without this, every
      -- peripheral address in a watch expression comes back an error rather than
      -- a value - which reads as a broken debugger rather than a setting.
      "--eval-command", "set mem inaccessible-by-default off",
      -- gdb defers loading the elf until configurationDone, but nvim-dap sends
      -- setBreakpoints before that, so every breakpoint is created against an
      -- empty symbol table and cannot resolve yet. Held pending, they resolve the
      -- moment the elf loads; dropped, they are gone for the session. Measured
      -- against this board's elf: `pending off` discards them silently, `pending
      -- on` resolves them to a real address once the file arrives.
      --
      -- The default is `auto`, which asks - and in DAP mode the query is
      -- auto-answered, so pending breakpoints do get created either way. This
      -- makes that explicit rather than depending on how an unattended query
      -- happens to be resolved.
      "--eval-command", "set breakpoint pending on",
      -- Declaring the XIP flash read-only *before* gdb connects is what makes
      -- breakpoints in it actually fire.
      --
      -- gdb chooses hardware vs software per breakpoint from what it knows about
      -- the address, and it learns the real layout only from the target's memory
      -- map - which does not exist until `target remote`. nvim-dap creates
      -- breakpoints before the attach (gdb defers the attach to
      -- configurationDone), so with no map gdb assumes writable memory and plans
      -- a software breakpoint: a BKPT written into XIP flash, which cannot stick.
      -- It still answers verified = true, and then never fires.
      --
      -- The tell is one missing line. Connected first, gdb says
      --   Note: automatically using hardware breakpoints for read-only addresses.
      -- Breakpoint-first, that note is absent - which is exactly what the nvim
      -- session logged.
      --
      -- 0x30000000-0x32000000 is this board's external QSPI flash: LinkServer
      -- reports "32MB = 256*128K at 0x30000000", and the target-supplied map calls
      -- the same range flash once connected.
      "--eval-command", "mem 0x30000000 0x32000000 ro",
    },
  }
  -- The same adapter against a gdb that knows non-host architectures, but as a
  -- function so it can see the resolved configuration.
  --
  -- nvim-dap's M.run calls prepare_config first - which is where `program` is
  -- produced, and for the target configuration that means the whole build, flash
  -- and stub startup - and only then looks up the adapter, handing a function
  -- adapter the finished config. So `config.program` is known by the time this
  -- runs.
  --
  -- Loading the elf here rather than leaving it to the attach is the point. gdb
  -- defers `file <elf>` until configurationDone, but nvim-dap sends setBreakpoints
  -- before that, so at the moment a breakpoint is created gdb has no symbol table
  -- and answers `No source file named .../src/main.c`. `set breakpoint pending on`
  -- does not save it: gdb's DAP creates breakpoints through the Python API with an
  -- explicit source and line, and that form resolves eagerly instead of going
  -- pending. Loading the symbols before the first breakpoint arrives is what makes
  -- them resolve. The attach re-files the same elf afterwards, which is harmless.
  dap.adapters.gdb_remote = function(callback, config)
    local args = vim.list_extend({}, dap.adapters.gdb.args)
    if type(config.program) == "string" and config.program ~= "" then
      -- `file` takes the rest of the line as the filename, so no quoting.
      vim.list_extend(args, { "--eval-command", "file " .. config.program })
    end
    callback { type = "executable", command = "gdb-multiarch", args = args }
  end

  -- gdb's DAP has no postLaunchCommands, so anything that has to happen after the
  -- connection goes through an evaluate request in the repl context - which gdb
  -- treats as a gdb command line.
  -- No post-attach commands at all, and that is the tested configuration.
  --
  -- What was here, and why each thing went:
  --
  --   monitor reset + load   Zephyr's linkserver runner issues this pair for
  --                          `west debug`, and it is right for a plain image, but
  --                          it destroys a signed one. west flash writes
  --                          header-plus-application into the mcuboot slot at
  --                          0x30040000 (sign step: partition offset 0x40000, rom
  --                          start offset 0x400) while the elf links rom_start
  --                          directly at 0x30040000, so `load` overwrites the
  --                          header. The slot stops validating and the part parks
  --                          in the bootloader (measured pc 0x3000874a) or the boot
  --                          ROM (0x0022xxxx). Nothing runs, so nothing hits.
  --                          Recovery needs another west flash.
  --   monitor reset alone    Tears the connection down - every register read after
  --                          it fails with 'remote failure reply 22'.
  --   monitor semihosting    Makes the debugger trap BKPT 0xAB. Any semihosting
  --                          call in the application then halts it, which presents
  --                          as the application freezing after attach.
  --
  -- There is also no way to reset the part from here: `monitor help` offers no
  -- reset-and-halt, LinkServer's -a/--attach only suppresses resets, and AIRCR is
  -- unreachable - writing SYSRESETREQ to 0xE000ED0C answers "Cannot access
  -- memory", because the stub's memory map advertises only RAM and flash.
  --
  -- So this is an attach to a running system. west flash has already reset the
  -- part and let it boot, so startup and main have executed by the time gdb
  -- connects; breakpoints in code that runs afterwards hit normally. Verified on
  -- hardware with nothing sent after the attach: a breakpoint on arch_cpu_idle
  -- reported "breakpoint already hit 1 time".
  --
  -- The stop in cmsis_gcc.h that greets you is not a fault: `target remote` halts
  -- the core, and the idle loop is simply where an idle application is.


  -- The stub exits by itself when gdb drops the connection, but not when the
  -- attach never got that far - a failed session would otherwise leave it holding
  -- the port and the probe.
  for _, event in ipairs { "event_terminated", "event_exited", "disconnect" } do
    dap.listeners.after[event]["dap.lua"] = stop_server
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("dap_debugserver", { clear = true }),
    desc = "Stop a debugserver this session started",
    callback = stop_server,
  })

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
