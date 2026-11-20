# 统一 lint / format 入口（zsh）
# 工具缺失时给提示，不刷 command not found。
# 依赖：~/.config/dev-toolbox 中的配置文件与全局工具链。

_lint_need() {
  local cmd=$1 hint=$2
  if ! (( $+commands[$cmd] )); then
    print -u2 "✗ 缺少 $cmd → $hint"
    return 127
  fi
}

# 项目内优先，全局兜底（ESLint / Prettier / Stylelint / markdownlint）
_lint_js_bin() {
  local tool=$1
  shift
  if [[ -x node_modules/.bin/$tool ]]; then
    node_modules/.bin/$tool "$@"
  elif (( $+commands[$tool] )); then
    command "$tool" "$@"
  else
    print -u2 "✗ 缺少 $tool → npm i -D $tool"
    return 127
  fi
}

_lint_sh_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z -- '*.sh' '*.bash'
  else
    find . -type f \( -name '*.sh' -o -name '*.bash' \) \
      -not -path './.git/*' -print0
  fi
}

_lint_docker_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z -- 'Dockerfile*' '*.dockerfile'
  else
    find . -type f \( -name 'Dockerfile*' -o -name '*.dockerfile' \) \
      -not -path './.git/*' -print0
  fi
}

_lint_cpp_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files -z -- '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.hh' '*.hxx'
  else
    find . -type f \( -name '*.c' -o -name '*.h' -o -name '*.cc' \
      -o -name '*.cpp' -o -name '*.cxx' -o -name '*.hpp' -o -name '*.hh' \
      -o -name '*.hxx' \) -not -path './.git/*' -not -path './build/*' \
      -not -path './install/*' -print0
  fi
}

# ---------- Python ----------
lint-py() {
  _lint_need ruff "python3 -m pip install --user ruff" || return
  ruff check "${@:-.}"
}

fmt-py() {
  _lint_need ruff "python3 -m pip install --user ruff" || return
  ruff format "${@:-.}"
}

fix-py() {
  _lint_need ruff "python3 -m pip install --user ruff" || return
  ruff check --fix "${@:-.}" && ruff format "${@:-.}"
}

type-py() {
  _lint_need pyright "npm i -D pyright 或 npm i -g pyright" || return
  pyright "$@"
}

# ---------- Shell ----------
lint-sh() {
  _lint_need shellcheck "见 ~/.config/dev-toolbox/README.md" || return
  if (( $# )); then
    shellcheck --external-sources "$@"
  else
    _lint_sh_files | xargs -0 -r shellcheck --external-sources
  fi
}

fmt-sh() {
  _lint_need shfmt "见 ~/.config/dev-toolbox/README.md" || return
  if (( $# )); then
    shfmt -w -i 2 -ci -sr "$@"
  else
    _lint_sh_files | xargs -0 -r shfmt -w -i 2 -ci -sr
  fi
}

# ---------- JS / TS / CSS / Markdown ----------
lint-js() {
  _lint_js_bin eslint --fix "${@:-.}"
}

fmt-js() {
  _lint_js_bin prettier --write "${@:-.}"
}

type-js() {
  _lint_js_bin tsc --noEmit
}

lint-css() {
  if (( $# )); then
    _lint_js_bin stylelint --fix "$@"
  else
    _lint_js_bin stylelint --fix "**/*.{css,scss,sass}"
  fi
}

lint-md() {
  if (( $# )); then
    _lint_js_bin markdownlint-cli2 "$@"
  else
    _lint_js_bin markdownlint-cli2 "**/*.md" "#node_modules" "#build"
  fi
}

# ---------- 配置 / 容器 ----------
lint-yaml() {
  _lint_need yamllint "python3 -m pip install --user yamllint" || return
  yamllint --strict "${@:-.}"
}

lint-docker() {
  _lint_need hadolint "见 ~/.config/dev-toolbox/README.md" || return
  if (( $# )); then
    hadolint "$@"
  else
    _lint_docker_files | xargs -0 -r hadolint
  fi
}

# ---------- C / C++ ----------
lint-cpp() {
  _lint_need cppcheck "sudo apt install cppcheck" || return
  cppcheck --enable=warning,performance,portability \
    --inline-suppr --error-exitcode=1 --quiet \
    -i build -i install "${@:-.}"
}

fmt-cpp() {
  _lint_need clang-format "见 ~/.config/dev-toolbox/README.md" || return
  if (( $# )); then
    clang-format -i "$@"
  else
    _lint_cpp_files | xargs -0 -r clang-format -i
  fi
}

lint-tidy() {
  _lint_need clang-tidy "见 ~/.config/dev-toolbox/README.md" || return
  clang-tidy -p build "$@"
}

# ---------- Go / Rust ----------
lint-go() {
  _lint_need golangci-lint "见 ~/.config/dev-toolbox/README.md" || return
  golangci-lint run ./...
}

fmt-go() {
  _lint_need go "见 ~/.config/dev-toolbox/README.md" || return
  go fmt ./...
}

lint-rs() {
  _lint_need cargo "见 ~/.config/dev-toolbox/README.md" || return
  cargo clippy --all-targets -- -D warnings
}

fmt-rs() {
  _lint_need cargo "见 ~/.config/dev-toolbox/README.md" || return
  cargo fmt
}

# ---------- 聚合入口 ----------
lint-stage() {
  _lint_need pre-commit "python3 -m pip install --user pre-commit" || return
  pre-commit run
}

lint-all() {
  _lint_need pre-commit "python3 -m pip install --user pre-commit" || return
  pre-commit run --all-files
}

lint-push() {
  _lint_need pre-commit "python3 -m pip install --user pre-commit" || return
  pre-commit run --all-files --hook-stage pre-push
}

lint() {
  case "$1" in
    py) shift; lint-py "$@" ;;
    sh) shift; lint-sh "$@" ;;
    js) shift; lint-js "$@" ;;
    css) shift; lint-css "$@" ;;
    md) shift; lint-md "$@" ;;
    yaml) shift; lint-yaml "$@" ;;
    docker) shift; lint-docker "$@" ;;
    cpp) shift; lint-cpp "$@" ;;
    go) shift; lint-go "$@" ;;
    rs) shift; lint-rs "$@" ;;
    all) shift; lint-all ;;
    stage) shift; lint-stage ;;
    push) shift; lint-push ;;
    *)
      print -u2 "用法: lint {py|sh|js|css|md|yaml|docker|cpp|go|rs|all|stage|push}"
      return 2
      ;;
  esac
}
