-- User snippets for shell buffers.
--
-- Filename is the filetype. `sh` is the right one: Neovim gives every shell
-- script ft=sh regardless of shebang or extension - a .bash file and a .sh file
-- with `#!/bin/bash` both come out as sh, with the dialect recorded in
-- b:is_bash. A bash.lua here would never load.
--
-- Picked up automatically by AstroNvim's from_lua.lazy_load(), which is called
-- with no paths and so scans the runtimepath, of which ~/.config/nvim is the
-- first entry. No plugin spec, and nothing in plugins/ needs editing - these
-- accumulate alongside the ANSI snippets and friendly-snippets rather than
-- replacing either.
--
-- The loader injects LuaSnip's constructors (s, t, i, c, f, d, rep) into this
-- file's environment, so there is no require here.

return {
  -- A hand-rolled loop rather than either of the two getopt implementations,
  -- because both fall down on long options:
  --
  --   getopts (bash builtin)  short options only. Long options are possible by
  --                           putting '-' in the optstring and re-parsing
  --                           $OPTARG, but that means indirect expansion via
  --                           ${!OPTIND} and fixing up OPTIND by hand to tell
  --                           `--board x` from `--board=x`.
  --   getopt(1) (util-linux)  does long options, but only the GNU version. macOS
  --                           ships the BSD one, which has no --long at all, so
  --                           anything written this way needs a brewed
  --                           gnu-getopt to run there. It also requires eval.
  --
  -- This loop is plain bash, needs no eval and behaves the same on Linux and
  -- macOS. Each arm owns its own shift count, which is the price of dropping
  -- getopts - as is losing bundling, so `-hv` stays unrecognised where getopts
  -- would have split it into -h -v.
  --
  -- Positionals are collected into args as they are met rather than assumed to
  -- come last, so `script foo -v bar` works. The closing `set --` puts them back
  -- into "$@" ahead of anything that followed a literal --.
  --
  -- Only --help is here by design: this is a starting point, and every real
  -- script wants a different option set. A flag is one line,
  --
  --     -v|--verbose) verbose=1; shift ;;
  --
  -- and one that takes a value is two, because `--board x` and `--board=x`
  -- arrive differently - the first as two words, the second as one:
  --
  --     -b|--board)   board=$2; shift 2 ;;
  --     --board=*)    board=${1#*=}; shift ;;
  --
  -- Both go above the fixed --/-*/* arms. The =* form in particular has to
  -- precede the catch-all -*, or that glob swallows it and calls it unknown.
  -- Initialise anything they set in the defaults block above the loop.
  --
  -- Two things to know if you add `set -u`: `board=$2` on a final `-b` with no
  -- value will trip it (guard with ${2:?} if that matters), and
  -- "${args[@]}" on an empty array is only safe from bash 4.4.
  s({ trig = "getopt", desc = "long and short option parsing loop" }, {
    t { "usage() {", "\tcat >&2 <<EOF", "Usage: ${0##*/} " },
    i(1, "[-h] [ARG...]"),
    t { "", "" },
    i(2, {
      "  -h, --help   show this help",
    }),
    t { "", "EOF", "}", "", "" },
    i(3, "args=()"),
    -- Indentation is baked into every line of the insert node rather than left
    -- to the preceding text node. A text node ending in "\t\t" indents only the
    -- first line of the node that follows it; the rest of a multi-line default
    -- would land at column 0.
    t { "", "", "while [[ $# -gt 0 ]]; do", "\tcase $1 in", "" },
    i(4, {
      "\t\t-h|--help) usage; exit 0 ;;",
    }),
    t {
      "",
      "\t\t--)        shift; break ;;",
      "\t\t-*)        echo \"ERROR: unknown option $1\" >&2; usage; exit 2 ;;",
      "\t\t*)         args+=(\"$1\"); shift ;;",
      "\tesac",
      "done",
      "set -- \"${args[@]}\" \"$@\"",
      "",
      "",
    },
    i(0),
  }),

  -- Standalone usage(), for scripts that want the help text without the whole
  -- getopts apparatus. Same shape as the one the `getopt` snippet embeds, so the
  -- two stay consistent if a script later grows option parsing.
  --
  -- A heredoc rather than a run of echo lines: the text stays readable as text,
  -- with no quoting to maintain per line and no `echo -e` portability question.
  -- Unquoted EOF on purpose, so ${0##*/} expands.
  --
  -- >&2 because usage is nearly always printed on the way out of an error, and a
  -- caller redirecting stdout should still see why it failed. The `-h` path is
  -- the exception; call `usage` there and let it go to stderr anyway rather than
  -- splitting the function in two.
  --
  -- ${0##*/} rather than $0 so the message names the script rather than whatever
  -- path it happened to be invoked by, and rather than basename(1) so it costs
  -- no subprocess.
  s({ trig = "usage", desc = "usage() function printing script usage" }, {
    t { "usage() {", "\tcat >&2 <<EOF", "Usage: ${0##*/} " },
    i(1, "[-h] [ARG...]"),
    t { "", "" },
    i(2, {
      "  -h    show this help",
    }),
    t { "", "EOF", "}", "" },
    i(0),
  }),
}
