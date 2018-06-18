local function get_subtable(hierarchy, tbl, add_empty)
	local tmp = tbl

	for _, nxt in ipairs(hierarchy or {}) do
		if not tmp[nxt] then 
			if add_empty then
				tmp[nxt] = {}
			else
				return nil
			end
		end

		tmp = tmp[nxt]
	end
	
	return tmp
end


MenuModRepository = MenuModRepository or {}

MenuModRepository.mods = {}

function MenuModRepository.register_mod(name, settings_file, localization_file, class)
	MenuModRepository.mods[name] = class:new(name, settings_file, localization_file)
end

function MenuModRepository.mod(name)
	return MenuModRepository.mods[name]
end



MenuModBase = MenuModBase or class()

function MenuModBase:init(name, settings_file, localization_file)
	self._name = name
	self._settings_file = settings_file
	self._localization_file = localization_file
	
	self._values_changed = false
	self._scripts_loaded = {}
	self._settings = {}
	self._defaults = {}
	self._menu_items = {}
	
	self:load()
end

function MenuModBase:post_require(script)
	if self._scripts_loaded[script] then
		return false
	end
	
	self._scripts_loaded[script] = true
	return true
end

function MenuModBase:name() return self._name end
function MenuModBase:settings() return self._settings end
function MenuModBase:defaults() return self._defaults end
function MenuModBase:menu_items() return self._menu_items end

--[[
	Builds a menu for a mod and menu structure, adding it to the BLT mod options menu or a specified parent menu
	Params:
		nodes: the menu node list provided by the BLT menu hook
		menu_data: the structure of the menu to build. A table containing an "id" string to define the name, a set of enumerated items to define the menu items to add, and a "sub_menus" table containing enumerated tables of the same structure to define sub-menus
		back_clbk: string containing the name of the function to call when the menu is exited. This function must also be manually added to the Payday 2 MenuCallbackHandler class
		parent_menu_id: optional string name of menu to add this menu to. Useful in combination with the add_blank_blt_menu function to re-use menus for multiple mods. If not specified, the parent menu will be the BLT mod options menu
		
		Ezample manu_data structure:
			{	
				id = "main",
				{ "divider", "divider", { size = 24 }},
				{ "unit_type", "input", { default = 1.15, float = true,  }},
				{ "enabled", "toggle", { default = false }},
				sub_menus = {
					{
						id = "multipliers",
						{ "damage", "slider", { default = 1, min = 0, max = 1, step = 0.1 }}
					},
					{
						id = "addends",
						{ "damage", "slider", { default = 0, min = 0, max = 10, step = 1, round = 0 }}
					},
				}
			}
]]
function MenuModBase:build_menu(nodes, menu_data, back_clbk, parent_menu_id)
	MenuBuilder.build_menu(nodes, self, menu_data, back_clbk, parent_menu_id)
end

function MenuModBase:has_settings(hierarchy)
	return get_subtable(hierarchy, self._settings) and true or false
end

function MenuModBase:get_value(hierarchy, setting, failsafe)
	local tbl = get_subtable(hierarchy, self._settings)
	
	if tbl and tbl[setting] ~= nil then
		return tbl[setting]
	else
		local default = self:get_default_value(hierarchy, setting)
		
		if default ~= nil then
			return default
		end
	end
	
	return failsafe
end

function MenuModBase:get_default_value(hierarchy, setting)
	local tbl = get_subtable(hierarchy, self._defaults, true)
	return tbl[setting]
end

function MenuModBase:set_value(hierarchy, setting, value)
	local tbl = get_subtable(hierarchy, self._settings, true)
	
	if tbl[setting] ~= value then
		tbl[setting] = value
		self._values_changed = true
	end
end

function MenuModBase:set_default_value(hierarchy, setting, value)
	local tbl = get_subtable(hierarchy, self._defaults, true)
	tbl[setting] = value
end

function MenuModBase:add_menu_items(hierarchy, added_items)
	local tbl = get_subtable(hierarchy, self._menu_items, true)
	
	for _, item_data in ipairs(added_items) do
		table.insert(tbl, item_data)
	end
end

function MenuModBase:clear_settings(hierarchy)
	local tbl = get_subtable(hierarchy, self._settings)
	
	local keys = {}
	for k, v in pairs(tbl) do
		if type(v) ~= "table" then
			table.insert(keys, k)
		end
	end
	for _, key in ipairs(keys) do
		tbl[key] = nil
	end
	
	self._values_changed = true
	
	self:_reset_items(hierarchy)
end

function MenuModBase:reload_items(hierarchy)
	for _, data in ipairs(get_subtable(hierarchy, self._menu_items)) do
		data.reload_clbk(data.item)
		
		local gui_node = data.item:parameters().gui_node
		if gui_node then
			gui_node:reload_item(data.item)
		end 
	end
end

function MenuModBase:save(force)
	if self._values_changed or force then
		self._values_changed = false
	
		local file = io.open(self._settings_file, "w+")
		
		if file then
			file:write(json.encode(self._settings))
			file:close()
		end
	end
end

function MenuModBase:load()
	local file = io.open(self._settings_file, "r")
	
	if file then
		self._values_changed = false
		self._settings = json.decode(file:read("*all"))
		file:close()
	end
end

function MenuModBase:_reset_items(hierarchy)
	for _, data in ipairs(get_subtable(hierarchy, self._menu_items)) do
		data.reset_to_default_clbk(data.item)
	end
	
	self:reload_items(hierarchy)
end



MenuBuilder = MenuBuilder or class()

MenuBuilder.BLT_OPTIONS_MENU_ID = "blt_options"
MenuBuilder.LOCALIZATION_STRINGS = {}

--[[
	Adds an empty menu directly to the BLT mod options menu. Useful for making plugin-style mods where multiple mods share a single main menu. To add submenus, use build_menu with the parent_menu_id
	Params:
		nodes: the menu node list provided by the BLT menu hook
		menu_data: table of menu parameters, at minimum an "id" string attribute defining the menu name, with optional "title" and "desc" strings for hard-coded localization
]]
function MenuBuilder.add_blank_blt_menu(nodes, menu_data)
	if not (MenuHelper.menus and MenuHelper.menus[menu_data.id]) then
		MenuCallbackHandler[menu_data.id .. "_back_clbk"] = function(self, item) end
	
		MenuHelper:NewMenu(menu_data.id)
		nodes[menu_data.id] = MenuHelper:BuildMenu(menu_data.id, { back_callback = menu_data.id .. "_back_clbk" })
		MenuHelper:AddMenuItem(nodes[MenuBuilder.BLT_OPTIONS_MENU_ID], menu_data.id, menu_data.id .. "_title", menu_data.id .. "_desc")
		
		if menu_data.title then MenuBuilder._add_localization_string(menu_data.id .. "_title", menu_data.title) end
		if menu_data.desc then MenuBuilder._add_localization_string(menu_data.id .. "_desc", menu_data.desc) end
	end
end

function MenuBuilder.build_menu(nodes, mod, menu_data, back_clbk, parent_menu_id)
	parent_menu_id = parent_menu_id or MenuBuilder.BLT_OPTIONS_MENU_ID

	if nodes[MenuBuilder.BLT_OPTIONS_MENU_ID] then
		MenuBuilder._initialize_menu(mod, menu_data, {})
		MenuBuilder._finalize_menu(nodes, mod:name(), menu_data, parent_menu_id, back_clbk)
	end
end

function MenuBuilder._init_templates()
	local function default_init_value(mod, hierarchy, setting, failsafe)
		return mod:get_value(hierarchy, setting, failsafe)
	end

	local function default_validate_value(item, data, fallback)
		return item:value() or fallback
	end

	local function default_serialize_value(item, data)
		return item:value()
	end

	local function default_deserialize_value(value)
		return value
	end

	MenuBuilder.TEMPLATES = {
		button = {
			blt_clbk = "AddButton",
			no_reload = true,
			init_value = function(...) return nil end,
			validate_value = default_validate_value,
			serialize_value = default_serialize_value,
			deserialize_value = default_deserialize_value,
			deserialize_value_2 = default_deserialize_value,
		},
		divider = {
			blt_clbk = "AddDivider",
			no_reload = true,
			init_value = function(...) return nil end,
			validate_value = default_validate_value,
			serialize_value = default_serialize_value,
			deserialize_value = default_deserialize_value,
			deserialize_value_2 = default_deserialize_value,
		},
		input = {
			blt_clbk = "AddInput",
			init_value = default_init_value,
			validate_value = function(item, data, fallback)
				local pattern = data.float and "^(-?%d*%.?%d+)$" or data.int and "^(-?%d+)$" or data.pattern or ""
				return string.match(item:value(), pattern) and item:value() or fallback
			end, 
			serialize_value = function(item, data) return (data.int or data.float) and tonumber(item:value()) or item:value() end,
			deserialize_value = function(value) return tostring(value) end,
			deserialize_value_2 = function(value) return tostring(value) end,
		},
		multichoice = {
			blt_clbk = "AddMultipleChoice",
			init_value = default_init_value,
			validate_value = default_validate_value,
			serialize_value = default_serialize_value,
			deserialize_value = default_deserialize_value,
			deserialize_value_2 = default_deserialize_value,
		},
		slider = {
			blt_clbk = "AddSlider",
			init_value = default_init_value,
			validate_value = function(item, data, fallback)
				if data.round then
					local p = math.pow(10, data.round)
					return math.round(item:value() * p) / p
				end
				
				return item:value()
			end,
			serialize_value = default_serialize_value,
			deserialize_value = default_deserialize_value,
			deserialize_value_2 = default_deserialize_value,
		},
		toggle = {
			blt_clbk = "AddToggle", 
			init_value = default_init_value,
			validate_value = default_validate_value,
			serialize_value = function(item, data) return item:value() == "on" end,
			deserialize_value = function(value) return value and "on" or "off" end,
			deserialize_value_2 = function(value) return value and true or false end,
		},
	}
	
	MenuBuilder.TEMPLATES.reset = MenuBuilder.TEMPLATES.button
end

function MenuBuilder._initialize_menu(mod, menu_data, hierarchy)
	local function default_change_clbk(mod, hierarchy, setting, value)
		mod:set_value(hierarchy, setting, value)
	end
	
	local function default_reset_clbk(mod, hierarchy, _, _)
		mod:clear_settings(hierarchy)
	end

	local added_items = {}
	local prefixed_menu_id = string.format("%s_%s", mod:name(), menu_data.id)
	
	MenuHelper:NewMenu(prefixed_menu_id)
	
	for i, item in ipairs(menu_data) do
		local i_name = item[1]	--Item name / setting associated with item
		local i_type = item[2]	--Item type
		local i_data = item[3] or {}	--Item parameters
		local template = MenuBuilder.TEMPLATES[i_type]
		local no_reload = i_data.no_reload or false
		local id = string.format("%s_%s", prefixed_menu_id, i_name)
		local change_clbk_id = string.format("%s_clbk", id)
		local localization_id = i_data.loc and string.format("%s_%s", mod:name(), i_data.loc) or id
		local params = { 
			id = id, 
			menu_id = prefixed_menu_id, 
			priority = -i, 
			callback = change_clbk_id,
			title = string.format("%s_title", localization_id), 
			desc = string.format("%s_desc", localization_id)
		}
		
		if i_data.title then
			MenuBuilder._add_localization_string(localization_id .. "_title", i_data.title)
		end
		if i_data.desc then
			MenuBuilder._add_localization_string(localization_id .. "_desc", i_data.desc)
		end
		
		mod:set_default_value(hierarchy, i_name, i_data.default)
		
		if i_type == "divider" then
			no_reload = true
			params.size = i_data.size
		elseif i_type == "reset" then
			local change_clbk = i_data.change_clbk or default_reset_clbk
			
			no_reload = true
			
			--Add handler for value changes
			MenuCallbackHandler[change_clbk_id] = function(_, item)
				change_clbk(mod, hierarchy)
			end
		else
			local change_clbk = i_data.change_clbk or default_change_clbk
			
			params.value = template.deserialize_value_2(template.init_value(mod, hierarchy, i_name))
			
			if i_type == "slider" then
				params.min = i_data.min
				params.max = i_data.max
				params.step = i_data.step
				params.show_value = true
			elseif i_type == "multichoice" then
				params.items = {}
				
				for _, option in ipairs(i_data.options) do
					table.insert(params.items, string.format("%s_%s", localization_id, option))
				end
			end
			
			--Add handler for value changes
			MenuCallbackHandler[change_clbk_id] = function(_, item)
				local value = template.validate_value(item, i_data, mod:get_value(hierarchy, i_name))
				
				if value ~= item:value() then
					item:set_value(value)
				end
				
				change_clbk(mod, hierarchy, i_name, template.serialize_value(item, i_data))
			end
			
		end
		
		--Add the item to the BLT menu
		MenuHelper[template.blt_clbk](MenuHelper, params)
		
		if not no_reload then
			local menu_items = MenuHelper:GetMenu(prefixed_menu_id)._items_list
			table.insert(added_items, { 
				item = menu_items[#menu_items],
				reset_to_default_clbk = i_data.reset_to_default_clbk or function(item)
					item:set_value(template.deserialize_value(template.init_value(mod, hierarchy, i_name))) 
				end,
				reload_clbk = i_data.reload_clbk or function(item) end,
			})
		end
	end
	
	mod:add_menu_items(hierarchy, added_items)
	
	--Recursive call to initialize sub menus
	for _, sub_menu_data in ipairs(menu_data.sub_menus or {}) do
		local new_hierarchy = table.list_copy(hierarchy)
		table.insert(new_hierarchy, sub_menu_data.id)
		MenuBuilder._initialize_menu(mod, sub_menu_data, new_hierarchy)
	end
end

function MenuBuilder._finalize_menu(nodes, prefix, menu_data, parent_menu_id, back_clbk)
	local prefixed_menu_id = string.format("%s_%s", prefix, menu_data.id)
	
	nodes[prefixed_menu_id] = MenuHelper:BuildMenu(prefixed_menu_id, { back_callback = back_clbk })
	MenuHelper:AddMenuItem(nodes[parent_menu_id], prefixed_menu_id, prefixed_menu_id .. "_title", prefixed_menu_id .. "_desc")
	
	if menu_data.title then
		MenuBuilder._add_localization_string(prefixed_menu_id .. "_title", menu_data.title)
	end
	if menu_data.desc then
		MenuBuilder._add_localization_string(prefixed_menu_id .. "_desc", menu_data.desc)
	end
	
	for _, sub_menu_data in pairs(menu_data.sub_menus or {}) do
		MenuBuilder._finalize_menu(nodes, prefix, sub_menu_data, prefixed_menu_id, back_clbk)
	end
end

function MenuBuilder._add_localization_string(id, text)
	if LocalizationManager and LocalizationManager.add_localized_strings then
		LocalizationManager:add_localized_strings({ [id] = text })
	else
		MenuBuilder.LOCALIZATION_STRINGS[id] = text
	end
end

--Initialize the static item template table
MenuBuilder._init_templates()


Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_MenuBuilder_localization", function(self)
	self:add_localized_strings(MenuBuilder.LOCALIZATION_STRINGS)
	MenuBuilder.LOCALIZATION_STRINGS = {}
end)