local M = {}
local Job = require("plenary.job")

local function get_api_key(name)
	return os.getenv(name)
end

function M.make_anthropic_spec_curl_args(opts, prompt, llm_behavior)
	local url = opts.url
	local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
	local data = {
		system = llm_behavior,
		messages = { { role = "user", content = prompt } },
		model = opts.model,
		stream = true,
		max_tokens = 4096,
	}
	local args = { "-N", "-X", "POST", "-H", "Content-Type: application/json", "-d", vim.json.encode(data) }
	if api_key then
		table.insert(args, "-H")
		table.insert(args, "x-api-key: " .. api_key)
		table.insert(args, "-H")
		table.insert(args, "anthropic-version: 2023-06-01")
	end
	table.insert(args, url)
	return args
end

local function write_string_at_cursor(str)
	vim.schedule(function()
		local current_window = vim.api.nvim_get_current_win()
		local cursor_position = vim.api.nvim_win_get_cursor(current_window)
		local row, col = cursor_position[1], cursor_position[2]

		local lines = vim.split(str, "\n")

		vim.cmd("undojoin")
		vim.api.nvim_put(lines, "c", true, true)

		local num_lines = #lines
		local last_line_length = #lines[num_lines]
		vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
	end)
end

local function get_prompt(opts)
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

	local selected_text = table.concat(lines, "\n")

	-- If opts.replace is true, delete the selected text
	if opts and opts.replace then
		vim.api.nvim_buf_set_text(bufnr, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3], {})
		-- Move cursor to the start of the deleted section
		vim.api.nvim_win_set_cursor(0, { start_pos[2], start_pos[3] - 1 })
	else
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
	end

	return selected_text
end

function M.handle_anthropic_spec_data(data_stream, event_state)
	if event_state == "content_block_delta" then
		local json = vim.json.decode(data_stream)
		if json.delta and json.delta.text then
			write_string_at_cursor(json.delta.text)
		end
	end
end

local group = vim.api.nvim_create_augroup("PROMPT_ASSISTANT_AutoGroup", { clear = true })
local active_job = nil

function M.call_llm(opts, make_curl_args_fn, handle_data_fn)
	vim.api.nvim_clear_autocmds({ group = group })
	local prompt = get_prompt(opts)
	local llm_behavior = opts.llm_behavior or "Tell me the plugin was set incorrectly"
	local args = make_curl_args_fn(opts, prompt, llm_behavior)
	local curr_event_state = nil

	local function parse_and_call(line)
		local event = line:match("^event: (.+)$")
		if event then
			curr_event_state = event
			return
		end
		local data_match = line:match("^data: (.+)$")
		if data_match then
			handle_data_fn(data_match, curr_event_state)
		end
	end

	if active_job then
		active_job:shutdown()
		active_job = nil
	end

	active_job = Job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, out)
			parse_and_call(out)
		end,
		on_stderr = function(_, _) end,
		on_exit = function()
			active_job = nil
		end,
	})

	active_job:start()

	vim.api.nvim_create_autocmd("User", {
		group = group,
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
	return active_job
end

return M
