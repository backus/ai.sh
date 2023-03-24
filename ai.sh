#!/usr/bin/env bash

progname="$(basename "$0")"
user_input=""
config_file="$HOME/.config/ai.sh/config"

is_installed() {
  which -s "$1" > /dev/null
}

ensure_dependency() {
  if ! is_installed "$1"; then
    echo "Error: this program depends on '$1'"
    echo "Install it with: $2"
    exit 1
  fi
}

ensure_dependencies_installed() {
  ensure_dependency bat "brew install bat"
  ensure_dependency openai "pip install openai"
  ensure_dependency sk "brew install sk"
  ensure_dependency sd "brew install sd"
}

load_api_key() {
  if [[ ! -f "$config_file" ]]; then
    echo "Error: config file does not exist: $config_file"
    echo
    echo "Create it with:"
    echo "  mkdir -p $(dirname "$config_file")"
    echo "  touch $config_file"
    echo
    echo "Then add your OpenAI API key to it:"
    echo "  echo 'OPENAI_API_KEY=your-key-here' > $config_file"
    exit 1
  fi

  api_key="$(sd '^OPENAI_API_KEY=' '' < "$config_file")"
  export OPENAI_API_KEY="$api_key"
}

print_usage() {
  echo "Usage: $progname 'natural language description of command you want "
}

parse_cli() {
  if [[ $# -ne 1 ]]; then
    print_usage
    exit 1
  fi

  user_input="$1"
}

# We include OSTYPE so that the model knows to recommend commands that work for that environment.
# @see https://github.com/backus/ai.sh/pull/4
openai_prompt_template=$(cat <<EOF
# zsh
#
# OSTYPE=$OSTYPE
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

# Inject into the zsh history so that it feels like we ran the command without the AI wrapper
inject_into_zsh_history() {
  local command
  command="$1"

  # make a prefix like : 1678919131:0;
  prefix=": $(date +%s):0;"
  # escape each newline with a backslash
  command="$(echo "$command" | sd "\n" '\\\n')"
  # delete the final backslash
  command="${command%?}"

  echo "$prefix$command" >> "$HISTFILE"
}

user_prompt() {
  echo "$openai_prompt_template" | sd '%DESCRIPTION%' "$user_input"
}

get_completions() {
  prompt="$(user_prompt)"
  prompt=${prompt%.}

  completion="$(
    openai api chat_completions.create \
      --model 'gpt-3.5-turbo'         \
      --message user "$prompt"        \
      --temperature 0                 \
      --stop '<STOP>'                 \
      --max-tokens 50
  )"

  # OpenAI returns the prompt + the completion. Strip that out
  echo "$completion" | sd --string-mode "$prompt" '' | sd "\n$" ''
}

pick_selection() {
  local completion_file
  completion_file="$1"

  # Preview the code using bat for nice syntax highlighting
  preview_command="bat --language bash --color=always --style=numbers $completion_file"

  # Only take up as much space as we need to show the code sample
  n_lines="$(wc -l < "$completion_temp_file" | sd "\s+" '')"

  # Render an interactive picker to select what action to take.
  # The preview window is on the right and takes up 80% of the screen
  sk --ansi                       \
    -i                            \
    --preview  "$preview_command" \
    --height "$n_lines"           \
    --preview-window right:80%    \
    --no-clear
}

choose_action() {
  local completion_temp_file
  completion_temp_file="$1"

  printf "Discard\nCopy to Clipboard\nRun Code" | pick_selection "$completion_temp_file"
}

run() {
  completion_temp_file="$(mktemp)"
  get_completions > "$completion_temp_file"
  user_action="$(choose_action "$completion_temp_file")"

  case "$user_action" in
    Run\ Code)
      # Print the code so the user knows what ran
      cat "$completion_temp_file"
      inject_into_zsh_history "$(cat "$completion_temp_file")"
      printf "\n\n"
      zsh "$completion_temp_file"
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

ensure_dependencies_installed
load_api_key
parse_cli "$@"
run
