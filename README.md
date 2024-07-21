# prompt-assistant
A Neovim plugin that allows you to stream responses from AI language models (Anthropic's Claude and OpenAI's GPT) directly into your editor.

## Acknowledgment

This plugin is based on the excellent work of Yacine Benaffane (yacineMTB) and their [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim) project.

## Features

- Stream AI responses directly into your Neovim buffer
- Support for both Anthropic (Claude) and OpenAI (GPT) models
- Replace selected text or append after cursor
- Easy to use commands and optional key mappings

## Requirements

- Neovim >= 0.7.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- curl
- Valid API keys for Anthropic and/or OpenAI

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'S41G0N/prompt-assistant',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function()
    -- Optional configuration
  end
}
```

## Configuration

Set your API keys as environment variables:

```sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
```

## Usage

### Commands

- `:AskAnthropic`
- `:AskAnthropicReplace`

### Default Key Mappings

- Normal mode:
  - `<leader>f`: Stream Anthropic response
- Visual mode:
  - `<leader>F`: Stream Anthropic response (replaces selection)

### Customize mappings
- To customize mappings, you can add the following commands in your Neovim configuration file as an example:
`vim.api.nvim_set_keymap('v', '<leader>d', ':AskAnthropic<CR>', { noremap = true, silent = true })`

## Customization

You can customize the plugin by modifying the `plugin/prompt-assistant.lua` file. You can change:

- API endpoints
- Model names
- System prompts
- Key mappings

## License

Apache License 2.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
