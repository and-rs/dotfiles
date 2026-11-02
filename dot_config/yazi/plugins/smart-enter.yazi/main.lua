--- @sync entry

return {
	entry = function()
		local hovered = cx.active.current.hovered
		if not hovered then
			return
		end

		if hovered.cha.is_dir then
			ya.emit("enter", {})
		else
			ya.emit("open", {})
		end
	end,
}
