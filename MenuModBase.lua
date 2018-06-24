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

MenuModBase = MenuModBase or class()

function MenuModBase:init(name, settings_file, localization_file)
	self._name = name
	self._settings_file = settings_file
	self._localization_file = localization_file
	
	self._values_changed = false
	self._scripts_loaded = {}
	self._settings = {}
	self._defaults = {}
	
	self:load()
end

function MenuModBase:initialize_menu(nodes, data, main_menu_id, parent_menu_id)
	MenuBuilder.initialize_menu(nodes, self, data, main_menu_id, parent_menu_id)
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
function MenuModBase:settings_file() return self._settings_file end
function MenuModBase:localization_file() return self._localization_file end

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

function MenuModBase:clear_settings(hierarchy)
	local tbl = get_subtable(hierarchy, self._settings)
	
	local keys = {}
	for k, v in pairs(tbl or {}) do
		if type(v) ~= "table" then
			table.insert(keys, k)
		end
	end
	for _, key in ipairs(keys) do
		tbl[key] = nil
	end
	
	self._values_changed = true
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
