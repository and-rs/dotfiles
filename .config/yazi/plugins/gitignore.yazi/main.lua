-- Gitignore plugin for Yazi
-- Reads .gitignore files and provides exclude patterns to the core

local M = {}

-- Parse a .gitignore file and return patterns
local function parse_gitignore(file_path)
	local patterns = {}
	local file = io.open(tostring(file_path), "r")
	if not file then
		return patterns
	end

	for line in file:lines() do
		-- Trim whitespace
		line = line:match("^%s*(.-)%s*$")

		-- Skip empty lines and comments
		if line ~= "" and not line:match("^#") then
			-- Handle negation patterns
			local is_negation = line:sub(1, 1) == "!"
			if is_negation then
				line = line:sub(2)
			end

			-- Convert gitignore pattern to glob pattern
			-- Handle leading slash (relative to git root)
			if line:sub(1, 1) == "/" then
				line = line:sub(2)
			end

			-- Handle directory patterns (ending with /)
			local is_dir = line:sub(-1) == "/"
			if is_dir then
				line = line:sub(1, -2)
			end

			-- Add the pattern with negation prefix if needed
			local prefix = is_negation and "!" or ""

			-- Gitignore semantics: patterns without '/' match at any level
			-- Patterns with '/' match from the root
			if not line:match("/") then
				-- Pattern like "target" should match target anywhere
				-- For directories, match both the dir itself and its contents
				if is_dir then
					table.insert(patterns, prefix .. line)
					table.insert(patterns, prefix .. line .. "/**")
					table.insert(patterns, prefix .. "**/" .. line)
					table.insert(patterns, prefix .. "**/" .. line .. "/**")
				else
					-- For files, match at any level
					table.insert(patterns, prefix .. line)
					table.insert(patterns, prefix .. "**/" .. line)
				end
			else
				-- Pattern with slash - match from git root
				if is_dir then
					table.insert(patterns, prefix .. line)
					table.insert(patterns, prefix .. line .. "/**")
				else
					table.insert(patterns, prefix .. line)
				end
			end
		end
	end
	file:close()
	return patterns
end

-- Fetch gitignore patterns for current directory
function M:fetch(job)
	-- Get the directory from the job
	-- For fetchers, we need to determine the directory from the files being processed
	if not job or not job.files or #job.files == 0 then
		return true
	end

	-- Get the parent directory of the first file
	local first_file = tostring(job.files[1].url)
	local cwd = first_file:match("(.*/)")
	if cwd then
		cwd = cwd:sub(1, -2) -- Remove trailing slash
	else
		return true
	end

	-- Quick check: does .git directory exist?
	local git_dir = cwd
	local found_git = false

	-- Walk up to find .git directory (simple check without spawning processes)
	for _ = 1, 10 do -- Limit depth to avoid infinite loops
		local check_path = git_dir .. "/.git"
		local f = io.open(check_path, "r")
		if f then
			f:close()
			found_git = true
			break
		end

		-- Go up one directory
		local parent = git_dir:match("(.*/)")
		if not parent or parent == git_dir then
			break
		end
		git_dir = parent:sub(1, -2) -- Remove trailing slash
	end

	if not found_git then
		return true -- Not in a git repo
	end

	-- Find .gitignore in git root and parse patterns
	local gitignore_path = git_dir .. "/.gitignore"
	local patterns = parse_gitignore(gitignore_path)

	if #patterns == 0 then
		return true -- No patterns found
	end

	-- Debug: Log patterns being emitted
	for i, pattern in ipairs(patterns) do
	end

	-- Always emit patterns to ensure they're applied even when folder is loaded from history
	ya.mgr_emit("exclude_add", patterns)

	return true
end

return M
