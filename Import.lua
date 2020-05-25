local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

local mod = {}
Core.Import = mod

function mod:Init()
	self.auto_backup_status = true
	self.options = {
		type = "group",
	    handler = self,
		name = "导入字符串",
		order = 3,
		disabled = function () return Core:ProcessQuene_IsBusy() end,
		args = {
			import_button = {
				type = "execute",
				name = "粘贴字符串",
				func = "ImportString_Window",
				order = 1,
			},
		},
	}
	Core.options.args.import_tab = self.options
end


function mod:ImportString_Analyse()
	if not self.import_string then return nil end
	Core:SetStatusText("正在分析字符串，可能卡顿...")
	self.import = Core:StringToData(self.import_string)
	local import = self.import
	local data = nil
	local info_string = ""
	local status_text = nil
	if import and import.AddonProfileShare and import.AddonProfileShare == "AddonProfileShareExportStrings" then
		if not (import.version and import.compatible) then
			info_string = "字符串版本信息无效"
		elseif import.version < Core.compatible then
			info_string = "字符串版本过低"
			status_text = info_string
			info_string = info_string .. string.format("\n字符串版本：%s\n插件版本：%s  最低兼容：%s", import.version, Core.version, Core.compatible)
		elseif import.compatible > Core.version then
			info_string = "字符串版本过高"
			status_text = info_string
			info_string = info_string .. string.format("\n字符串版本：%s  最低兼容：%s\n插件版本：%s", import.version, import.compatible, Core.version)
		else
			info_string = info_string .. "|cffffd100档案名称：|r" .. import.name
			info_string = info_string .. "\n|cffffd100档案说明：|r" .. import.description
			info_string = info_string .. "\n|cffffd100建立时间：|r" .. import.create_time
			info_string = info_string .. "\n|cffffd100建立角色：|r" .. import.player_name .. " - " .. import.player_server
			info_string = info_string .. "\n|cffffd100字符串版本：|r" .. import.version
			status_text = "档案分析完成，请选择导入"
			data = import.data
		end
	else
		local info_string = "未检测到有效字符串"
	end
	status_text = status_text or info_string
	Core:SetStatusText(status_text)
	self:ImportString_AnalyseData(info_string,data)
end

function mod:ImportString_AnalyseData(info_string,data)
	local option = {
		type = "group",
		--name = "字符串信息",
		inline = true,
		order = 3,
		args = {
			info = {
				type = "description",
				name = info_string,
				order = 1,
			},
			data = {
				type = "group",
				name = "",
				inline = true,
				order = 2,
				args = {},
			},
		},
	}

	if data then
		self.change_name = not self:ImportString_IsFromPlayer()
		self:ImportString_GetAddonList(data)
		option.args.data.args = self:ImportString_OptionsAddonList()
	end
	mod.options.args.import_info = option
	Core:RefreshDialog()
end

function mod:ImportString_IsFromPlayer()
	local import_player_name = self.import.player_name .. " - " .. self.import.player_server
	for k,_ in pairs(Core.db.sv.profileKeys) do
		if k == import_player_name then return true end
	end
	return false
end

function mod:ImportString_GetAddonList(data)
	local addon_list = {}
	addon_list.available_toggle = {}
	addon_list.available_names = {}
	addon_list.unavailable_names = {}
	for k,v in pairs(data) do 
		if IsAddOnLoaded(k) and not Core.AddonDB:IsBlockedAddon(k) then
			addon_list.available_names[k] = select(2,GetAddOnInfo(k))
			addon_list.available_toggle[k] = true
		else
			addon_list.unavailable_names[k] = k 
		end
	end
	self.addon_list = addon_list
end



function mod:ImportString_OptionsAddonList()
	local options = {
		buttons = {
			type = "group",
			inline = true,
			names = "",
			order = 1,
			args = {
				select_all = {
					type = "execute",
					name = "全选",
					width = "half",
					func = "ImportString_SelectAll",
					order = 1,
				},
				select_invert = {
					type = "execute",
					name = "反选",
					width = "half",
					func = "ImportString_SelectInvert",
					order = 2,
				},
				import = {
					type = "execute",
					name = "导入所选插件",
					confirm = function () return "确认导入设置，并立即重载界面？\n过程中可能会卡顿一会" end,
					func = "ApplyImportProfile",
					order = 3,
				},
				change_name = {
					type = "toggle",
					name = "修改角色名称",
					desc = "修改档案中的角色名称为你自己，如果与档案建立者是处于同一帐号下，最好不要修改角色名称",
					get = function () return self.change_name end,
					set = function (info, val) self.change_name = val end,
					width = 1,
					order = 4,
				},
				backup = {
					type = "toggle",
					name = "自动备份",
					desc = "导入插件前自动备份",
					get = function () return self.auto_backup_status end,
					set = function (info, val) self.auto_backup_status = val end,
					width = 1,
					order = 2,
				},
			},
		},
		list = {
			type = "group",
			inline = true,
			names = "",
			order = 2,
			args = {
				available = {
					type = "multiselect",
					name = "选择导入插件",
					values = self.addon_list.available_names,
					set = function ( info, val, val2 ) self.addon_list.available_toggle[val] = val2 end,
					get = function ( info, val ) return self.addon_list.available_toggle[val] end,
					order = 1,
				},
				unavailable = {
					type = "multiselect",
					name = "不可用插件（未加载或已屏蔽）",
					values = self.addon_list.unavailable_names,
					disabled = true,
					get = function ( info, val ) return false end,
					order = 2,
				},
			},
		},
	}
	return options
end

function mod:ImportString_SelectAll()
	for k,v in pairs(self.addon_list.available_toggle) do
		self.addon_list.available_toggle[k] = true
	end
end

function mod:ImportString_SelectInvert()
	for k,v in pairs(self.addon_list.available_toggle) do
		self.addon_list.available_toggle[k] = not v
	end
end

function mod:ApplyImportProfile()
	local import_addons = self:GetImportAddons()
	if not import_addons then return nil end
	if self.auto_backup_status then
		Core.Backup:BackupAddons(nil,import_addons,true)
	end
	do
		for addon_name,_ in pairs(import_addons) do
			Core:ProcessQuene_Add(0.1,self,"ApplyProfile",addon_name,self.import.data[addon_name])
		end
		Core:ProcessQuene_Add(0.1,self,"ApplyProfileComplete")
	end
end

function mod:GetImportAddons()
	local import_addons = {}
	if not (self.addon_list and self.addon_list.available_toggle and self.import and self.import.data) then return nil end
	for addon_name, chosen in pairs(self.addon_list.available_toggle) do
		if chosen and IsAddOnLoaded(addon_name) then
			import_addons[addon_name] = true
		end
	end
	return import_addons
end


function mod:ApplyProfile(addon_name, data)
	if (not data) or (not data.type) then return nil end
	if data.type == "rule" then
		self:ApplyRuleProfile(addon_name,Core:Deserialize(data.data_string))
	elseif data.type == "acedb" then
		self:ApplyAceProfile(addon_name,Core:Deserialize(data.data_string))
	elseif data.type == "normal" then
		for db_name,profile_string in pairs(data.data_string) do
			local profile
			if self.change_name then
				profile = self:Deserialize_ChangeName(profile_string)
			else
				profile = Core:Deserialize(profile_string)
			end
			_G[db_name] = profile
		end
	end
	if #Core.process_quene == 1 then
		Core:SetStatusText("正在重载界面...")
	else
		Core:SetStatusText("正在导入插件，可能卡顿...剩余".. (#Core.process_quene - 1) .."  "..addon_name.." 完成!")
	end
end

function mod:ApplyProfileComplete()
	local frame = LibStub("AceConfigDialog-3.0").popup
	frame:Show()
	frame.text:SetText("导入已经完成，请问是否立即重载界面？")
	local height = 61 + frame.text:GetHeight()
	frame:SetHeight(height)

	frame.accept:ClearAllPoints()
	frame.accept:SetText("重载界面")
	frame.accept:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	frame.cancel:Hide()
	frame.accept:SetScript("OnClick", function(self) C_UI.Reload() end)
end


function mod:Deserialize_ChangeName(profile_string)
	local profile_string = self:StringChangeName(profile_string,self.import.player_name,self.import.player_server,Core.player_name,Core.player_server)
	return Core:Deserialize(profile_string)
end


function mod:StringChangeName(serialized_string,source_name,source_server,target_name,target_server)
	if not (serialized_string and source_name and source_server and target_name and target_server) then return nil end
	local patterns = {
		{ source = source_name .. " - " .. source_server, target = target_name .. " - " .. target_server},
		{ source = source_name .. "-" .. source_server, target = target_name .. "-" .. target_server},
		{ source = source_name .. "@" .. source_server, target = target_name .. "@" .. target_server},
		{ source = source_server .. " - " .. source_name, target = target_server .. " - " .. target_name},
		{ source = source_server .. "-" .. source_name, target = target_server .. "-" .. target_name},
		--{ source = source_name, target = target_name},
	}
	for _, pattern in ipairs(patterns) do
		source = self:PatternSerializer(pattern.source)
		target = self:PatternSerializer(pattern.target)
		serialized_string = Core:StrReplace(serialized_string, source, target)
	end
	return serialized_string
end

function mod:PatternSerializer(pattern)
	local serialized_string = AceSerializer:Serialize(pattern)
	serialized_string = string.gsub(serialized_string, "^%^1","")
	serialized_string = string.gsub(serialized_string, "%^%^$","%^")
	return serialized_string
end


function mod:ImportString_Window()
	Core:SetStatusText("")
	return Core:BulkPasteWindow(self,"import_string","ImportString_Analyse")
end



function mod:ApplyAceProfile(addon_name,import_db)
	
	local db = Core.AddonDB:GetAceDB(addon_name, true)
	if (not db) or (not import_db) then return nil end

	local profile_key = Core.player_name .. " - " .. Core.player_server

	local except = {"namespaces","profiles","profileKeys","char","profile","profile_name"}

	local profile_name = "APS_Import"
	if not db.profiles then db.profiles = {} end
	db.profiles[profile_name] = import_db.profile
	if import_db.char then
		db.sv.char = db.sv.char or {}
		db.sv.char[profile_key] = import_db.char
	end

	for k,v in pairs(import_db) do
		if not tContains(except, k) then
			db.sv[k] = v
		end
	end

	local namespaces = import_db.namespaces
	if namespaces then 
		for ns, import_ns_db in pairs(namespaces) do
			db.sv.namespaces = db.sv.namespaces or {}
			db.sv.namespaces[ns] = db.sv.namespaces[ns] or {}
			db.sv.namespaces[ns].profiles = db.sv.namespaces[ns].profiles or {}
			db.sv.namespaces[ns].profiles[profile_name] = import_ns_db.profile
			if import_ns_db.char then
				db.sv.namespaces[ns].char = db.sv.namespaces[ns].char or {}
				db.sv.namespaces[ns].char[profile_key] = import_ns_db.char
			end
			for k,v in pairs(import_ns_db) do
				if not tContains(except, k) then
					db.sv.namespaces[ns][k] = v
				end
			end
		end
	end

	db.sv.profileKeys[profile_key] = profile_name
end


function mod:ApplyRuleProfile(addon_name,data)

	--data = {profile_name = {profile_name},	profile = {profile},	name_rule = name_rule}
	local addon_name = addon_name
	local player_name = Core.player_name
	local player_server = Core.player_server
	local param_dict = {
		["$name$"] = player_name,
		["$server$"] = player_server,
		["$addon$"] = addon_name,
	}
	if data.profile_name then param_dict["$profile$"] = data.profile_name.value end
	local profile_name
	if data.name_rule then 
		profile_name = Core.Rule:GetParseString(data.name_rule,param_dict)
	else
		profile_name = "APS_Import"
	end
	param_dict["$profile$"] = profile_name

	--set profileKeys
	if data.profile_name then
		self:ApplyRuleProfile_SetValue(data.profile_name.path, param_dict, profile_name)
	end

	--set profile
	if data.profile then
		for _, profile in pairs(data.profile) do
			self:ApplyRuleProfile_SetValue(profile.path, param_dict, profile.value)
		end
	end

	--set value
	if data.value_set then
		for key, value in pairs(data.value_set) do
			value = Core.Rule:GetParseString(value,param_dict)
			self:ApplyRuleProfile_SetValue(key, param_dict, value)
		end
	end

	--set func
	if data.set_func then
		local func_string = Core.Rule:GetParseString(data.set_func,param_dict)
		local set_func = loadstring(func_string)
		set_func(data)
	end

end

local function SetValue(tbl, depth, path, value)
	if depth == #path then
		tbl[path[depth]] = value
	else
		if (not tbl[path[depth]]) or (type(tbl[path[depth]]) ~= "table") then
			tbl[path[depth]] = {}
		end
		SetValue(tbl[path[depth]], depth+1, path, value)
	end
end

function mod:ApplyRuleProfile_SetValue(path_string, param_dict, value)
	-- print(path_string)
	-- GLOBAL_MATCH = value
	local path = {strsplit("/", path_string)}
	for i, _ in pairs(path) do
		path[i] = Core.Rule:GetParseString(path[i],param_dict)
	end
	SetValue(_G,1,path,value)
end

