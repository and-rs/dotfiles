th.git = th.git or {}
th.git.untracked_sign = "?"
th.git.modified_sign = "~"
th.git.ignored_sign = "/"
th.git.deleted_sign = "-"
th.git.updated_sign = "!"
th.git.added_sign = "+"

require("git"):setup()

require("bookmarks"):setup({
	persist = "all",
})
