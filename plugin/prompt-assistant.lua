if vim.fn.has("nvim-0.7.0") == 0 then
	vim.api.nvim_err_writeln("prompt-assistant requires at least nvim-0.7.0.")
	return
end

-- Prevent loading if already loaded
if vim.g.loaded_prompt_assistant == 1 then
	return
end
vim.g.loaded_prompt_assistant = 1

-- Import the main module
local prompt_assistant = require("prompt-assistant")

-- Define system prompts
local system_prompt =
	"You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks"
local helpful_prompt =
	"You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful."

-- Define user commands
vim.api.nvim_create_user_command("AskAnthropic", function(opts)
	prompt_assistant.invoke_llm_and_stream_into_editor({
		url = "https://api.anthropic.com/v1/messages",
		api_key_name = "ANTHROPIC_API_KEY",
		model = "claude-3-opus-20240229",
		replace = false,
		system_prompt = system_prompt,
	}, prompt_assistant.make_anthropic_spec_curl_args, prompt_assistant.handle_anthropic_spec_data)
end, { range = true })

vim.api.nvim_create_user_command("AskAnthropicReplace", function(opts)
	prompt_assistant.invoke_llm_and_stream_into_editor({
		url = "https://api.anthropic.com/v1/messages",
		api_key_name = "ANTHROPIC_API_KEY",
		model = "claude-3-opus-20240229",
		replace = true,
		system_prompt = system_prompt,
	}, prompt_assistant.make_anthropic_spec_curl_args, prompt_assistant.handle_anthropic_spec_data)
end, { range = true })

-- Set up key mappings (optional, adjust as needed)
vim.api.nvim_set_keymap("n", "<leader>f", ":AskAnthropic<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<leader>F", ":AskAnthropicReplace<CR>", { noremap = true, silent = true })
