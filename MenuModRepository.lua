MenuModRepository = MenuModRepository or class()

MenuModRepository.MODS = {}

function MenuModRepository.register_mod(name, settings_file, localization_file, class)
	MenuModRepository.MODS[name] = (class or MenuModBase):new(name, settings_file, localization_file)
	return MenuModRepository.MODS[name]
end

function MenuModRepository.mod(name)
	return MenuModRepository.MODS[name]
end
