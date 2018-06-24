MenuModRepository = MenuModRepository or class()

MenuModRepository.mods = {}

function MenuModRepository.register_mod(name, settings_file, localization_file, menu_nodes, class)
	local mod = (class or MenuModBase):new(name, settings_file, localization_file)
	
	MenuModRepository.mods[name] = mod
	MenuBuilder.create_menu_nodes(menu_nodes, mod)
	
	return MenuModRepository.mods[name]
end

function MenuModRepository.mod(name)
	return MenuModRepository.mods[name]
end

Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_MenuModRepository_localization", function(self)
	for id, mod in pairs(MenuModRepository.mods) do
		LocalizationManager:load_localization_file(mod:localization_file())
	end
end)
