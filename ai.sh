#!/usr/bin/env bash

# Mode can be one of:
#   - user_entrypoint
#   - get_completions
#   - selector_preview
mode="user_entrypoint"
user_input=""

parse_cli_get_completions() {
  echo "Not implemented!"
  exit 1
}

print_usage() {
  echo "Not implemented!"
  exit 1
}

parse_cli_preview_selection() {
  if [[ $# -ne 1 ]]; then
    echo "Error: expected 1 arg for __preview_selection__, got $#"
    exit 1
  fi

  mode="selector_preview"
  user_input="$1"
}

parse_cli() {
  if [[ "$1" == "__get_completions__" ]]; then
    shift 1
    parse_cli_get_completions "$@"
    return
  fi

  if [[ "$1" == "__preview_selection__" ]]; then
    shift 1
    parse_cli_preview_selection "$@"
    return
  fi

  # If we get here, we're in user_entrypoint mode which requires 1 or more args
  if [[ $# -eq 0 ]]; then
    echo "Error: no user input provided"
    print_usage
    exit 1
  fi

  mode="user_entrypoint"
  # User might do something like
  #   $ ai.sh I want to list all the files in the directory
  # this should be equivalent to
  #   $ ai.sh 'I want to list all the files in the directory'
  user_input="$*"
}

get_completions_stub() {
  cat stub_completions.txt
}

select_completion() {
  sk --read0 --ansi -i --preview "$0 __preview_selection__ {}"
}

run_user_entrypoint() {
  get_completions_stub | select_completion
}

run_preview_selection() {
  bat --language bash --color=always <(echo "$user_input")
}

parse_cli "$@"

# switch on mode
case "$mode" in
  user_entrypoint)
    run_user_entrypoint
    exit 0
    ;;
  get_completions)
    echo "Not implemented!"
    exit 1
    ;;
  selector_preview)
    run_preview_selection
    exit 0
    ;;
  *)
    echo "Error: unknown mode '$mode'"
    exit 1
    ;;
esac
