local prompt_assistant = require("prompt-assistant")

-- System prompts
local output_code = "You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks"
local be_helpful = "You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful."

local function anthropic_call(opts)
	opts = opts or {}
	prompt_assistant.call_llm({
		url = "https://api.anthropic.com/v1/messages",
		model = opts.model or "claude-3-5-sonnet-20240620",
		api_key_name = "ANTHROPIC_API_KEY",
		llm_behavior = opts.behavior or be_helpful,
		replace = opts.replace or false,
		display_on_new_window = opts.display_on_new_window or false,
	}, prompt_assistant.make_anthropic_spec_curl_args, prompt_assistant.handle_anthropic_spec_data)
end

-- Usage:
local function anthropic_code_replace()
	anthropic_call({ behavior = output_code, replace = true })
end

local function anthropic_code_noreplace()
	anthropic_call({ behavior = output_code, replace = false })
end

local function anthropic_help_noreplace()
	anthropic_call({ behavior = be_helpful, replace = false })
end

local function anthropic_help_replace()
	anthropic_call({ behavior = be_helpful, replace = true })
end

local function anthropic_help_new_window()
	anthropic_call({ behavior = be_helpful, replace = false, display_on_new_window = true })
end

-- Set up keybindings
local map = vim.keymap.set

map({ "n", "v" }, "<leader>H", anthropic_help_replace, { desc = "llm anthropic_help" })
map({ "n", "v" }, "<leader>h", anthropic_help_noreplace, { desc = "llm anthropic_help" })
map({ "n", "v" }, "<leader>l", anthropic_help_new_window, { desc = "llm anthropic" })

map({ "n", "v" }, "<leader>C", anthropic_code_replace, { desc = "llm anthropic" })
map({ "n", "v" }, "<leader>c", anthropic_code_noreplace, { desc = "llm anthropic" })
