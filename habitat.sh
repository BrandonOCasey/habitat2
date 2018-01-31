habitat_help() {
  echo
  echo "  Usage: . habitat [options]"
  echo
  echo "  -d, --debug          print debug statements"
  echo "  -c, --check          check for git changes before run/build, off by default"
  echo "  -f, --force          force a rebuild right now"
  echo "  -fb, --force-build   alias for force"
  echo "  -t, --time <mins>    time between rebuilds in minutes, defaults is 20160 (14 days)"
  echo "  -nr, --no-run        don't run"
  echo "  -nb, --no-build      don't build"
  echo "  -h, --help           show this help"
  echo
}

habitat_exec() {
  if [ "$HABITAT_DEBUG" = "0" ]; then
    "$@"
    return "$?"
  fi
  local retval;

  local old_TIMEFORMAT="$TIMEFORMAT"
  TIMEFORMAT="%Rs"; time "$@"
  retval="$?"
  # 6 spaces so that we are after the time output then
  # go up one line, so we can print on the same line as the time output
  local back=$'      \e[1A'
  echo "$back: $(echo "$@" | sed "s~$HABITAT_DIR/~~g")" 1>&2

  TIMEFORMAT="$old_TIMEFORMAT"
  return "$retval"
}

habitat_git_check() {
  if [ ! -d "$HABITAT_DIR/.git" ]; then
    return
  fi

  (cd "$HABITAT_DIR" && git remote update >/dev/null 2>&1)
  local UPSTREAM="${1:-@{u}}"
  local LOCAL="$(cd "$HABITAT_DIR" && git rev-parse @)"
  local REMOTE="$(cd "$HABITAT_DIR" && git rev-parse "$UPSTREAM")"
  local BASE="$(cd "$HABITAT_DIR" && git merge-base @ "$UPSTREAM")"

  if [ "$LOCAL" = "$REMOTE" ] && [ "$HABITAT_DEBUG" = 1 ]; then
    echo "settings are up to date on git"
  elif [ "$LOCAL" = "$BASE" ]; then
    # pull needed
    (cd "$HABITAT_DIR" && git pull -q  >/dev/null 2>&1)
  elif [ "$REMOTE" = "$BASE" ]; then
    # push needed
    echo "You need to push your new habitat settings"
  else
    # fix needed
    echo "Your habitat git repo has diverged from master!"
  fi
}

habitat_build() {
  local build_dir="$1"; shift
  local lock_file="$build_dir/lock"
  local syml="$build_dir/syml"
  local new_dir="$build_dir/new-build-$RANDOM"
  local old_dir="$(readlink "$syml")"

  echo "Building your habitat!"
  mkdir -p "$build_dir"

  [ -f "$lock_file" ] && echo "habitat build is locked" && return

  # start lock so other environments cannot build
  touch "$lock_file"

  mkdir -p "$new_dir/"{lib,plugins}
  while read -r file; do
    newfile="$file"
    dir="$(dirname "$file")"
    if echo "$file" | grep -q "^plugins"; then
      newfile="$(echo "$dir" | sed 's~/~-~g' | sed 's~plugins-~plugins/~').sh"
    fi
    habitat_exec "$HABITAT_DIR/$file" "$HABITAT_DIR/$dir" "$HABITAT_DIR/dotfiles" >> "$new_dir/$newfile"
  done <<< "$(find "$HABITAT_DIR/"{lib,plugins} -type f -perm +111 | sed "s~$HABITAT_DIR/~~")"


  # replace
  # syml -> old_dir
  # with
  # syml -> new_dir
  ln -sfn "$new_dir" "$syml"
  [ -d "$old_dir" ] && rm -rf "$old_dir"

  # remove lock so other environments can build
  rm -f "$lock_file"

}

habitat_run() {
  local build_dir="$1"; shift

  while read -r file; do
    habitat_exec . "$file"
  done <<< "$(find -L "$build_dir/syml/lib" "$build_dir/syml/plugins" -name '*.sh')"
}

habitat_main() {
  local build_dir="$HABITAT_DIR/.build"
  [ ! -d "$build_dir" ] && mkdir -p "$build_dir"
  local rebuild_time=20160
  local run=1
  local build=1
  local check=0
  export HABITAT_DEBUG=0

  while [ $# -gt 0 ]; do
    local argv="$1"; shift

    case "$argv" in
      -d|--debug) export HABITAT_DEBUG=1 ;;
      -h|--help) habitat_help && return ;;
      -t|--time) [ -n "$1" ] && rebuild_time="$1" && shift || rebuild_time='invalid';;
      -f|--force|-fb|--force-build) rebuild_time=0 ;;
      -c|--check) check=1 ;;
      -nr|--no-run) run=0 ;;
      -nb|--no-build) build=0 ;;
      *) echo "invalid option $argv" 1>&2 && return 1;;
    esac
  done

  if ! echo "$rebuild_time" | grep -Eq "[0-9]+"; then
    echo "Must pass a number with --time" 2>&1
    return 1
  fi

  if [ "$check" = 1 ]; then
    habitat_git_check
  fi

  habitat_total() {
    # if its time to rebuild
    if [ "$build" = 1 ] && [ -z "$(find "$build_dir/syml" -type l -mmin "-${rebuild_time}" 2>/dev/null)" ]; then
      habitat_exec habitat_build "$build_dir"
    fi

    if [ "$run" = 1 ]; then
      habitat_exec habitat_run "$build_dir"
    fi
  }

  habitat_exec habitat_total
}


habitat_clean() {
  unset -f habitat_build
  unset -f habitat_run
  unset -f habitat_help
  unset -f habitat_main
  unset -f habitat_clean
  unset -f habitat_git_check
  unset -f habitat_exec
  unset -f habitat_total
  unset HABITAT_DEBUG
}

# used to determine if this script is sourced or run as a binary
# shellcheck disable=SC2091
$(return >/dev/null 2>&1)

# shellcheck disable=SC2181
if [ "$?" != "0" ]; then
  echo "Script must be sourced, not run"
  exit 1
fi

if [ -z "$HABITAT_DIR" ] || [ ! -d "$HABITAT_DIR" ]; then
  echo "HABITAT_DIR must be set and exist before sourcing habitat" 2>&1
  return 1
fi

export HABITAT_DIR="$HABITAT_DIR"
alias habitat='. "$HABITAT_DIR/habitat.sh"'

habitat_main "$@"
retval="$?"
habitat_clean
return "$retval"
