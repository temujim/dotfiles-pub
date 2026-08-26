--- @sync entry
return {
	entry = function()
		local h = cx.active.current.hovered
		if not h then
			ya.emit("tab_create", { current = true })
			return
		end

		if h.cha.is_dir then
			ya.emit("tab_create", { tostring(h.url) })
		else
			local parent = h.url.parent
			if parent then
				ya.emit("tab_create", { tostring(parent) })
				ya.emit("reveal", { tostring(h.url) })
			else
				ya.emit("tab_create", { current = true })
			end
		end
	end,
}
