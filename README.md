# ai.sh

Copilot for the terminal. Generate commands and preview them before running.

## Demo

![demo](demo.gif)

## What's inside

Just run `ai 'what you want to do'` and the script will use [code-davinci-002 (AKA "Codex")][codex] to convert the prompt into (hopefully) runnable bash / zsh.

Under the hood, the tool uses [skim][skim] to provide a preview of the generated command, allowing you to choose to either (1) Run, (2) Copy, or (3) Discard the generated code.

I tried to calibrate the prompt this tool uses to try to do a few things:

1. Generate the simplest command possible for the given prompt
2. Try to annotate destructive commands (deleting files, killing processes, etc) with a leading `# destructive` comment

[codex]: https://help.openai.com/en/articles/6195637-getting-started-with-codex
[skim]: https://github.com/lotabout/skim

## Dependencies and setup

This tool is written in pure bash, but it depends on a few programs being available:

* [bat](https://github.com/sharkdp/bat) for syntax highlighted code previews
* [skim](https://github.com/lotabout/skim) for the interactive UI for choosing if you want to run the code, copy it, or discard
* [openai-python](https://github.com/openai/openai-python) for the openai CLI

### Config

This tool uses the OpenAI CLI and therefore needs an active API key. It looks for a file in `~/.config/ai.sh/config` where the contents should just be `OPENAI_API_KEY=sk-1234...`

## Warranty

I hope it is obvious that you should exercise caution in running a bash script that uses AI to generate and run commands in your terminal. I've tried to make it sane, but use your best judgement and make sure you understand what you run.

### Credits

* Thanks to Jay Hack for the original inspiration with his [llm.sh](https://github.com/jayhack/llm.sh)
