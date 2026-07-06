local black = "0"
local red = "1"
local green = "2"
local yellow = "3"
local blue = "4"
local magenta = "5"
local cyan = "6"
local white = "7"
local bright_black = "8"
local bright_red = "9"
local bright_green = "10"
local bright_yellow = "11"
local bright_blue = "12"
local bright_magenta = "13"
local bright_cyan = "14"
local bright_white = "15"
local terminal_default = "16"

maki.setup({
	always_yolo = true,

	keybinds = {
		tui = {
			editor = {
				cursor_up = { "up", "ctrl+p" },
				cursor_down = { "down", "ctrl+n" },
				delete_char_forward = { "delete", "ctrl+d" },
			},
			select = {
				up = { "up", "ctrl+p" },
				down = { "down", "ctrl+n" },
			},
		},
		app = {
			interrupt = "ctrl+s",
			editor_external = "ctrl+o",
			exit = "ctrl+c",
			tools_expand = "ctrl+e",
			model_cycle_forward = "ctrl+right",
			model_cycle_backward = "ctrl+left",
			session_toggle_path = "ctrl+p",
			session_toggle_named_filter = "ctrl+n",
			models_toggle_provider = "ctrl+t",
		},
	},

	theme = {
		splash = blue,
		splash_text = white,
		splash_text_highlighted = cyan,
		splash_tip = white,
		splash_tip_label = cyan,

		background = black,
		foreground = bright_white,

		user = bright_cyan,
		assistant = bright_white,
		assistant_prefix = bright_magenta,
		thinking = bright_black,

		tool_bg = black,
		tool = cyan,
		tool_path = blue,
		tool_annotation = bright_black,
		tool_prefix = yellow,
		tool_success = green,
		tool_error = red,
		tool_dim = bright_black,

		error = bright_red,
		status_dim = bright_black,
		status_notice = blue,
		status_retry_error = red,
		status_retry_info = bright_black,

		bold = bright_white,
		italic = bright_white,
		bold_italic = bright_white,
		inline_code = cyan,
		code_block = black,
		code_gutter = bright_black,
		strikethrough = bright_black,

		heading = magenta,
		list_marker = cyan,
		horizontal_rule = bright_black,
		plan_rule = magenta,
		table_border = bright_black,

		diff_old = red,
		diff_new = green,
		diff_old_emphasis = bright_red,
		diff_new_emphasis = bright_green,
		diff_line_nr = bright_black,

		todo_completed = green,
		todo_in_progress = yellow,
		todo_pending = bright_black,
		todo_cancelled = bright_black,

		item_selected = black,
		item = cyan,
		item_desc = bright_black,
		item_match = blue,
		item_match_selected = cyan,

		panel_border = blue,
		panel_title = blue,
		cursor = bright_white,
		input_border = bright_white,
		input_placeholder = bright_black,

		accent = cyan,
		active = cyan,
		keybind_key = cyan,
		keybind_desc = bright_white,
		keybind_section = magenta,

		mode_build = yellow,
		mode_plan = cyan,
		mode_bash = yellow,

		queue = magenta,
		queue_delete = red,
		plan_path = blue,
		timestamp = bright_black,
		spinner = yellow,

		index_section = magenta,
		index_line_nr = bright_black,
		index_keyword = magenta,
		shell_prefix = yellow,
	},
})
