local M = {}
local Job = require("plenary.job")

M.is_initialized = false

local default_opts = {
	url = "https://api.anthropic.com/v1/messages",
	api_key_name = "ANTHROPIC_API_KEY",
	model = "claude-3-opus-20240229",
	system_prompt = "You are a helpful programming assistant. Provide clear and concise explanations.",
	setup_keymaps = true,
}

local function setup_keymaps()
	local map = vim.api.nvim_set_keymap
	local opts = { noremap = true, silent = true }
	map("v", "<Leader>F", ":AskAnthropic<CR>", opts)
	map("n", "<Leader>F", ":AskAnthropic<CR>", opts)
end

function M.init(opts)
	opts = vim.tbl_extend("force", default_opts, opts or {})
	M.opts = opts
	M.is_initialized = true

	if opts.setup_keymaps then
		setup_keymaps()
	end
end

local function make_curl_args(opts, prompt, system_prompt)
	local api_key = opts.api_key_name and os.getenv(opts.api_key_name)
	local data = {
		system = system_prompt,
		messages = { { role = "user", content = prompt } },
		model = opts.model,
		stream = true,
		max_tokens = 4096,
	}
	local args = {
		"-N",
		"-X",
		"POST",
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(data),
		"-H",
		"x-api-key: " .. (api_key or ""),
		"-H",
		"anthropic-version: 2023-06-01",
		opts.url,
	}
	return args
end

local function insert_text(text)
	vim.schedule(function()
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local lines = vim.split(text, "\n", true)
		vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
		local new_row = row + #lines - 1
		local new_col = col
		if #lines > 1 then
			new_col = #lines[#lines]
		else
			new_col = col + #lines[1]
		end
		vim.api.nvim_win_set_cursor(0, { new_row, new_col })
	end)
end

local text_buffer = ""

local function handle_data(data_stream)
    local json = vim.json.decode(data_stream)
    if json.delta and json.delta.text then
        insert_text(json.delta.text)
    end
end

local function get_selected_text()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)

	-- Check if text is selected
	if start_pos[2] == end_pos[2] and start_pos[3] == end_pos[3] then
		-- No text selected, return all text in the buffer
		local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local all_text = table.concat(all_lines, "\n")

		-- Move cursor to the end of the buffer and add a new line
		local last_line = #all_lines
		vim.api.nvim_buf_set_lines(bufnr, last_line, last_line, false, { "" })
		vim.api.nvim_win_set_cursor(0, { last_line + 1, 0 })

		return all_text
	end

	if #lines == 0 then
		return ""
	end
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
	else
		lines[1] = string.sub(lines[1], start_pos[3])
		lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
	end

	-- Move cursor to the end of selection and add a new line if needed
	local last_line = vim.api.nvim_buf_line_count(bufnr)
	local new_cursor_line = end_pos[2]

	if new_cursor_line == last_line then
		vim.api.nvim_buf_set_lines(bufnr, last_line, last_line, false, { "" })
		new_cursor_line = last_line + 1
	else
		new_cursor_line = new_cursor_line + 1
	end

	vim.api.nvim_win_set_cursor(0, { new_cursor_line, 0 })
	return table.concat(lines, "\n")
end

local active_job

-- Copy these from the previous core.lua file

function M.call_llm()
	if not M.is_initialized then
		M.init(default_opts)
	end

	local prompt = get_selected_text()
	local args = make_curl_args(M.opts, prompt, M.opts.system_prompt)

	if active_job then
		active_job:shutdown()
	end

    active_job = Job:new({
        command = "curl",
        args = args,
        on_stdout = function(_, out)
            if out:match("^data: ") then
                handle_data(out:match("^data: (.+)$"))
            end
        end,
        on_exit = function() active_job = nil end,
    }):start()

	vim.api.nvim_create_autocmd("User", {
		pattern = "PROMPT_ASSISTANT_Escape",
		callback = function()
			if active_job then
				active_job:shutdown()
				print("LLM streaming cancelled")
				active_job = nil
			end
		end,
	})

	vim.api.nvim_set_keymap(
		"n",
		"<Esc>",
		":doautocmd User PROMPT_ASSISTANT_Escape<CR>",
		{ noremap = true, silent = true }
	)
end

return M
