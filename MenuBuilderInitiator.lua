local printf = printf or function(...)
	log(string.format(...))
end

MenuBuilderInitiator = MenuBuilderInitiator or class()

MenuBuilderInitiator.NODE_DATA = {}

function MenuBuilderInitiator:modify_node(node)
	self:_initialize_data(node, true)
	return self:modify(node)
end

function MenuBuilderInitiator:modify(node)
	self:_clear(node)
	self:_initialize_items(node)
	return node
end

function MenuBuilderInitiator:refresh_node(node)
	self:_initialize_data(node)
	return self:refresh(node)
end

function MenuBuilderInitiator:refresh(node)
	return node
end

function MenuBuilderInitiator:update_node(node)

end

function MenuBuilderInitiator:_initialize_data(node, create_callbacks)
	if not self._node_data then
		self._node_data = MenuBuilderInitiator.NODE_DATA[node:parameters().name]
		
		if self._node_data then
			self._mod = self._node_data.mod
			self._menu_data = self._node_data.node_data or {}
			self._menu_id = self._node_data.id
			self._prefix = string.format("%s_%s", self._mod:name(), self._menu_id)
			
			if create_callbacks then
				self:_initialize_callbacks()
			end
		end
	end
end

function MenuBuilderInitiator:_initialize_callbacks()
	self._clbk_id = string.format("%s_default_clbk", self._mod:name())
	self._visible_clbk_id = string.format("%s_default_visible_clbk", self._mod:name())
	self._enabled_clbk_id = string.format("%s_default_enabled_clbk", self._mod:name())
	
	local function exec_clbks(tbl, mod, item, ...)
		local result = true
		for _, clbk in ipairs(tbl or {}) do 
			result = result and clbk(mod, item, ...)
		end
		
		return result
	end
	
	MenuCallbackHandler[self._clbk_id] = MenuCallbackHandler[self._clbk_id] or function(_, item)	
		if item.validate_value then item:set_value(item.validate_value(item)) end
		
		local serialized_value = item.serialize_value and item.serialize_value(item) or item.value and item:value()
		
		return exec_clbks(item.change_clbks, self._mod, item, serialized_value)
	end
	
	MenuCallbackHandler[self._visible_clbk_id] = MenuCallbackHandler[self._visible_clbk_id] or function(_, item)
		return exec_clbks(item.visible_clbks, self._mod, item)
	end
	
	MenuCallbackHandler[self._enabled_clbk_id] = MenuCallbackHandler[self._enabled_clbk_id] or function(item)
		return exec_clbks(item.enabled_clbks, self._mod, item)
	end
end

function MenuBuilderInitiator:_initialize_items(node)
	for i, data in ipairs(self._menu_data) do
		local i_name, i_type, i_data = data[1], data[2], data[3]
		local item = self:_create_item(node, i_type, i_name, i_data)
	end
	
	self:_add_back_button(node)
end

function MenuBuilderInitiator:_clear(node)
	node:clean_items()
	self._node_data.items = {}
end

function MenuBuilderInitiator:_create_item(node, i_type, i_name, i_data)
	local create_clbk = self["_create_" .. i_type]
	
	if create_clbk then
		local id = string.format("%s_%s", self._prefix, i_name)
		local localization_id = i_data.localization and string.format("%s_%s", self._mod:name(), i_data.localization) or id
	
		if i_data.title then MenuBuilder.add_localization_string(localization_id .. "_title", i_data.title) end
		if i_data.desc then MenuBuilder.add_localization_string(localization_id .. "_desc", i_data.desc) end
		
		local data_node, params = create_clbk(self, id, localization_id, i_data)
		
		params.name = id
		params.visible_callback = self._visible_clbk_id
		params.enabled_callback = self._enabled_clbk_id
		params.color = i_data.color
		params.disabled_color = i_data.disabled_color
		--params.text_offset = ...
		--params.halign = ...
		--params.align = ...
		--params.no_text = ...
		--params.localize = ...
		
		local new_item = node:create_item(data_node, params)
		
		if new_item then
			self:_set_item_parameters(i_type, i_name, new_item, i_data)
			node:add_item(new_item)
			
			table.insert(self._node_data.items, new_item)
			
			--Slider fix from BLT to fix override that BLT apparently adds
			if i_type == "slider" then new_item.dirty_callback = nil end
			
			return new_item
		end
	else
		printf("ERROR: No callback for creating item of type '%s'", tostring(i_type))
	end
end

function MenuBuilderInitiator:_set_item_parameters(i_type, i_name, item, i_data)
	local template = MenuBuilder.TEMPLATES[i_type] or {}
	
	item.validate_value = template.validate_value
	item.serialize_value = template.serialize_value
	item.deserialize_value = template.deserialize_value
	item.change_clbks = {}
	item.visible_clbks = {}
	item.enabled_clbks = {}
	item.hierarchy = i_data.hierarchy or self._menu_data.hierarchy or { }
	item.mod = self._mod
	item.setting_name = i_name
	item.default_value = i_data.default_value
	item.reload_value = function(item)
		if item.set_value then
			local initial_value = self._mod:get_value(item.hierarchy, item.setting_name, item.default_value)			
			local v = item.deserialize_value and item.deserialize_value(initial_value) or initial_value
			
			if v ~= nil then
				item:set_value(v)
			end
		end
	end
	
	for _, clbk in ipairs(type(i_data.clbks) == "table" and i_data.clbks or { i_data.clbks } or {}) do
		table.insert(item.change_clbks, clbk)
	end
	for _, clbk in ipairs(type(i_data.visible_clbks) == "table" and i_data.visible_clbks or { i_data.visible_clbks } or {}) do
		table.insert(item.visible_clbks, clbk)
	end
	for _, clbk in ipairs(type(i_data.enabled_clbks) == "table" and i_data.enabled_clbks or { i_data.enabled_clbks } or {}) do
		table.insert(item.enabled_clbks, clbk)
	end
	
	item.reload_value(item)
end

function MenuBuilderInitiator:_create_divider(id, localization_id, params)
	local data = {
		text_id = params.use_text and (localization_id .. "_title"),
		
		no_text = not params.use_text,
		size = params.size or 12,
	}
	
	return { type = "MenuItemDivider" }, data
end

function MenuBuilderInitiator:_create_toggle(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
	}

	local opt_on = { 
		_meta = "option", 
		icon = "guis/textures/menu_tickbox", 
		s_icon = "guis/textures/menu_tickbox", 
		value = true, 
		x = 24, 
		y = 0, 
		w = 24, 
		h = 24, 
		s_x = 24, 
		s_y = 24, 
		s_w = 24, 
		s_h = 24
	}
	
	local opt_off = table.deep_map_copy(opt_on)
	opt_off.value = false
	opt_off.x = 0
	opt_off.s_x = 0
	
	return { opt_on, opt_off, type = "CoreMenuItemToggle.ItemToggle" }, data
end

function MenuBuilderInitiator:_create_multichoice(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
	}

	local data_node = { type = "MenuItemMultiChoice" }
	
	for i, option_data in ipairs(params.options) do
		table.insert(data_node, {
			_meta = "option",
			value = option_data.value,
			text_id = option_data.title or string.format("%s_opt_%s_title", id, tostring(option_data.value)),
			localize = not option_data.title,
		})
	end
	
	return data_node, data
end

function MenuBuilderInitiator:_create_slider(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
		
		round = params.round,
	}

	local data_node = {
		type = "CoreMenuItemSlider.ItemSlider",
		show_value = true,
		min = params.min,
		max = params.max,
		step = params.step,
	}

	return data_node, data
end

function MenuBuilderInitiator:_create_input(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
		
		is_number = params.int or params.float,
		match_pattern = params.int and "^(-?%d+)$" or params.float and "^(-?%d*%.?%d+)$" or "",
	}
	
	return { type = "MenuItemInput" }, data
end

function MenuBuilderInitiator:_create_textbox(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
	}

	return { type = "MenuItemTextBox" }, data
end

function MenuBuilderInitiator:_create_button(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		callback = self._clbk_id,
	}
	
	return { type = "CoreMenuItem.Item" }, data
end

function MenuBuilderInitiator:_create_menu_button(id, localization_id, params)
	local data = {
		text_id = localization_id .. "_title",
		help_id = localization_id .. "_desc",
		
		next_node = string.format("%s_%s", self._mod:name(), params.next_node),
	}
	
	return { type = "CoreMenuItem.Item" }, data
end

function MenuBuilderInitiator:_add_back_button(node)
	node:delete_item("back")

	local data = {
		visible_callback = "is_pc_controller",
		name = "back",
		back = true,
		text_id = "menu_back",
		last_item = true,
		previous_node = true
	}
	local new_item = node:create_item(nil, data)
	node:add_item(new_item)

	return new_item
end
