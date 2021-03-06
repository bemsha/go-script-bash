#! /usr/bin/env bats

load environment

setup() {
  @go.create_test_go_script '@go "$@"'
  @go.create_test_command_script "test-command"
}

teardown() {
  @go.remove_test_go_rootdir
}

# Some versions of Bash single quote each array value, causing the assertion to
# fail. Yeah.
quotify_expected() {
  local test_array=()
  if [[ "$(declare -p test_array)" == "declare -a test_array='()'" ]]; then
    # Oh, and using a single quote directly causes an error. Yep.
    local quote="'"
    expected=("${expected[@]/=(/=${quote}(}")
    expected=("${expected[@]/%)/)${quote}}")
  fi
}

@test "$SUITE: _GO_* variables are set for Bash" {
  run "$TEST_GO_SCRIPT" vars
  assert_success

  local search_paths=("[0]=\"$_GO_CORE_DIR/libexec\""
    "[1]=\"$TEST_GO_SCRIPTS_DIR\"")

  local expected=("declare -rx _GO_CMD=\"$TEST_GO_SCRIPT\""
    'declare -ax _GO_CMD_ARGV=()'
    'declare -ax _GO_CMD_NAME=([0]="vars")'
    "declare -rx _GO_CORE_DIR=\"$_GO_CORE_DIR\""
    "declare -rx _GO_CORE_URL=\"$_GO_CORE_URL\""
    "declare -rx _GO_CORE_VERSION=\"$_GO_CORE_VERSION\""
    'declare -a _GO_IMPORTED_MODULES=()'
    'declare -- _GO_PLUGINS_DIR=""'
    'declare -a _GO_PLUGINS_PATHS=()'
    "declare -rx _GO_ROOTDIR=\"$TEST_GO_ROOTDIR\""
    "declare -rx _GO_SCRIPT=\"$TEST_GO_SCRIPT\""
    "declare -- _GO_SCRIPTS_DIR=\"$TEST_GO_SCRIPTS_DIR\""
    "declare -a _GO_SEARCH_PATHS=(${search_paths[*]})"
    "declare -rx _GO_USE_MODULES=\"$_GO_CORE_DIR/lib/internal/use\"")

  quotify_expected
  assert_lines_equal "${expected[@]}"
}

@test "$SUITE: all _GO_* variables for Bash subcommand contain values" {
  @go.create_test_command_script 'test-command.d/test-subcommand' \
    '. "$_GO_USE_MODULES" "complete" "format"' \
    '@go vars'

  mkdir "$TEST_GO_PLUGINS_DIR"
  mkdir "$TEST_GO_PLUGINS_DIR/plugin"{0,1,2}
  mkdir "$TEST_GO_PLUGINS_DIR/plugin"{0,1,2}"/bin"

  run "$TEST_GO_SCRIPT" test-command test-subcommand foo bar 'baz quux' xyzzy
  assert_success

  local cmd_argv=('[0]="foo"' '[1]="bar"' '[2]="baz quux"' '[3]="xyzzy"')
  local plugins_paths=("[0]=\"$TEST_GO_PLUGINS_DIR\""
    "[1]=\"$TEST_GO_PLUGINS_DIR/plugin0/bin\""
    "[2]=\"$TEST_GO_PLUGINS_DIR/plugin1/bin\""
    "[3]=\"$TEST_GO_PLUGINS_DIR/plugin2/bin\"")
  local search_paths=("[0]=\"$_GO_CORE_DIR/libexec\""
    "[1]=\"$TEST_GO_PLUGINS_DIR\""
    "[2]=\"$TEST_GO_PLUGINS_DIR/plugin0/bin\""
    "[3]=\"$TEST_GO_PLUGINS_DIR/plugin1/bin\""
    "[4]=\"$TEST_GO_PLUGINS_DIR/plugin2/bin\""
    "[5]=\"$TEST_GO_SCRIPTS_DIR\"")

  # Note that the `format` module imports `strings` and `validation`.
  local expected_modules=('[0]="complete"'
    '[1]="format"'
    '[2]="strings"'
    '[3]="validation"')
  local expected=("declare -rx _GO_CMD=\"$TEST_GO_SCRIPT\""
    "declare -ax _GO_CMD_ARGV=(${cmd_argv[*]})"
    'declare -ax _GO_CMD_NAME=([0]="test-command" [1]="test-subcommand")'
    "declare -rx _GO_CORE_DIR=\"$_GO_CORE_DIR\""
    "declare -rx _GO_CORE_URL=\"$_GO_CORE_URL\""
    "declare -rx _GO_CORE_VERSION=\"$_GO_CORE_VERSION\""
    "declare -a _GO_IMPORTED_MODULES=(${expected_modules[*]})"
    "declare -- _GO_PLUGINS_DIR=\"$TEST_GO_PLUGINS_DIR\""
    "declare -a _GO_PLUGINS_PATHS=(${plugins_paths[*]})"
    "declare -rx _GO_ROOTDIR=\"$TEST_GO_ROOTDIR\""
    "declare -rx _GO_SCRIPT=\"$TEST_GO_SCRIPT\""
    "declare -- _GO_SCRIPTS_DIR=\"$TEST_GO_SCRIPTS_DIR\""
    "declare -a _GO_SEARCH_PATHS=(${search_paths[*]})"
    "declare -rx _GO_USE_MODULES=\"$_GO_CORE_DIR/lib/internal/use\"")

  quotify_expected
  assert_lines_equal "${expected[@]}"
}

# Since Bash scripts are sourced, and have access to these variables regardless,
# we use Perl to ensure they are are exported to new processes that run command
# scripts in languages other than Bash.
@test "$SUITE: run perl script; _GO_* variables are exported" {
  if ! command -v perl >/dev/null; then
    skip 'perl not installed'
  fi

  @go.create_test_command_script 'test-command.d/test-subcommand' \
    '#!/bin/perl' \
    'foreach my $env_var (sort keys %ENV) {' \
    '  if ($env_var =~ /^_GO_/) {' \
    '    printf("%s: %s\n", $env_var, $ENV{$env_var});' \
    '  }' \
    '}'
  run "$TEST_GO_SCRIPT" test-command test-subcommand foo bar 'baz quux' xyzzy
  assert_success
  assert_lines_equal "_GO_CMD: $TEST_GO_SCRIPT" \
    $'_GO_CMD_ARGV: foo\x1fbar\x1fbaz quux\x1fxyzzy' \
    $'_GO_CMD_NAME: test-command\x1ftest-subcommand' \
    "_GO_CORE_DIR: $_GO_CORE_DIR" \
    "_GO_CORE_URL: $_GO_CORE_URL" \
    "_GO_CORE_VERSION: $_GO_CORE_VERSION" \
    "_GO_ROOTDIR: $TEST_GO_ROOTDIR" \
    "_GO_SCRIPT: $TEST_GO_SCRIPT" \
    "_GO_USE_MODULES: $_GO_USE_MODULES"
}
