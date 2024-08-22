# prompt-assistant

![Demo](img/demo.gif)

A Neovim plugin for interacting with the Anthropic and Ollama API within the existing buffer. Code faster than ever before without ever leaving your neovim editor.

## Acknowledgment

This plugin was forked from [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim) project made by yacineMTB.
Modifications were made, the ability to display the result on a split buffer was added, cursor behavior was improved so I doesn't override existing text, users can now replace the currently selected text with the LLM response. Ollama support was added. Gloobal configuration available.

## Features
- Support for both Anthropic API and Ollama API, Grok and OpenAI will be added later
- Stream AI responses directly into your Neovim buffer
- Display the result on a split screen to not meddle with your current buffer
- Replace current selection with LLM generated code or text
- Select the models of your choice
- Define your custom LLM model behavior
- Global config files for quick start, extensive config options for those who want to customize
- No default mappings which would meddle with your existing keybinds, create your OWN mappings easily
- Customize LLM model, behavior, text replacement per each mapping

## Requirements

- Neovim >= 0.7.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- curl
- Valid API keys for Anthropic (optional if Anthropic API will be used)
- API link of a running Ollama instance (optional if Ollama will be used)

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use { 'S41G0N/prompt-assistant', requires = {'nvim-lua/plenary.nvim'} }
```

## Quick Start
Setup environment variables:
```sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export OLLAMA_URL_LINK="your_ollama_api_link" #default is http://localhost:11434/api/generate
```
Place this into your neovim config:
```lua
-- LOAD THE PLUGIN
local prompt_assistant = require("prompt-assistant")

-- MAP KEYBINDS TO ONE OF THE 2 AVAILABLE FUNCTIONS (call_anthropic, call_ollama)
vim.keymap.set({ "n", "v" }, "<leader>h", function() prompt_assistant.call_anthropic() end, { desc = "Call Anthropic LLM with default options" })
vim.keymap.set({ "n", "v" }, "<leader>l", function() prompt_assistant.call_ollama() end, { desc = "Call Ollama LLM with default options" })

-- MAP SPECIAL FUNCTION TO LIST ALL AVAILABLE OLLAMA MODELS (SELECT BY j/k or Arrow Keys and press ENTER or 'q' to quit)
vim.keymap.set({ "n", "v" }, "<leader>t", function() prompt_assistant.create_option_screen() end, { desc = "List Available LLMs" })

```

## Usage, Keymaps & Extensive Configuration
For extensive configuration, the following can be added into your neovim config file. Load "prompt-assistant" and map the necessary functions (overriding globals and setting up custom behaviors are completely optional):

```lua
local prompt_assistant = require("prompt-assistant")

-- OPTIONAL GLOBAL CONFIG OVERRIDE (globally set options will always be lower priority than options set per keymap)
prompt_assistant.setup({
    anthropic = {
        model = "claude-3-5-sonnet-20240620", -- Set your preferred default model
        url = "https://api.anthropic.com/v1/messages", -- You can change this if needed
        api_key_name = "ANTHROPIC_API_KEY", -- ENV Variable name of your Anthropic API Key

    },

    ollama = {
        model = "llama3.1", -- Set your preferred default Ollama model
        url = "http://localhost:11434", -- Change if you're using a different URL (setting OLLAMA_URL_LINK env variable is also possible)

    },

    default_behavior = "You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.",
    display_on_new_window = false, -- default false
    replace = false, --default false
})

-- CUSTOM BEHAVIORS (Define your custom behaviors of your LLM)
local custom_behavior = "You are a debugging assistant, you should only output parts of code that you would replace or improve and comment on why. Talk in a short and concise manner. Do not provide backticks that surround the code. Comments should remain."
local output_code = "You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is calling you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks"


-- KEYBINDINGS (Set up keybindings to call specific API's with default or custom settings)
-- available commands (call_anthropic(), call_llama())
local map = vim.keymap.set
map({ "n", "v" }, "<leader>h", function() prompt_assistant.call_anthropic() end, { desc = "Call Anthropic LLM with default options" })
map({ "n", "v" }, "<leader>H", function() prompt_assistant.call_anthropic({ replace = true }) end, { desc = "Call Anthropic LLM and replace the current selection" })
map({ "n", "v" }, "<leader>l", function() prompt_assistant.call_anthropic({ display_on_new_window = true }) end, { desc = "Call Anthropic LLM and display answer on a new window" })
map({ "n", "v" }, "<leader>c", function() prompt_assistant.call_anthropic({ behavior = output_code }) end, { desc = "Call Anthropic LLM and output code" })
map({ "n", "v" }, "<leader>C", function() prompt_assistant.call_anthropic({ behavior = output_code, replace = true }) end, { desc = "Call Anthropic LLM and replace the current selection with code" })
map({ "n", "v" }, "<leader>L", function() prompt_assistant.call_anthropic({ behavior = custom_behavior, display_on_new_window = true }) end, { desc = "Call Anthropic LLM to debug code on the new window" })
map({ "n", "v" }, "<leader>d", function() prompt_assistant.call_ollama({ display_on_new_window = true }) end, { desc = "Call Ollama model to debug code on the new window" })
map({ "n", "v" }, "<leader>T", function() prompt_assistant.call_ollama({ollama = { model = "codegemma:latest" },behavior = "You're a helpful AI",display_on_new_window = true})
map({ "n", "v" }, "<leader>t", function() prompt_assistant.create_option_screen() end, { desc = "Options screen" })


-- configurable parameters
--	ollama/anthropic = {url = <string>} (non-standard url for the API without '/' at the end -> useful when running ollama on a custom port with a custom domain),
--	ollama/anthropic = {model = <string>} (model name -> e.g. "llama3.1" or "claude-3-5-sonnet-20240620"),
--	behavior = <string> (Defines LLM behavior -> e.g. "You're a strict assistant"),
--	replace = <boolean> (replaces currently selected text with the LLM response),
--	display_on_new_window = <boolean> (displays LLM response on a new window),
```

### The config file above will result in the following mappings:
- Mappings work in both Visual & Normal mode:
  - `<leader>C`: Ask Anthropic to write code (replaces selection)
  - `<leader>c`: Ask Anthropic to write code (no replace)
  - `<leader>H`: Ask Anthropic for help (replaces selection)
  - `<leader>h`: Ask Anthropic for help (no replace)
  - `<leader>l`: Ask Anthropic for help (displays the output on the new window)

  - `<leader>d`: Ask Ollama for help (displays the output on the new window)
  - `<leader>T`: Ask Ollama for help with custom model (codegemma) and custom behavior on split buffer
  - `<leader>t`: Choose between all available Ollama models by in the option window (is j/k or arrow keys to navigate, 'q' to quit and ENTER to select the model)

## Additional Configuration (Optional)

Set your API keys as and Ollama API url (e.g. http://localhost:11434/api/generate) as environment variables:

```sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export OLLAMA_URL_LINK="your_ollama_api_link"
```

This method prevents you from having to type the API keys or ollama links directly into your config file (in case you wanna keep this info private and you have public dotfiles)

## License

Apache License 2.0

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
