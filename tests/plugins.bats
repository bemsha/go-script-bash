#! /usr/bin/env bats

load environment

setup() {
  @go.create_test_go_script '@go "$@"'
  mkdir "$TEST_GO_PLUGINS_DIR"
}

teardown() {
  @go.remove_test_go_rootdir
}

@test "$SUITE: tab completion returns error if no plugins dir" {
  rmdir "$TEST_GO_PLUGINS_DIR"
  run "$TEST_GO_SCRIPT" complete 1 plugins ''
  assert_failure ''
}

@test "$SUITE: tab completion returns flags if plugins dir present" {
  run "$TEST_GO_SCRIPT" complete 1 plugins ''
  local expected=('--paths' '--summaries')
  local IFS=$'\n'
  assert_success "${expected[*]}"

  run "$TEST_GO_SCRIPT" complete 1 plugins '--paths'
  assert_success '--paths'
}

@test "$SUITE: error if no scripts/plugin directory" {
  run "$TEST_GO_SCRIPT" plugins
  assert_failure ''
}

@test "$SUITE: error if no plugins present" {
  run "$TEST_GO_SCRIPT" plugins
  assert_failure ''
}

@test "$SUITE: show plugin info" {
  mkdir -p "$TEST_GO_PLUGINS_DIR/bar/bin" "$TEST_GO_PLUGINS_DIR/plugh/bin"

  local plugins=(
    'bar/bin/bar'
    'bar/bin/baz'
    'foo'
    'plugh/bin/plugh'
    'xyzzy')
  local plugin
  local longest_plugin_len=0
  local plugin_path
  local summary
  local IFS=$'\n'

  for plugin in "${plugins[@]}"; do
    @go.create_test_command_script "plugins/$plugin" \
      "# Does ${plugin##*/} stuff"

    plugin="${plugin##*/}"
    if [[ "$longest_plugin_len" -lt "${#plugin}" ]]; then
      longest_plugin_len="${#plugin}"
    fi
  done

  run "$TEST_GO_SCRIPT" plugins
  assert_success "${plugins[*]##*/}"

  local paths=(
    'bar    scripts/plugins/bar/bin/bar'
    'baz    scripts/plugins/bar/bin/baz'
    'foo    scripts/plugins/foo'
    'plugh  scripts/plugins/plugh/bin/plugh'
    'xyzzy  scripts/plugins/xyzzy')

  run "$TEST_GO_SCRIPT" plugins --paths
  assert_success "${paths[*]}"

  local summaries=(
    '  bar    Does bar stuff'
    '  baz    Does baz stuff'
    '  foo    Does foo stuff'
    '  plugh  Does plugh stuff'
    '  xyzzy  Does xyzzy stuff')

  run "$TEST_GO_SCRIPT" plugins --summaries
  assert_success "${summaries[*]}"
}
