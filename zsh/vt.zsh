# Helpers for working inside the SDKZ container. Sourced from zshrc only when
# SDKZ_IMAGE_VERSION is set, so these never appear on the host.

# Locates the workspace's apps directory. Walks up from the current directory
# first, so it works from anywhere inside the workspace, and falls back to the
# one workspace folder under the west topdir. Used by vtbuild and its completion.
vt-apps-dir() {
  local dir=$PWD
  while [[ $dir != / ]]; do
    [[ -d $dir/apps ]] && { print -r -- $dir/apps; return 0 }
    dir=${dir:h}
  done

  local topdir
  topdir=$(west topdir 2>/dev/null) || return 1
  local -a found=($topdir/*/apps(N/))
  (( $#found )) && { print -r -- $found[1]; return 0 }
  return 1
}

# vtbuild - wrapper around `west build` for the C4.3 workspace.
#
#   vtbuild [--target|--sim] [--debug|--release] [-p] [--export] [app] [-- cmake args]
#
# Board and shield follow the target/sim choice, matching what the container
# test suite builds (sdkz_docker tests/container/workspaces/C4.3/test_builds.py):
#
#   --target  vt_rt1160/mimxrt1166/cm7  shield c4p3      (default)
#   --sim     veethree_sim              shield c4p3_sim
#
# --debug / --release set -DCMAKE_BUILD_TYPE, debug being the default. -p is
# passed through as west's pristine flag, which is what you want when switching
# between target and sim in the same build directory.
#
# The app is a directory under the workspace's apps folder. With none given the
# current directory is built, so `vtbuild` on its own works from inside an app.
# Either way the build lands in the app's own directory, at <app>/build, unless
# -d says otherwise.
#
# --export copies the build's compile_commands.json to the root of the west
# workspace, where clangd finds it by walking up from whatever file is open -
# including sources in the modules and in zephyr itself.
#
# Unrecognised flags are handed to `west build`, and anything after `--` is
# handed to CMake, so the wrapper never blocks the underlying command.
vtbuild() {
  local board="vt_rt1160/mimxrt1166/cm7" shield="c4p3"
  local build_type="Debug"
  local build_dir="build"
  local app="" export_cc=0 build_dir_given=0
  local -a west_args cmake_args

  while (( $# )); do
    case $1 in
      --target)       board="vt_rt1160/mimxrt1166/cm7"; shield="c4p3" ;;
      --sim)          board="veethree_sim";             shield="c4p3_sim" ;;
      --debug)        build_type="Debug" ;;
      --release)      build_type="Release" ;;
      -p|--pristine)  west_args+=(-p) ;;
      --export)       export_cc=1 ;;
      -d|--build-dir) build_dir=$2; build_dir_given=1; west_args+=($1 $2); shift ;;
      -h|--help)
        print "usage: vtbuild [--target|--sim] [--debug|--release] [-p] [--export] [app] [-- cmake args]"
        print "  app        directory under the workspace apps folder, default is the cwd"
        print "  --target   vt_rt1160/mimxrt1166/cm7, shield c4p3 (default)"
        print "  --sim      veethree_sim, shield c4p3_sim"
        print "  --debug    -DCMAKE_BUILD_TYPE=Debug (default)"
        print "  --release  -DCMAKE_BUILD_TYPE=Release"
        print "  -p         pristine build"
        print "  --export   copy compile_commands.json to the west workspace root"
        return 0
        ;;
      --)             shift; cmake_args+=("$@"); break ;;
      -*)             west_args+=($1) ;;
      *)              app=$1 ;;
    esac
    shift
  done

  # An app name resolves under the apps folder. A path that already exists is
  # taken as given, so `vtbuild ../someapp` and tab completed paths both work.
  local source=""
  if [[ -n $app ]]; then
    local apps
    apps=$(vt-apps-dir)
    if [[ -n $apps && -d $apps/$app ]]; then
      source=$apps/$app
    elif [[ -d $app ]]; then
      source=$app
    else
      print -u2 "vtbuild: no such app '$app'${apps:+ in $apps}"
      return 1
    fi
  fi

  # Build inside the app, so each app keeps its own build directory and its own
  # compile_commands.json rather than every build landing in whichever directory
  # vtbuild happened to be run from. With no app named the cwd is the app, and
  # west's own default puts build/ there already.
  if (( ! build_dir_given )) && [[ -n $source ]]; then
    build_dir=$source/build
    west_args+=(-d $build_dir)
  fi

  local -a cmd
  cmd=(west build -b $board --shield $shield $west_args)
  [[ -n $source ]] && cmd+=(-s $source)
  cmd+=(-- -DCMAKE_BUILD_TYPE=$build_type $cmake_args)

  print -r -- "\$ ${(j: :)cmd}"
  $cmd || return $?

  (( export_cc )) || return 0

  local topdir
  topdir=$(west topdir 2>/dev/null)
  if [[ -z $topdir ]]; then
    print -u2 "vtbuild: --export needs a west workspace, and west topdir found none"
    return 1
  fi

  # A configure that fails never reaches the generate step, so the database is
  # absent rather than stale. Say which it is instead of failing on the copy.
  if [[ ! -f $build_dir/compile_commands.json ]]; then
    print -u2 "vtbuild: no $build_dir/compile_commands.json - cmake writes it at the end"
    print -u2 "         of a successful configure, so check the build output above"
    return 1
  fi

  cp $build_dir/compile_commands.json $topdir/compile_commands.json || return $?
  print "exported compile_commands.json -> $topdir/compile_commands.json"
}
