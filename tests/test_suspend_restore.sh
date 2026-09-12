#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
installer="$repo_root/Super_shift_S_release.sh"
unmask_command="systemctl unmask --runtime sleep.target suspend.target hibernate.target hybrid-sleep.target"

extract_heredoc() {
  local start_marker="$1"
  local end_marker="$2"
  sed -n "/<< '$start_marker'/,/^$end_marker$/p" "$installer"
}

assert_contains() {
  local description="$1"
  local content="$2"
  local expected="$3"
  if ! grep -Fq "$expected" <<<"$content"; then
    echo "FAIL: $description does not contain: $expected" >&2
    exit 1
  fi
}

assert_before() {
  local description="$1"
  local content="$2"
  local first="$3"
  local second="$4"
  local first_line second_line
  first_line=$(grep -Fn "$first" <<<"$content" | head -1 | cut -d: -f1)
  second_line=$(grep -Fn "$second" <<<"$content" | head -1 | cut -d: -f1)
  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    echo "FAIL: $description must place '$first' before '$second'" >&2
    exit 1
  fi
}

wrapper=$(extract_heredoc NM_WRAPPER NM_WRAPPER)
steam_exit=$(extract_heredoc OS_SESSION_SELECT OS_SESSION_SELECT)
desktop_switch=$(extract_heredoc SWITCH_DESKTOP SWITCH_DESKTOP)
sudoers=$(extract_heredoc SUDOERS_SWITCH SUDOERS_SWITCH)

wrapper_cleanup=$(sed -n '/^cleanup() {/,/^}/p' <<<"$wrapper")
wrapper_startup=$(sed -n '/^trap cleanup EXIT INT TERM$/,/^# Enable performance mode/p' <<<"$wrapper")

assert_contains "session startup" "$wrapper_startup" "$unmask_command"
assert_contains "session cleanup" "$wrapper_cleanup" "$unmask_command"
assert_contains "Steam exit handler" "$steam_exit" "$unmask_command"
assert_before "Steam exit handler" "$steam_exit" "$unmask_command" "rm -f /tmp/.gaming-session-active"
assert_contains "desktop switch" "$desktop_switch" "$unmask_command"
assert_before "desktop switch" "$desktop_switch" "$unmask_command" 'if [[ ! -f /tmp/.gaming-session-active ]]'
assert_contains "sudoers policy" "$sudoers" "/usr/bin/$unmask_command"

echo "PASS: every Gaming Mode exit path restores suspend targets"
