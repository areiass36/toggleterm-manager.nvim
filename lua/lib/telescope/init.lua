local pickers, finders, make_entry, actions, actions_state, conf
if pcall(require, "telescope") then
	pickers = require("telescope.pickers")
	finders = require("telescope.finders")
	make_entry = require("telescope.make_entry")
	actions = require("telescope.actions")
	actions_state = require("telescope.actions.state")
	conf = require("telescope.config").values
else
	error("Cannot find telescope!")
end
local status_ok, _ = pcall(require, "toggleterm")
if not status_ok then
	error("Cannot find toggleterm!")
end
---

local displayer = require("lib.displayer").gen_displayer
---

local M = {}
M.open = function(opts)
	local bufnrs = vim.tbl_filter(function(b)
		return vim.api.nvim_buf_get_option(b, "filetype") == "toggleterm"
	end, vim.api.nvim_list_bufs())
	-- ╭────────────────────────────────────────────────────────────────────╮
	-- │                                note                                │
	-- ╰────────────────────────────────────────────────────────────────────╯
	-- uncommenting this prevents
	-- telescope from opening a modal windows when there are
	-- no terminal buffers open.
	-- ──────────────────────────────────────────────────────────────────────
	if not next(bufnrs) then
		print("no terminal buffers are opened/hidden")
		return
	end
	-- ──────────────────────────────────────────────────────────────────────
	table.sort(bufnrs, function(a, b)
		return vim.fn.getbufinfo(a)[1].lastused > vim.fn.getbufinfo(b)[1].lastused
	end)
	local buffers = {}
	local toggleterm_name_lengths = {}
	for _, bufnr in ipairs(bufnrs) do
		local info = vim.fn.getbufinfo(bufnr)[1]
		local term_number = vim.api.nvim_buf_get_var(info.bufnr, "toggle_number")
		local display_name = require("toggleterm.terminal").get(term_number, false).display_name
		local term_name = display_name or tostring(term_number) -- number icon if id is less than 11

		table.insert(toggleterm_name_lengths, #term_name)

		local flag = (bufnr == vim.fn.bufnr("") and "%") or (bufnr == vim.fn.bufnr("#") and "#" or " ")

		local element = {
			bufnr = bufnr,
			flag = flag,
			-- term_name = term_name,
			-- changed = info.changed,
			-- changedtick = info.changedtick,
			-- hidden = info.hidden,
			-- lastused = info.lastused,
			-- linecount = info.linecount,
			-- listed = info.listed,
			-- lnum = info.lnum,
			-- loaded = info.loaded,
			-- name = info.name,
			-- name = term_name,
			term_name = term_name,
			info = info,
			-- windows = info.windows,
			-- terminal_job_id = info.variables.terminal_job_id,
			-- terminal_job_pid = info.variables.terminal_job_pid,
			-- toggle_number = info.variables.toggle_number,
		}
		table.insert(buffers, element)
	end

	local entry_maker_opts = {}
	local max_toggleterm_name_length = math.max(unpack(toggleterm_name_lengths))
	-- local max_bufnr = math.max(bufnrs)
	-- entry_maker_opts.bufnr_width = #tostring(max_bufnr)
	entry_maker_opts.bufnr_width = max_toggleterm_name_length
	-- ──────────────────────────────────────────────────────────────────────
	pickers
		.new(opts, {
			prompt_title = "Terminal Buffers",
			previewer = conf.grep_previewer(opts),
			finder = finders.new_table({
				results = buffers,
				entry_maker = displayer(entry_maker_opts),
				-- entry_maker = function(entry)
				-- 	return {
				-- 		value = entry,
				-- 		text = tostring(entry.bufnr),
				-- 		display = tostring(entry.name),
				-- 		ordinal = tostring(entry.bufnr),
				-- 	}
				-- end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = actions_state.get_selected_entry()
					if selection == nil then
						return
					end
					local bufnr = tostring(selection.value.bufnr)
					local toggle_number = selection.value.toggle_number
					require("toggleterm").toggle_command(bufnr, toggle_number)
					vim.defer_fn(function()
						vim.cmd("stopinsert")
					end, 0)
				end)
				-- ╭────────────────────────────────────────────────────────────────────╮
				-- │                           setup mappings                           │
				-- ╰────────────────────────────────────────────────────────────────────╯
				local mappings = require("config").options.telescope_mappings
				for keybind, action in pairs(mappings) do
					map("i", keybind, function()
						action(prompt_bufnr)
					end)
				end
				return true
			end,
		})
		:find()
end
return M