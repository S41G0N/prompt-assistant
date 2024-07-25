local prompt_assistant = require('prompt-assistant')

-- System prompts
local system_prompt = 'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks'
local helpful_prompt = 'You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.'

local function anthropic_help()
  prompt_assistant.call_llm({
    url = 'https://api.anthropic.com/v1/messages',
    model = 'claude-3-5-sonnet-20240620',
    api_key_name = 'ANTHROPIC_API_KEY',
    system_prompt = helpful_prompt,
    replace = false,
  }, prompt_assistant.make_anthropic_spec_curl_args, prompt_assistant.handle_anthropic_spec_data)
end

local function anthropic_replace()
  prompt_assistant.call_llm({
    url = 'https://api.anthropic.com/v1/messages',
    model = 'claude-3-5-sonnet-20240620',
    api_key_name = 'ANTHROPIC_API_KEY',
    system_prompt = system_prompt,
    replace = true,
  }, prompt_assistant.make_anthropic_spec_curl_args, prompt_assistant.handle_anthropic_spec_data)
end

-- Set up keybindings
vim.keymap.set({ 'n', 'v' }, '<leader>F', anthropic_help, { desc = 'llm anthropic_help' })
vim.keymap.set({ 'n', 'v' }, '<leader>L', anthropic_replace, { desc = 'llm anthropic' })

