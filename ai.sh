#!/usr/bin/env bash

# Mode can be one of:
#   - user_entrypoint
#   - debug_prompt
#   - debug_completions
#   - selector_preview
mode="user_entrypoint"
user_input=""

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
  if [[ "$1" == "__preview_selection__" ]]; then
    shift 1
    parse_cli_preview_selection "$@"
    return
  fi

  if [[ "$1" == "__debug_prompt__" ]]; then
    shift 1
    mode="debug_prompt"
    user_input="$1"
    return
  fi

  if [[ "$1" == "__debug_completions__" ]]; then
    shift 1
    mode="debug_completions"
    user_input="$1"
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

openai_prompt_template=$(cat <<'EOF'
# zsh
#
# All code that deletes, kills, or does an unrevertable update should be
# prefixed with a comment saying "# destructive"

# DESCRIPTION: compile a C program named "program.c" and save the output to "myprog"
# CODE:
gcc -o myprog program.c<STOP>

# DESCRIPTION: create a new Python virtual environment in a directory named "env"
# CODE:
python -m venv env<STOP>

# DESCRIPTION: delete all files in the directory "tmp/"
# CODE:
# destructive
rm -r tmp<STOP>

# DESCRIPTION: print a period every second for 30 seconds
# CODE:
for i in {1..30}; do
  echo "."
  sleep 1
done<STOP>

# DESCRIPTION: %DESCRIPTION%
# CODE:
.
EOF
)

sample_output=$(cat <<'EOF'
# zsh
#
# All code that deletes, kills, or does an unrevertable update should be
# prefixed with a comment saying "# destructive"

# DESCRIPTION: compile a C program named "program.c" and save the output to "myprog"
# CODE:
gcc -o myprog program.c<STOP>

# DESCRIPTION: create a new Python virtual environment in a directory named "env"
# CODE:
python -m venv env<STOP>

# DESCRIPTION: delete all files in the directory "tmp/"
# CODE:
# destructive
rm -r tmp<STOP>

# DESCRIPTION: print a period every second for 30 seconds
# CODE:
for i in {1..30}; do
  echo "."
  sleep 1
done<STOP>

# DESCRIPTION: %DESCRIPTION%
# CODE:
echo "hello world"
EOF
)

user_prompt() {
  echo "$openai_prompt_template" | sd '%DESCRIPTION%' "$user_input"
}

debug_prompt() {
  prompt="$(user_prompt)"
  prompt=${prompt%.}
  echo
  echo 'Template:'
  echo "$openai_prompt_template"
  echo
  echo "----"
  echo
  echo "Prompt:"
  echo "$prompt"
  echo "----"
  echo
  echo "This is what the prompt looks like when I immediately append some text:"
  echo
  echo "$prompt"'hello world'
  echo
}

get_completions() {
  prompt="$(user_prompt)"
  prompt=${prompt%.}

  completion="$(
    dotenv openai api completions.create \
      --engine 'code-davinci-002'        \
      --prompt "$prompt"                 \
      --temperature 0                    \
      --stop '<STOP>'                    \
      --max-tokens 50
  )"

  # OpenAI returns the prompt + the completion. Strip that out
  echo "$completion" | sd --string-mode "$prompt" '' | sd "\n$" ''
}

select_completion() {
  sk --read0 --ansi -i --preview "$0 __preview_selection__ {}"
}

pick_selection() {
  local completion_file
  completion_file="$1"

  preview_command="bat --language bash --color=always --style=numbers $completion_file"

  n_lines="$(wc -l < "$completion_temp_file" | sd "\s+" '')"

  sk --ansi                       \
    -i                            \
    --preview  "$preview_command" \
    --height "$n_lines"           \
    --preview-window right:60%    \
    --no-clear
}

choose_action() {
  local completion_temp_file
  completion_temp_file="$1"
  printf "Discard\nCopy to Clipboard\nRun Code" | pick_selection "$completion_temp_file"
}

run_user_entrypoint() {
  completion_temp_file="$(mktemp)"
  get_completions > "$completion_temp_file"
  user_action="$(choose_action "$completion_temp_file")"

  case "$user_action" in
    Run\ Code)
      echo "Running completion"
      eval "$(cat "$completion_temp_file")"
      ;;
    Copy\ to\ Clipboard)
      echo "Copying completion to clipboard"
      pbcopy < "$completion_temp_file"
      ;;
    Discard|"")
      echo "Completion discarded"
      ;;
    *)
      echo "Error: unknown action '$user_action'"
      exit 1
      ;;
  esac
}

run_preview_selection() {
  bat --language bash --color=always --style=numbers <(echo "$user_input")
}

parse_cli "$@"

case "$mode" in
  user_entrypoint)
    run_user_entrypoint
    exit 0
    ;;
  debug_prompt)
    debug_prompt
    exit 0
    ;;
  debug_completions)
    get_completions
    exit 0
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
