local Job = require("plenary.job")

local function get_env_value(name)
	if not name or type(name) ~= "string" then
		error("Invalid input: name must be a non-empty string")
	end
	local value = os.getenv(name)
	if not value then
		error("Environment variable '" .. name .. "' not found")
	end
	return value
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
	local ascii_file = get_env_value("HOME")
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
		local api_key = get_env_value(options.api_key_name)
		local data = {
			system = llm_behavior,
			messages = { { role = "user", content = prompt } },
			model = options.model,
			stream = true,
			max_tokens = options.max_tokens,
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
		max_tokens = 4096,
	},
	ollama = {
		model = "llama3.1:latest",
		url = "http://localhost:11434",
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
	local merged_options = vim.tbl_deep_extend("force", M.config, options)
	call_llm({
		url = merged_options.anthropic.url,
		model = merged_options.anthropic.model,
		api_key_name = merged_options.anthropic.api_key_name,
		llm_behavior = merged_options.behavior or M.config.default_behavior,
		replace = merged_options.replace,
		display_on_new_window = merged_options.display_on_new_window,
		llm_api_provider = "anthropic",
		max_tokens = merged_options.anthropic.max_tokens,
	})
end

function M.call_ollama(options)
	options = options or {}
	local merged_options = vim.tbl_deep_extend("force", M.config, options)

	call_llm({
		url = (merged_options.ollama.url or get_env_value("OLLAMA_URL_LINK")) .. "/api/generate",
		model = merged_options.ollama.model,
		llm_behavior = merged_options.behavior or M.config.default_behavior,
		replace = merged_options.replace,
		display_on_new_window = merged_options.display_on_new_window,
		llm_api_provider = "ollama",
	})
end

local function fetch_ollama_models(callback)
	local run_curl = require("plenary.curl")
	run_curl.get(M.config.ollama.url .. "/api/tags", {
		callback = vim.schedule_wrap(function(res)
			if res.status ~= 200 then
				local err_msg = type(res.body) == "string" and res.body or "HTTP error " .. res.status
				vim.notify("Error fetching models: " .. err_msg, vim.log.levels.ERROR)
				return callback({})
			end
			local ok, decoded = pcall(vim.json.decode, res.body)
			if not ok then
				vim.notify("Error parsing JSON response", vim.log.levels.ERROR)
				return callback({})
			end
			callback(vim.tbl_map(function(model)
				return model.name
			end, decoded.models))
		end),
	})
end

local function create_option_window(options)
	local api = vim.api
	local current_buf, current_win, ns_id

	local function update_highlight()
		if current_buf and current_win then
			api.nvim_buf_clear_namespace(current_buf, ns_id, 0, -1)
			local cursor = api.nvim_win_get_cursor(current_win)
			api.nvim_buf_add_highlight(current_buf, ns_id, "CursorLine", cursor[1] - 1, 0, -1)
		end
	end

	local function handle_selection()
		if current_win then
			local cursor = api.nvim_win_get_cursor(current_win)
			local selected_index = cursor[1] - 1 -- Subtract 1 because the first line is the title
			if selected_index > 0 and selected_index <= #options then
				api.nvim_win_close(current_win, true)
				M.call_ollama({ ollama = { model = options[selected_index] } })
				print("Selected model: " .. options[selected_index])
			end
		end
	end

	-- Create a new buffer
	current_buf = api.nvim_create_buf(false, true)

	-- Set buffer options
	api.nvim_buf_set_option(current_buf, "buftype", "nofile")
	api.nvim_buf_set_option(current_buf, "bufhidden", "wipe")

	-- Create content
	local lines = { "Choose a model:" }
	for i, option in ipairs(options) do
		table.insert(lines, string.format("%d. %s", i, option))
	end

	-- Set buffer lines
	api.nvim_buf_set_lines(current_buf, 0, -1, false, lines)

	-- Open the buffer in a new window
	local width = 30 -- Increased width to accommodate longer model names
	local height = #lines
	current_win = api.nvim_open_win(current_buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = (vim.o.columns - width) / 2,
		row = (vim.o.lines - height) / 2,
		style = "minimal",
		border = "rounded",
	})

	-- Set cursor to the first option
	api.nvim_win_set_cursor(current_win, { 2, 0 })

	-- Highlight the current line
	ns_id = api.nvim_create_namespace("OptionScreenHighlight")
	update_highlight()

	-- Set up keymaps for navigation and selection
	local opts = { noremap = true, silent = true }
	api.nvim_buf_set_keymap(
		current_buf,
		"n",
		"j",
		[[<cmd>lua vim.api.nvim_win_set_cursor(0, {math.min(vim.fn.line('.') + 1, vim.fn.line('$')), 0})<CR>]],
		opts
	)
	api.nvim_buf_set_keymap(
		current_buf,
		"n",
		"k",
		[[<cmd>lua vim.api.nvim_win_set_cursor(0, {math.max(vim.fn.line('.') - 1, 2), 0})<CR>]],
		opts
	)
	api.nvim_buf_set_keymap(
		current_buf,
		"n",
		"<CR>",
		"",
		{ noremap = true, silent = true, callback = handle_selection }
	)
	api.nvim_buf_set_keymap(current_buf, "n", "q", "<cmd>close<CR>", opts)

	-- Set up autocommand to update highlight when cursor moves
	api.nvim_create_autocmd("CursorMoved", {
		buffer = current_buf,
		callback = update_highlight,
	})
end

function M.create_option_screen()
	fetch_ollama_models(function(options)
		if #options == 0 then
			vim.schedule(function()
				vim.notify("No models available.", vim.log.levels.WARN)
			end)
			return
		end

		vim.schedule(function()
			create_option_window(options)
		end)
	end)
end

return M
