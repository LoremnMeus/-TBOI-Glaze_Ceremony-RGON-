local g = require("Qing_Remaster_scripts.core.globals")
local enums = require("Qing_Remaster_scripts.core.enums")
local auxi = require("Qing_Remaster_scripts.auxiliary.functions")

local item = {
	ToCall = {},
}

function item.register_on(name,ent,params)
	params = params or {}
	Assembler_holder_in_synatic_pool = Assembler_holder_in_synatic_pool or {}
	if params.force then 
		if Assembler_holder_in_synatic_pool[name] then
			Assembler_holder_in_synatic_pool[name].Assemble_holder_linker = ent
			auxi.check_if_any(Assembler_holder_in_synatic_pool[name].on_Assemble_fail,Assembler_holder_in_synatic_pool[name],ent)
		end
		Assembler_holder_in_synatic_pool[name] = ent
	else 
		if Assembler_holder_in_synatic_pool[name] == nil then Assembler_holder_in_synatic_pool[name] = ent
		else
			auxi.check_if_any(ent.on_Assemble_fail,ent,Assembler_holder_in_synatic_pool[name])
			ent.Assemble_holder_linker = Assembler_holder_in_synatic_pool[name]
		end
	end
end

return item