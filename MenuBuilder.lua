local printf = printf or function(...)
	log(string.format(...))
end

MenuBuilder = MenuBuilder or class()

MenuBuilder.BLT_OPTIONS_MENU_ID = "blt_options"
MenuBuilder.TEMPLATES = {}
MenuBuilder.LOCALIZATION_STRINGS = {}
MenuBuilder._NODE_CLBKS = {}

function MenuBuilder.create_menu_nodes(menu_node_clbk, mod)
	table.insert(MenuBuilder._NODE_CLBKS, { mod = mod, clbk = menu_node_clbk })
end

function MenuBuilder.insert_nodes(node_table)
	for _, data in ipairs(MenuBuilder._NODE_CLBKS) do
		local nodes = data.clbk(data.mod) or {}
		
		for _, node in ipairs(nodes) do
			local full_id = string.format("%s_%s", data.mod:name(), node.id)
			
			table.insert(node_table, {
				name = full_id,
				topic_id = node.title or (full_id .. "_title"),
				_meta = "node",
				modifier = node.initiator or "MenuBuilderInitiator",
				refresh = node.initiator or "MenuBuilderInitiator",
				update = node.initiator or "MenuBuilderInitiator",
				gui_class = node.gui_class,
			})
		end
	end
	
	MenuBuilder._NODE_CLBKS = {}
end

function MenuBuilder.initialize_menu(nodes, mod, data, main_menu_id, parent_menu_id)
	for id, node_data in pairs(data) do
		--Add each node to the lookup table for the initiators
		local node_id = string.format("%s_%s", mod:name(), id)
		MenuBuilderInitiator.NODE_DATA[node_id] = { mod = mod, node_data = node_data, id = id }
		
		--Set the back and focus callbacks for the node
		local node_params = nodes[node_id]:parameters()
		node_params.back_callback = type(node_data.back_callback) == "table" and node_data.back_callback or { node_data.back_callback } or {}
		node_params.focus_changed_callback = type(node_data.focus_changed_callback) == "table" and node_data.focus_changed_callback or { node_data.focus_changed_callback } or {}
	end
	
	--Use BLT to add an entry point to the main menu at the BLT options node or specified parent node
	parent_menu_id = parent_menu_id or MenuBuilder.BLT_OPTIONS_MENU_ID
	if nodes[parent_menu_id] then
		local node_id = string.format("%s_%s", mod:name(), main_menu_id)
		MenuHelper:AddMenuItem(nodes[parent_menu_id], node_id, node_id .. "_title", node_id .. "_desc")
	else
		printf("ERROR: Parent node '%s' not found while attempting to add menu for mod '%s'", tostring(parent_menu_id), tostring(mod:name()))
	end
end

--[[
	Manually adds a localization string
	Parameters:
		id: the localization ID
		text: the localization text
]]
function MenuBuilder.add_localization_string(id, text)
	if LocalizationManager and LocalizationManager.add_localized_strings then
		LocalizationManager:add_localized_strings({ [id] = text })
	else
		MenuBuilder.LOCALIZATION_STRINGS[id] = text
	end
end

--[[
	Creates an empty menu with the BLT options node as parent. Useful for creating a shared root menu for multiple mods by specifying the blank menu node as the parent node in the mod
	Parameters:
		nodes: the array of menu nodes from the BLT menu hook
		id: the full ID of the new menu node
		title: (Optional) Hard-coded title localization string
		title: (Optional) Hard-coded description localization string
]]
function MenuBuilder.add_blank_blt_menu(nodes, id, title, desc)
	if not (MenuHelper.menus and MenuHelper.menus[id]) then
		MenuHelper:NewMenu(id)
		nodes[id] = MenuHelper:BuildMenu(id, {})
		MenuHelper:AddMenuItem(nodes[MenuBuilder.BLT_OPTIONS_MENU_ID], id, id .. "_title", id .. "_desc")
		
		if title then MenuBuilder.add_localization_string(id .. "_title", title) end
		if desc then MenuBuilder.add_localization_string(id .. "_desc", desc) end
	end
end

function MenuBuilder._init_templates()
	--MenuBuilder.TEMPLATES.button = {}
	--MenuBuilder.TEMPLATES.divider = {}
	--MenuBuilder.TEMPLATES.multichoice = {}
	
	MenuBuilder.TEMPLATES.toggle = {
		deserialize_value = function(value) 
			return value and true or false
		end,
	}
	
	MenuBuilder.TEMPLATES.input = {
		validate_value = function(item)
			return string.match(item:value(), item:parameters().match_pattern) and item:value() or ""
		end, 
		
		serialize_value = function(item) 
			return item:parameters().is_number and tonumber(item:value()) or tostring(item:value())
		end,
		
		deserialize_value = function(value) 
			return tostring(value) 
		end,
	}
	
	MenuBuilder.TEMPLATES.slider = {
		validate_value = function(item)
			if item:parameters().round then
				local p = math.pow(10, item:parameters().round)
				return math.round(item:value() * p) / p
			end
			
			return item:value()
		end,
	}
end

MenuBuilder._init_templates()


Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_MenuBuilder_localization", function(self)
	self:add_localized_strings(MenuBuilder.LOCALIZATION_STRINGS)
	MenuBuilder.LOCALIZATION_STRINGS = {}
end)
