if vim.g.loaded_prompt_assistant then
  return
end
vim.g.loaded_prompt_assistant = true

local prompt_assistant = require("prompt-assistant")

vim.api.nvim_create_user_command("AskAnthropic", function()
    prompt_assistant.call_llm()
end, { range = true })

-- Optional: Set up the plugin with default options
-- Remove this if you want users to always call setup manually
prompt_assistant.init()
