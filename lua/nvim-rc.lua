local M = {}

local a = vim.api

local f = vim.fn

local rc_file_name = ".nvimrc.lua"

local levels = vim.log.levels

M.config = {
	allow_dir = f.stdpath("data") .. "/allow",
}

local function short(path)
	return f.fnamemodify(path, ":~:.")
end

local function notify(msg, level)
	vim.notify(msg, level, { title = "nvim-rc" })
end

--- Like `vim.fn.findfile` but returns all matches.
---@return string[]
local function find_all_rc_files()
	local path = f.getcwd() .. "/"

	local acc = {}

	repeat
		local last_path = path
		path = f.fnamemodify(path, ":h")
		local file = path .. "/" .. rc_file_name

		if f.filereadable(file) == 1 then
			table.insert(acc, file)
		end

	until path == last_path

	return f.reverse(acc)
end

M.find_all_rc_files = find_all_rc_files

local function allow_file_path(checksum)
	return M.config.allow_dir .. "/" .. checksum
end

local function print_deny_err(path)
	notify(string.format("%s is blocked. Run `:RcAllow` to allow its content", short(path)), levels.ERROR)
end

--- Generate a checksum for a file.
---@param file string
---@return string
local function gen_checksum(file)
	local lines = f.systemlist("openssl sha256 " .. file)
	local line = lines[1]
	return vim.split(line, " ", { plain = true, trimempty = true })[2]
end

local function is_allowed(path)
	local sum = gen_checksum(path)
	local allow_file = allow_file_path(sum)

	if f.filereadable(allow_file) == 1 then
		-- Take the first line only
		local contents = f.readfile(allow_file)[1]
		if contents == path then
			return true
		else
			return false
		end
	else
		return false
	end
end

local function denied_files()
	local acc = {}
	for _, path in ipairs(find_all_rc_files()) do
		if not is_allowed(path) then
			table.insert(acc, path)
		end
	end
	return acc
end

local function allowed_files()
	local acc = {}
	for _, path in ipairs(find_all_rc_files()) do
		if is_allowed(path) then
			table.insert(acc, path)
		end
	end
	return acc
end

local function source(path)
	notify("loading " .. short(path), levels.INFO)
	dofile(path)
end

local function with_interactive_choice(choices, prompt, callback, default)
	if #choices == 0 then
		error("Expected at least one choice")
	end

	if #choices == 1 then
		callback(choices[1])
		return
	end

	vim.ui.select(choices, {
		prompt = prompt,
	}, function(selected)
		if selected then
			callback(selected)
		end
	end)
end

-- Find all .nvimrc.lua files from the current file to the root. For each
-- check if the file matches a saved checksum, if the file does then source it,
-- if it does not then terminate, and prompt the user that they need to
-- run a command to allow the file for loading.
function M.load_rc_files()
	for _, path in ipairs(find_all_rc_files()) do
		if is_allowed(path) then
			source(path)
		else
			print_deny_err(path)
		end
	end
end

--- Allow a file to be sourced, this will save the checksum of the file
--- to a file in the allow directory. Immediately sources the file after
--- approval.
function M.allow(args)
	local choices = find_all_rc_files()

	if #choices == 0 then
		notify("No .nvimrc.lua files found", levels.ERROR)
		return
	end

	with_interactive_choice(choices, "Select a file to allow", M.allow_file)
end

--- Allow a file to be sourced. Immediately source the file after approval.
function M.allow_file(path)
	local sum = gen_checksum(path)
	local allow_file = allow_file_path(sum)

	f.writefile({ path }, allow_file)
	source(path)
end

--- List all allowed checksums.
function M.ls()
	vim.pretty_print(f.systemlist("ls -C " .. M.config.allow_dir))
end

--- Edit an rc file, prompts for selection if there are multiple.
function M.edit()
	local choices = find_all_rc_files()

	if #choices == 0 then
		vim.cmd.edit(rc_file_name)
		return
	end

	with_interactive_choice(choices, "Select a file to edit", function(selected)
		vim.cmd.edit(selected)
	end)
end

--- Revoke a previous authorization.
function M.revoke()
	local choices = allowed_files()

	if #choices == 0 then
		notify("No .nvimrc.lua files found", levels.ERROR)
		return
	end

	with_interactive_choice(choices, "Select a file to revoke", M.revoke_file)
end

--- Deny a file from being sourced.
function M.revoke_file(path)
	local sum = gen_checksum(path)
	local allow_file = allow_file_path(sum)

	if f.filereadable(allow_file) == 1 then
		f.delete(allow_file)
		notify(short(path) .. " revoked", levels.INFO)
	end
end

function M.setup()
	f.mkdir(M.config.allow_dir, "p")

	a.nvim_create_user_command("RcAllow", M.allow, {})

	a.nvim_create_user_command("RcEdit", M.edit, {})

	a.nvim_create_user_command("RcReload", M.load_rc_files, {})

	a.nvim_create_user_command("RcRevoke", M.revoke, {})

	a.nvim_create_user_command("RcLs", M.ls, {})

	local group = a.nvim_create_augroup("nvim-rc", { clear = true })

	a.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
		group = group,
		pattern = "*",
		callback = M.load_rc_files,
	})
end

return M
