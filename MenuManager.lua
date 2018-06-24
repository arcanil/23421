local pm_meta = getmetatable(PackageManager)
local script_data_original = pm_meta.script_data

local menus = {
	start_menu = true,
	pause_menu = true,
}

pm_meta.script_data = function(self, t, ...)
	local root = script_data_original(self, t, ...)
	
	if t == Idstring("menu") then
		for _, menu in ipairs(root) do
			if menu._meta == "menu" and menus[menu.id] then
				MenuBuilder.insert_nodes(menu)
			end
		end
	end
	
	
	return root
end
