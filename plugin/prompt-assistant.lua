local prompt_assistant = require("prompt-assistant")

-- System prompts
local output_code =
	"You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is calling you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks"
local be_helpful = "You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful."
local debug_code =
	"You are a debugging assistant, you should only output parts of code that you would replace or improve and comment on why. Talk in a short and concise manner. Do not provide backticks that surround the code. Comments should remain."

local function call_anthropic(options)
	options = options or {}
	prompt_assistant.call_llm({
		url = "https://api.anthropic.com/v1/messages",
		model = options.model or "claude-3-5-sonnet-20240620",
		api_key_name = "ANTHROPIC_API_KEY",
		llm_behavior = options.behavior or be_helpful,
		replace = options.replace or false,
		display_on_new_window = options.display_on_new_window or false,
        llm_api_provider = "anthropic"
	})
end

local function call_ollama(options)
	options = options or {}
	prompt_assistant.call_llm({
		url = "http://localhost:11434/api/generate",
		model = options.model or "llama3.1",
		llm_behavior = options.behavior or be_helpful,
		replace = options.replace or false,
		display_on_new_window = options.display_on_new_window or false,
        llm_api_provider = "ollama"
	})
end

-- Set up keybindings
local map = vim.keymap.set
map({ "n", "v" }, "<leader>h", function() call_anthropic() end, { desc = "Call Anthropic LLM with default options" })
map({ "n", "v" }, "<leader>H", function() call_anthropic({ replace = true }) end, { desc = "Call Anthropic LLM and replace the current selection" })
map({ "n", "v" }, "<leader>l", function() call_anthropic({ display_on_new_window = true }) end, { desc = "Call Anthropic LLM and display answer on a new window" })
map({ "n", "v" }, "<leader>c", function() call_anthropic({ behavior = output_code }) end, { desc = "Call Anthropic LLM and output code" })
map({ "n", "v" }, "<leader>C", function() call_anthropic({ behavior = output_code, replace = true }) end, { desc = "Call Anthropic LLM and replace the current selection with code" })
map({ "n", "v" }, "<leader>L", function() call_anthropic({ behavior = debug_code, display_on_new_window = true }) end, { desc = "Call Anthropic LLM to debug code on the new window" })
map({ "n", "v" }, "<leader>d", function() call_ollama({display_on_new_window = true }) end, { desc = "Call Ollama model to debug code on the new window" })
