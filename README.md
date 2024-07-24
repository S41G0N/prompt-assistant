# prompt-assistant

A Neovim plugin for interacting with the Anthropic API.

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'S41G0N/prompt-assistant',
  requires = {'nvim-lua/plenary.nvim'},
  config = function()
    require('prompt-assistant').init({
      -- Custom options here (optional)
    })
  end
}

## Acknowledgment

This plugin was inspired by Yacine Benaffane (yacineMTB) and his [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim) project. Although it contains less features, this plugin will gradually be improved and is primarily meant to be a personal learning project.

## Features

- Stream AI responses directly into your Neovim buffer
- Support for both Anthropic (Claude), other LLMs will be added later
- Easy to use commands and optional key mappings

## Requirements

- Neovim >= 0.7.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- curl
- Valid API keys for Anthropic


## Configuration

Set your API keys as environment variables:

```sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
```

## Usage

### Commands

- `:AskAnthropic`

### Default Key Mappings

- Visual & Normal mode:
  - `<leader>F`: Stream Anthropic response (replaces selection)

### Customize mappings
- To customize mappings, you can add the following commands in your Neovim configuration file as an example:
`vim.api.nvim_set_keymap('v', '<leader>d', ':AskAnthropic<CR>', { noremap = true, silent = true })`

## License

Apache License 2.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
