local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local mod = {}
Core.Export = mod


function mod:Init()
	self.addon_list = {}
	self:AddonLoadTrackerInit()
	self:AddonListRefresh()
	self:InitOptions()
end

function mod:InitOptions()
	self.options = {
		type = "group",
	    handler = self,
		name = "导出字符串",
		order = 2,
		disabled = function () return Core:ProcessQuene_IsBusy() end,
		args = {
			export_result = {
				type = "group",
				name = "",
				hidden = function() if self.export_string then return false else return true end end,
				inline = true,
				order = 1,
				args = {
					export_result_header = {
						type = "header",
						name = "导出结果",
						order = 1
					},
					export_result_string = {
						type = "input",
						name = "字符串",
						get = function() return self.export_string end,
						width = "full",
						order = 2,
					},
					export_result_instruction = {
						type = "description",
						name = function() return "字符串长度："..(self.export_string and #self.export_string or "") .."，请选中后，按下{Ctrl+A},{Ctrl+C}复制上方字符串" end,
						width = "full",
						order = 3,
					},
					export_string_info_show = {
						type = "execute",
						name = function () if self.export_string_info_show then return "隐藏插件表" else return "显示插件表" end end,
						func = function() self.export_string_info_show = not self.export_string_info_show end,
						order = 4,
					},
					export_string_info = {
						type = "input",
						name = "",
						multiline = 10,
						hidden = function() return not self.export_string_info_show end,
						get = function() return self.export_string_info end,
						width = "full",
						order = 5,
					},
					export_result_interval = {
						type = "description",
						name = "\n\n",
						width = "full",
						order = 6,
					},
				},
			},
			new_export = {
				type = "group",
				name = "",
				inline = true,
				order = 2,
				args = {
					new_export_header = {
						type = "header",
						name = "创建新导出字符串",
						order = 1
					},
					new_export_name = {
						type = "input",
						name = "档案名称(可选)",
						get = function() return self.export_name end,
						set = function(info,val) self.export_name = val end,
						order = 2,
					},
					new_export_description = {
						type = "input",
						name = "档案说明(可选)",
						get = function() return self.export_description end,
						set = function(info,val) self.export_description = val end,
						width = 3,
						order = 3,
					},
					new_export_button = {
						type = "execute",
						name = "导出所选插件配置",
						func = "ExportSelectAddonProfile",
						order = 4,
					},
				},
			},
			addon_list = {
				type = "group",
				inline = true,
				name = "",
				order = 3,
				args = {
					addon_list_header = {
						type = "header",
						name = "插件列出",
						order = 1
					},
					select_all = {
						type = "execute",
						name = "全选",
						width = "half",
						func = "Export_SelectAll",
						order = 2,
					},
					select_invert = {
						type = "execute",
						name = "反选",
						width = "half",
						func = "Export_SelectInvert",
						order = 3,
					},
					refresh = {
						type = "execute",
						name = "刷新",
						width = "half",
						func = "AddonListRefresh",
						order = 4,
					},
					addon_list_content = {
						type = "group",
						name = "",
						inline = true,
						order = 5,
						args = {},
					},
				},
			},
		},
	}
	for i, category in ipairs(Core.AddonDB:GetAllCategoryNames()) do
		local options = {
			type = "multiselect",
			name = function() return Core.AddonDB:GetCategoryDescName(category) end,
			values = function() return self.addon_list[category].name end,
			disabled = function() return not tContains(Core.AddonDB:GetGoodCategoryNames(),category) end,
			get = function ( info, val ) return self.addon_list[category].toggle[val] end,
			set = function ( info, val, val2 ) self.addon_list[category].toggle[val] = val2 end,
			order = i,
		}
		self.options.args.addon_list.args.addon_list_content.args[category] = options
	end
	Core.options.args.export_tab = self.options
end

function mod:AddonListRefresh()
	local installed = Core.AddonDB:GetInstalledAddons()
	local addon_list = {}
	for i, category in ipairs(Core.AddonDB:GetAllCategoryNames()) do
		addon_list[category] = { name = {}, toggle = {}}
	end
	for _, addon_name in pairs(installed) do
		local addon_title = select(2,GetAddOnInfo(addon_name))
		local category = Core.AddonDB:GetAddonCategory(addon_name)
		addon_list[category] = addon_list[category] or { name = {}, toggle = {}}
		addon_list[category]["name"][addon_name] = addon_title
		addon_list[category]["toggle"][addon_name] = false
	end
	wipe(self.addon_list) 
	self.addon_list = addon_list
	Core:RefreshDialog()	
end


function mod:Export_SelectAll()
	for _,category in pairs(Core.AddonDB:GetGoodCategoryNames()) do
		for addon_name,toggle in pairs(self.addon_list[category].toggle) do
			self.addon_list[category]["toggle"][addon_name] = true
		end
	end
end

function mod:Export_SelectInvert()
	for _,category in pairs(Core.AddonDB:GetGoodCategoryNames()) do
		for addon_name,toggle in pairs(self.addon_list[category].toggle) do
			self.addon_list[category]["toggle"][addon_name] = not toggle
		end
	end
end

function mod:ExportSelectAddonProfile()
	local check_toggle
	local good_category = Core.AddonDB:GetGoodCategoryNames()
	for _,category in pairs(good_category) do
		for addon_name,toggle in pairs(self.addon_list[category].toggle) do
			if toggle then check_toggle = true break end
		end
	end
	if not check_toggle then Core:SetStatusText("未选择有效插件") return nil end

	self:ExportInit()
	for _,category in pairs(good_category) do
		for addon_name,toggle in pairs(self.addon_list[category].toggle) do
			if toggle then Core:ProcessQuene_Add(0.2,self,"ExportProfile",addon_name) end
		end
	end
	Core:ProcessQuene_Add(0.2,self,"ExportStringGenerate")
end

function mod:ExportStringGenerate()
	if self.export then
		self.export_string = Core:DataToString(self.export)
		self.export_string_info = self:ExportStringInfoGenerate()
		Core:SetStatusText("字符串长度："..#self.export_string.."  请复制上方字符串")
		Core:RefreshDialog()
	end
end

function mod:ExportStringInfoGenerate()
	local info = ""
	local export = self.export
	info = info .. "=======导出档案信息======="
	info = info .. "\n档案名称：" .. self.export.name
	if self.export.description ~= "" then info = info .. "\n档案说明：" .. self.export.description end
	info = info .. "\n建立时间：" .. self.export.create_time
	info = info .. "\n建立角色：" .. self.export.player_name .. " - ".. self.export.player_server

	local addon_list = self.addon_list
	info = info .. "\n=======已导出插件=======\n"
	local exported = {}
	local good_category = Core.AddonDB:GetGoodCategoryNames()
	for category,category_info in pairs(self.addon_list) do
		if tContains(good_category,category) then
			for addon_name,toggle in pairs(category_info.toggle) do
				if toggle then exported[#exported+1] = addon_name end
			end
		end
	end
	sort(exported)
	info = info.. strjoin(", ", unpack(exported))
	info = info .. "\n=======未导出插件=======\n"
	local not_exported = {}
	for category,category_info in pairs(self.addon_list) do
		if tContains(good_category,category) then
			for addon_name,toggle in pairs(category_info.toggle) do
				if not toggle then not_exported[#not_exported+1] = addon_name end
			end
		end
	end
	for category,category_info in pairs(self.addon_list) do
		if (not tContains({"not_loaded","not_installed"},category)) and (not tContains(good_category,category))then
			for addon_name,toggle in pairs(category_info.toggle) do
				not_exported[#not_exported+1] = addon_name
			end
		end
	end
	sort(not_exported)
	info = info.. strjoin(", ", unpack(not_exported))
	info = info .. "\n=======未开启插件=======\n"
	local not_loaded = {}
	for category,category_info in pairs(self.addon_list) do
		if tContains({"not_loaded","not_installed"},category) then
			for addon_name,toggle in pairs(category_info.toggle) do
				not_loaded[#not_loaded+1] = addon_name
			end
		end
	end
	sort(not_loaded)
	info = info.. strjoin(", ", unpack(not_loaded))
	return info
end

function mod:ExportInit()
	if self.export then wipe(self.export) else self.export = {} end
	self.export.AddonProfileShare = "AddonProfileShareExportStrings"
	self.export.version = Core.version
	self.export.compatible = Core.compatible
	self.export.name = self.export_name or "未命名档案"
	self.export.description = self.export_description or ""
	self.export.create_time = date("%Y-%m-%d %H:%M:%S",GetServerTime())
	self.export.player_name = UnitName("player")
	self.export.player_server = GetRealmName()
	self.export.data = {}
end


function mod:ExportProfile(addon_name)
	category = Core.AddonDB:GetAddonCategory(addon_name)
	if category == "rule" then
		self.export.data[addon_name] = {type = category}
		self.export.data[addon_name].data_string = Core:DataToString(self:ExportRuleProfile(addon_name))
	elseif category == "acedb" then
		self.export.data[addon_name] = {type = category}
		self.export.data[addon_name].data_string = Core:DataToString(self:ExportAceProfile(addon_name))
	elseif category == "normal" then
		self.export.data[addon_name] = {type = category,data_string = {}}
		db_names = Core.AddonDB.addon_db[addon_name]
		for k,db_name in pairs(db_names) do
			self.export.data[addon_name].data_string[db_name] = Core:DataToString(Core:deepCopy(_G[db_name]))
		end
	end
	if #Core.process_quene == 1 then
		Core:SetStatusText("正在生成字符串，会卡顿一会儿...")
	else
		Core:SetStatusText("正在导出插件，可能卡顿...剩余".. (#Core.process_quene - 1) .."  "..addon_name.." 完成!")
	end
end

function mod:AddonLoadTrackerInit()
	local addon_load_tracker = self.addon_load_tracker or CreateFrame("Frame")
	addon_load_tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon_load_tracker:SetScript("OnEvent", function(self, event, addon_name)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		--self:RegisterEvent("ADDON_LOADED")
		mod:AddonListRefresh()
	end)
	self.addon_load_tracker = addon_load_tracker
end

--
function mod:ExportAceProfile(addon_name)
	local db = Core.AddonDB:GetAceDB(addon_name)
	if not db then return nil end

	local profile_name = db:GetCurrentProfile()
	local export_db = {}
	export_db.profile_name = profile_name
	export_db.profile = Core:deepCopy(db.profile)
	export_db.global = Core:deepCopy(db.global)

	local namespaces = db.sv.namespaces
	if namespaces then 
		export_db.namespaces = {}
		for ns, _ in pairs(namespaces) do
			local ns_db = db:GetNamespace(ns,true)
			if ns_db then
				export_db.namespaces[ns] = {}
				export_db.namespaces[ns].profile = Core:deepCopy(ns_db.profile)
				export_db.namespaces[ns].global = Core:deepCopy(ns_db.global)
			end
		end
	end
	return export_db
end


--/dump APS.Export:ExportRuleProfile("D")
--/dump APS.Rule:GetRule("AddonProfileShare")
function mod:ExportRuleProfile(addon_name)
	local rule = Core.Rule:GetRule(addon_name)
	if not rule then return nil end
	return self:GetProfileFromRule(addon_name, rule)
end


function mod:GetProfileFromRule(addon_name, rule)
	local db_names = Core.AddonDB.addon_db[addon_name]
	if not (db_names and #db_names > 0) then return nil end
	local addon_name = addon_name
	local player_name = UnitName("player")
	local player_server = GetRealmName()
	local param_dict = {
		["$name$"] = player_name,
		["$server$"] = player_server,
		["$addon$"] = addon_name,
	}
	local profile_name = rule.profile_name and self:ParseRule_GetProfileName(addon_name, db_names, param_dict, rule.profile_name) or nil
	if profile_name then param_dict["$profile$"] = profile_name.value end
	local profile = {}
	for _, path_pattern in pairs(rule.profile_path) do
		self:ParseRule_GetProfileFromPath(addon_name, db_names, param_dict, path_pattern, profile)
	end
	local name_rule = rule.name_rule or nil
	local value_set = rule.value_set or nil
	local result = {
		profile_name = profile_name,
		profile = profile,
		name_rule = name_rule,
		value_set = value_set,
	}
	return result
end

function mod:ParseRule_GetProfileName(addon_name, db_names, param_dict, profile_name_path)
	local path = {strsplit("/", profile_name_path)}
	local match_result = self:ParseRule_MatchPattern( addon_name, db_names, path, param_dict )
	--GLOBAL_MATCH =  match_result
	if #match_result > 0 then 
		return match_result[1]
	else return nil end
end

function mod:ParseRule_GetProfileFromPath(addon_name, db_names, param_dict, path_pattern, result)
	local path = {strsplit("/", path_pattern)}
	local match_result = self:ParseRule_MatchPattern( addon_name, db_names, path, param_dict, result)
end


local function findpatterintable(value, key, path, parent, depth, param_dict, result)
	local tar = path[depth]
	if not tar then return nil end
	if strfind(tar, "[", 1, true) and strfind(tar, "]", -1, true) then 
		tar = strsub(tar, 2, -2)
		local non
		if strfind(tar, "^", 1, true) then non = true tar = strsub(tar, 2, -1) else non = false end
		tar_list = {strsplit("|", tar)}
		local find = tContains(tar_list,key)
		if non then find = not find end
		if find and depth == #path then
			result[#result+1] = {path = parent and strjoin("/",parent,key) or key, value = value}
		elseif type(value) == "table" then
			for sub_key,sub_value in pairs(value) do
				findpatterintable(sub_value, sub_key, path, parent and strjoin("/",parent,key) or key, depth+1, param_dict, result)
			end
		end
	elseif strfind(tar, "{", 1, true) and strfind(tar, "}", -1, true) then 
		tar = "^" .. strsub(tar, 2, -2) .. "$"
		if string.gmatch(key,tar) and depth == #path then
			result[#result+1] = {path = parent and strjoin("/",parent,key) or key, value = value}
		elseif type(value) == "table" then
			for sub_key,sub_value in pairs(value) do
				findpatterintable(sub_value, sub_key, path, parent and strjoin("/",parent,key) or key, depth+1, param_dict, result)
			end
		end
	else
		tar = Core.Rule:GetParseString(tar,param_dict)
		--for k,v in pairs(param_dict) do tar = Core:StrReplace(tar, k, v) end  -- change param
		if key == tar and depth == #path then
			result[#result+1] = {path = parent and strjoin("/",parent,path[depth]) or path[depth], value = value}
		elseif type(value) == "table" then
			for sub_key,sub_value in pairs(value) do
				findpatterintable(sub_value, sub_key, path, parent and strjoin("/",parent,key) or key, depth+1, param_dict, result)
			end
		end
	end
end

function mod:ParseRule_MatchPattern( addon_name, db_names, path, param_dict, result )
	local result = result or {}
	for _,db_name in pairs(db_names) do
		db = Core:deepCopy(_G[db_name])
		if db then
			findpatterintable(db, db_name, path, nil, 1, param_dict,result)
		end
	end
	return result
end



--/tinspect APS.Export:ExportAceProfile("Bartender4")

-- /run Bartender4ACE = APS.Export:ExportAceProfile("Bartender4")
-- /run APS.Export:ApplyAceProfile("Bartender4",Bartender4ACE)