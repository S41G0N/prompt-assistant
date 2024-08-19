# prompt-assistant

A Neovim plugin for interacting with the Anthropic API within the existing buffer.

![Demo](img/demo.gif)


## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'S41G0N/prompt-assistant',
  requires = {'nvim-lua/plenary.nvim'},
  config = function()
    require('prompt-assistant')
  end
}
```

## Acknowledgment

This plugin was forked from [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim) project made by yacineMTB.
Modifications were made, the ability to display the result on a split window was added, cursor behavior was improved so I doesn't override existing text. Ollama support was added.

## Features

- Stream AI responses directly into your Neovim buffer
- Support for both Anthropic (Claude), other LLMs will be added later
- Easy to use commands and optional key mappings
- Display the result on a split screen to not meddle with your current buffer

## Requirements

- Neovim >= 0.7.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- curl
- Valid API keys for Anthropic


## Configuration

Set your API keys as and Ollama API url (e.g. http://localhost:11434/api/generate) as environment variables:

```sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export OLLAMA_URL_LINK="your_ollama_api_link"
```

## Usage

### Default Key Mappings
- Mappings work in both Visual & Normal mode:
  - `<leader>C`: Ask Anthropic to write code (replaces selection)
  - `<leader>c`: Ask Anthropic to write code (no replace)
  - `<leader>H`: Ask Anthropic for help (replaces selection)
  - `<leader>h`: Ask Anthropic for help (no replace)
  - `<leader>l`: Ask Anthropic for help (displays the output on the new window)

  - `<leader>d`: Ask Ollama for help (displays the output on the new window)

## License

Apache License 2.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
