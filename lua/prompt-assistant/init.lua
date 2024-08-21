local Job = require("plenary.job")

local function get_api_key(name)
	return os.getenv(name)
end

local function write_string_at_cursor(str)
	vim.schedule(function()
		-- ensure soft breaks to not make the text exceed the buffer
		vim.wo.wrap = true
		vim.wo.linebreak = true
		vim.wo.breakindent = true

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

local function get_prompt_for_llm_and_adjust_cursor(replace_text_boolean)
	-- Selects all text in the current buffer up until the current cursor and returns it as a long string
	local function get_lines_until_cursor()
		local current_buffer = vim.api.nvim_get_current_buf()
		local current_window = vim.api.nvim_get_current_win()
		local cursor_position = vim.api.nvim_win_get_cursor(current_window)
		local row = cursor_position[1]
		local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)
		return table.concat(lines, "\n")
	end
	-- Selects all text in the current buffer and returns it as a single long string
	local function get_entire_buffer()
		local current_buffer = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, -1, false)
		local buffer_content = table.concat(lines, "\n")
		return buffer_content
	end
	-- Selects text marked by Visual Mode in the current buffer and returns it as a single long string
	local function get_selected_text()
		local _, srow, scol = unpack(vim.fn.getpos("v"))
		local _, erow, ecol = unpack(vim.fn.getpos("."))

		if vim.fn.mode() == "V" then
			if srow > erow then
				return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
			else
				return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
			end
		end

		if vim.fn.mode() == "v" then
			if srow < erow or (srow == erow and scol <= ecol) then
				return vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
			else
				return vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {})
			end
		end

		if vim.fn.mode() == "\22" then
			local lines = {}
			if srow > erow then
				srow, erow = erow, srow
			end
			if scol > ecol then
				scol, ecol = ecol, scol
			end
			for i = srow, erow do
				table.insert(
					lines,
					vim.api.nvim_buf_get_text(0, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})[1]
				)
			end
			return lines
		end
	end

	-- ADJUST THE CURSOR
	local replace = replace_text_boolean
	local visual_lines = get_selected_text()
	local prompt = ""

	if visual_lines then
		-- condense the prompt into one line separated by '\n'
		prompt = table.concat(visual_lines, "\n")
		local bufnr = vim.api.nvim_get_current_buf()
		local _, srow, _ = unpack(vim.fn.getpos("v"))
		local _, erow, _ = unpack(vim.fn.getpos("."))

		-- Ensure erow is always the last row of the selection
		if srow > erow then
			srow, erow = erow, srow
		end

		if replace then
			-- Replace the selected lines with a single empty line
			vim.api.nvim_buf_set_lines(bufnr, srow - 1, erow, false, { "" })
			vim.api.nvim_win_set_cursor(0, { srow, 0 })
		else
			-- Add an empty line after the selection
			vim.api.nvim_buf_set_lines(bufnr, erow, erow, false, { "" })
			vim.api.nvim_win_set_cursor(0, { erow + 1, 0 })
		end

		-- Clear the visual selection
		vim.api.nvim_command("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
	else
		while true do
			local choice = vim.fn.input(
				"No selection, choose prompt method -> a/c/q (select all | select until cursor | quit process)"
			)
			if choice == "a" then
				local bufnr = vim.api.nvim_get_current_buf()
				local line_count = vim.api.nvim_buf_line_count(bufnr)
				-- Add a new line at the end of the buffer
				vim.api.nvim_buf_set_lines(bufnr, line_count, -1, false, { "" })
				-- Move cursor to the new line
				vim.api.nvim_win_set_cursor(0, { line_count + 1, 0 })
				return get_entire_buffer()
			elseif choice == "c" then
				local bufnr = vim.api.nvim_get_current_buf()
				local current_line = vim.api.nvim_win_get_cursor(0)[1]
				-- Insert a new empty line below the current line
				vim.api.nvim_buf_set_lines(bufnr, current_line, current_line, false, { "" })
				-- Move cursor to the new line
				vim.api.nvim_win_set_cursor(0, { current_line + 1, 0 })
				return get_lines_until_cursor()
			elseif choice == "q" then
				print("Operation cancelled, you can select your specific prompt using Visual Mode")
				return nil
			else
				print("Invalid choice. Please try again.")
			end
		end
	end

	return prompt
end

local function get_ascii_message(message_name)
	local ascii_file = os.getenv("HOME")
		.. "/.local/share/nvim/site/pack/packer/start/prompt-assistant"
		.. "/ascii_msg/"
		.. message_name

	local file = io.open(ascii_file, "r")
	if not file then
		return { "Error: Couldn't load ASCII message: " .. message_name, "" }
	end
	local content = file:read("*all")
	file:close()
	return vim.split(content, "\n")
end

-- Create a new buffer to the right and print "prompt assistant" in ASCII and move the cursor to the end
local function open_new_window_before_write(llm_api_provider)
	vim.cmd("vsplit | vertical resize 75%")
	vim.cmd("wincmd l")
	vim.cmd("enew")
	local ascii_msg = get_ascii_message("prompt-assistant.txt")
	if llm_api_provider then
		ascii_msg = get_ascii_message(llm_api_provider .. ".txt")
	end
	vim.api.nvim_buf_set_lines(0, 0, -1, false, ascii_msg)
	vim.cmd("normal! G")
end

local function make_curl_args_for_specified_llm(options, prompt, llm_behavior, llm_api_provider)
	local url = options.url

	if llm_api_provider == "anthropic" then
		local api_key = get_api_key(options.api_key_name)
		local data = {
			system = llm_behavior,
			messages = { { role = "user", content = prompt } },
			model = options.model,
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
	else
		if llm_api_provider == "ollama" then
			local data = { system = llm_behavior, prompt = prompt, model = options.model, stream = true }
			local json_data = vim.json.encode(data)
			local args = { "-N", "-X", "POST", "-H", "Content-Type: application/json", "-d", json_data, url }
			return args
		end
	end
end

local function handle_ollama_spec_data(data_stream)
	local json = vim.json.decode(data_stream)
	if json.response then
		write_string_at_cursor(json.response)
	end
	if json.done then
		write_string_at_cursor("\n")
	end
end

local function handle_anthropic_spec_data(data_stream, event_state)
	if event_state == "content_block_delta" then
		local json = vim.json.decode(data_stream)
		if json.delta and json.delta.text then
			write_string_at_cursor(json.delta.text)
		end
	end
end

local group = vim.api.nvim_create_augroup("PROMPT_ASSISTANT_AutoGroup", { clear = true })
local active_job = nil

local function call_llm(options)
	vim.api.nvim_clear_autocmds({ group = group })
	local prompt = get_prompt_for_llm_and_adjust_cursor(options.replace)
	local args = make_curl_args_for_specified_llm(options, prompt, options.llm_behavior, options.llm_api_provider)
	local curr_event_state = nil

	if options.display_on_new_window then
		open_new_window_before_write(options.llm_api_provider)
	end

	local function parse_and_call(line)
		if options.llm_api_provider == "anthropic" then
			local event = line:match("^event: (.+)$")
			if event then
				curr_event_state = event
				return
			end
			local data_match = line:match("^data: (.+)$")
			if data_match then
				handle_anthropic_spec_data(data_match, curr_event_state)
			end
		end

		if options.llm_api_provider == "ollama" then
			handle_ollama_spec_data(line)
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

local M = {}

M.config = {
	anthropic = {
		url = "https://api.anthropic.com/v1/messages",
		model = "claude-3-5-sonnet-20240620",
		api_key_name = "ANTHROPIC_API_KEY",
	},
	ollama = {
		url = "http://localhost:11434/api/generate",
		model = "llama3.1",
	},
	default_behavior = "You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.",
	display_on_new_window = false,
	replace = false,
}

function M.setup(options)
	M.config = vim.tbl_deep_extend("force", M.config, options or {})
end

function M.call_anthropic(options)
	options = options or {}
	local merged_options = vim.tbl_deep_extend("force", M.config, M.config.anthropic, options)

	call_llm({
		url = merged_options.url,
		model = merged_options.model,
		api_key_name = merged_options.api_key_name,
		llm_behavior = merged_options.behavior or M.config.default_behavior,
		replace = merged_options.replace,
		display_on_new_window = merged_options.display_on_new_window,
		llm_api_provider = "anthropic",
	})
end

function M.call_ollama(options)
	options = options or {}
	local merged_options = vim.tbl_deep_extend("force", M.config, M.config.ollama, options)

	call_llm({
		url = merged_options.url or os.getenv("OLLAMA_URL_LINK"),
		model = merged_options.model,
		llm_behavior = merged_options.behavior or M.config.default_behavior,
		replace = merged_options.replace,
		display_on_new_window = merged_options.display_on_new_window,
		llm_api_provider = "ollama",
	})
end

return M
