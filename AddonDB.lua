local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local mod = {}
Core.AddonDB = mod


function mod:Init()
	self.show_index = 1
	self.new_custom_addon = {}
	self:InitOptions()
	self:AddonDBUpdate()
	self.addon_db_strings = self:AddonDBPrintString()
	self:AddonDBListShow(self.show_index)
end

function mod:InitOptions()
	self.options = {
		type = "group",
	    handler = self,
	    disabled = function () return Core:ProcessQuene_IsBusy() end,
		name = "插件信息库",
		order = 7,
		args = {
			instruction = {
				type = "description",
				name = "插件信息库，用于保存每个插件的SavedVariables信息（就是什么东西会存在WTF文件里面）",
				order = 1,
			},
			custom_addon_db = {
				type = "group",
				name = "自定义信息库",
				order = 2,
				args = {
					unknown = {
						type = "group",
						name = "未知插件",
						desc = "在插件库中无信息的插件",
						order = 1,
						inline = true,
						args = {
							addon_name = {
								type = "description",
								name = function () return self.unknown_addon_string or "" end,
								order = 1,
							},
						},
					},
					custom_add = {
						type = "group",
						name = "新增自定义信息",
						inline = true,
						order = 2,
						args = {
							addon_name = {
								type = "input",
								name = "插件名称",
								desc = "插件文件夹的名字，不是游戏中名字",
								get = function () return self.new_custom_addon.addon_name end,
								set = function (info, val) self.new_custom_addon.addon_name = val end,
								order = 1,
							},
							db_names = {
								type = "input",
								name = "库名称(如无，可不填)",
								desc = "插件toc文件中##SavedVaribles对应的库名",
								get = function () return self.new_custom_addon.db_names end,
								set = function (info, val) self.new_custom_addon.db_names = val end,
								order = 2,
							},
							add = {
								type = "execute",
								name = "新增信息",
								func = "CustomAddonDB_New",
								order = 3,
							},
						},
					},
					custom_list = {
						type = "group",
						name = "显示自定义信息",
						order = 3,
						inline = true,
						args = {

						},
					},
				},
			},
			block = {
				type = "group",
				name = "黑名单",
				--inline = true,
				order = 2,
				args = {
					desc = {
						type = "description",
						name = "在黑名单中的插件将被屏蔽导入和导出",
						order = 2,
					},
					new = {
						type = "input",
						name = "加入黑名单",
						desc = "插件文件夹的名字，不是游戏中名字",
						get = function () return "" end,
						set = function (info, val) if val and val ~= "" then self:BlockedAddon_New(val) end end,
						order = 1,
					},
					reset = {
						type = "execute",
						name = "重置黑名单",
						confirm = function() return "是否重置黑名单" end,
						func = "BlockedAddon_Reset",
						order = 4,
					},
					list = {
						type = "group",
						name = "已屏蔽插件",
						order = 3,
						inline = true,
						args = {

						},
					},
				},
			},
			default_addon_db = {
				type = "group",
				name = "内置信息库",
				order = 4,
				args = {
					pageup = {
						type = "execute",
						name = "<<",
						func = "PrevPage",
						width = "half",
						order = 1,
					},
					pagedown = {
						type = "execute",
						name = ">>",
						func = "NextPage",
						width = "half",
						order = 2,
					},
					number = {
						type = "description",
						name = function () return "   " .. math.modf( self.show_index / 20 ) + 1 .. " / " .. math.modf( #self.addon_db_strings / 20 ) + 1 .. " 页"end,
						width = "normal",
						order = 3,
					},
					restore = {
						type = "execute",
						name = "重置内置信息库",
						confirm = function() return "是否重置内置信息库？已导入信息将被重置" end,
						func = "DefaultAddonDB_Reset",
						order = 4,
					},
				},
			},

		},
	}
	Core.options.args.config.args.addondb_tab = self.options
end


local function orderednext(t, n)
	local key = t[t.__next]
	if not key then return end
	t.__next = t.__next + 1
	return key, t.__source[key]
end

function orderedpairs(t, f)
	local keys, kn = {__source = t, __next = 1}, 1
	for k in pairs(t) do
		keys[kn], kn = k, kn + 1
	end
	table.sort(keys, f)
	return orderednext, keys
end

function mod:AddonDBUpdate()
	self:DefaultAddonDB_Load()
	-- if not Core.db.global.default_addon_db then self:DefaultAddonDB_Reset() end
	if not Core.db.profile.custom_addon_db then self:CustomAddonDB_Reset() end
	if not Core.db.profile.blocked_addon then self:BlockedAddon_Reset() end
	-- self.default_addon_db = Core.db.global.default_addon_db
	self.custom_addon_db = Core.db.profile.custom_addon_db
	self.blocked_addon = Core.db.profile.blocked_addon
	self.addon_db = self:MergeAddonDB(Core:deepCopy(self.default_addon_db),self.custom_addon_db)
	self.unknown_addon_string = self:UnknownAddonString()
	self:CustomAddonDB_OptionUpdate()
	self:BlockedAddon_OptionUpdate()
	if not Core.loading then Core.Export:AddonListRefresh() end
end


function mod:DefaultAddonDB_Load()
	self.default_addon_db = Core:deepCopy(Core.Default.default_addon_db)
	local load_other = {
		["BigFoot"] = "bigfoot",
		["!!!163UI!!!"] = "aby",
		["EuiInfoDB"] = "eui",
		[Core.addon_name] = "manual",
	}
	for check_addon, addon_db in pairs(load_other) do
		if self:IsAddonInstalled(check_addon) then self:MergeAddonDB(self.default_addon_db,Core.Default.default_addon_db_other[addon_db]) end
	end
	if Core.db.profile.default_addon_db_update then
		for version, db_update in orderedpairs(Core.db.profile.default_addon_db_update) do
			if version > Core.Default.default_addon_db.version then
				self:MergeAddonDB(self.default_addon_db,db_update)
			end
		end
	end
end
function mod:DefaultAddonDB_Reset()
	if Core.db.profile.default_addon_db_update then wipe(Core.db.profile.default_addon_db_update) else Core.db.profile.default_addon_db_update = {} end
	self:AddonDBUpdate()
end

function mod:CustomAddonDB_Reset()
	if Core.db.profile.custom_addon_db then wipe(Core.db.profile.custom_addon_db) else Core.db.profile.custom_addon_db = {} end
	self:AddonDBUpdate()
end

function mod:BlockedAddon_Reset()
	if Core.db.profile.blocked_addon then wipe(Core.db.profile.blocked_addon) end
	Core.db.profile.blocked_addon = Core:deepCopy(Core.Default.default_blocked_addon)
	self:AddonDBUpdate()
end

function mod:UnknownAddonString()
	local unknown = {}
	for i = 1, GetNumAddOns() do
		addon_name,addon_title = GetAddOnInfo(i)
		if not self.addon_db[addon_name] then tinsert(unknown, addon_name) end
	end
	return strjoin(", ", unpack(unknown))
end

function mod:MergeAddonDB(db_A,db_B)
	for addon_name, db_names in pairs(db_B) do
		if not db_A[addon_name] then db_A[addon_name] = {} end
		for _, db_name in pairs(db_names) do 
			if not tContains(db_A[addon_name], db_name) then tinsert(db_A[addon_name],db_name) end
		end
	end
	return db_A
end


function mod:CustomAddonDB_New()
	if (not self.new_custom_addon.addon_name) or (self.new_custom_addon.addon_name == "") then Core:SetStatusText("未填插件名") return nil end
	local addon_name = self.new_custom_addon.addon_name
	--if (not self.new_custom_addon.db_names) or (self.new_custom_addon.db_names == "") then Core:SetStatusText("未填库名") return nil end
	local db_names = {}
	if (self.new_custom_addon.db_names) and (self.new_custom_addon.db_names ~= "") then 
		db_names = {strsplit(",",self.new_custom_addon.db_names)}
		for k,v in pairs(db_names) do db_names[k] = v:match( "^%s*(.-)%s*$" ) end
	end
	local new_custom_addon = { [addon_name] = db_names }
	self.custom_addon_db = self:MergeAddonDB(self.custom_addon_db, new_custom_addon)
	wipe(self.new_custom_addon)
	self:AddonDBUpdate()
	Core:SetStatusText("新增插件库："..addon_name)
end

function mod:CustomAddonDB_Remove(addon_name)
	if not addon_name then return nil end
	self.custom_addon_db[addon_name] = nil
	self:AddonDBUpdate()
	Core:SetStatusText("已删除插件信息：："..addon_name)
end

function mod:CustomAddonDB_OptionUpdate()
	local options = {}
	for addon_name,db_names in pairs(self.custom_addon_db) do
		local addon_string = "[|cFF00FF00" .. addon_name .. "|r]: "
		if #db_names == 0 then addon_string = addon_string .. "无" else addon_string = addon_string .. strjoin(", ", unpack(db_names)) end		
		local option = {
			type = "group",
			inline = true,
			name = "",
			args = {
				del = {	
					type = "execute",
					name = "删除",
					func = function() self:CustomAddonDB_Remove(addon_name) end,
					confirm = function() return "是否删除此条插件信息：" .. addon_name end,
					width = "half",
					order = 1,
				},
				addon_string = {
					type = "description",
					name = addon_string,
					order = 2,
					width = 2,
				},
			},
		}
		options[addon_name] = option
	end
	self.options.args.custom_addon_db.args.custom_list.args = options
	Core:RefreshDialog()
end


function mod:BlockedAddon_OptionUpdate()
	local options = {}
	for i, addon_name in ipairs(self.blocked_addon) do
		if self:IsAddonInstalled(addon_name) then
			local option = {
				type = "execute",
				name = addon_name,
				desc = "点击删除",
				confirm = function () return "是否将"..addon_name .."移出黑名单？" end,
				func = function () self:BlockedAddon_Remove(addon_name) end,
				order = i
			}
			options[addon_name] = option
		end
	end
	self.options.args.block.args.list.args = options
	Core:RefreshDialog()
end

function mod:BlockedAddon_New(addon_name)
	tinsert(self.blocked_addon, addon_name)
	sort(self.blocked_addon)
	self:BlockedAddon_OptionUpdate()
end

function mod:BlockedAddon_Remove(addon_name)
	for k,v in pairs(self.blocked_addon) do
		if v == addon_name then tremove(self.blocked_addon, k) break end
	end
	self:BlockedAddon_OptionUpdate()
end

function mod:IsBlockedAddon(addon_name)
	return tContains(self.blocked_addon, addon_name)
end

function mod:PrevPage()
	self.show_index = self.show_index - 20
	if self.show_index < 1 then self.show_index = 1 end
	self:AddonDBListShow(self.show_index)
end

function mod:NextPage()
	if self.show_index + 20 > #self.addon_db_strings then return nil end 
	self.show_index = self.show_index + 20
	self:AddonDBListShow(self.show_index)
end


function mod:AddonDBListShow(show_index)
	local addon_db_list = {
		type = "group",
		name = "",
		inline = true,
		order = 8,
		args = {}
	}
	local addon_db_strings = self.addon_db_strings
	for i = show_index,show_index+20 do
		if i > #addon_db_strings then break end
		addon_db_string = addon_db_strings[i]
		local addon_db = {
			type = "description",
			name = addon_db_string,
			width = "full",
			order = i,
		}
		local name = "addon" .. i
		addon_db_list.args[name] = addon_db
	end
	self.options.args.default_addon_db.args.addon_db_list = addon_db_list
end

function mod:AddonDBPrintString()
	local addon_db_strings = {}
	local installed_addons = self:GetInstalledAddons()
	for i, addon_name in pairs(installed_addons) do
		local addon_db_string = ""
		db_names = self.addon_db[addon_name]
		if not db_names then
			addon_db_string = addon_db_string .."[|cFF00FF00" .. addon_name .. "|r]: |cFFFF0000未知|r"
		else
			if (#db_names == 0) then 
				addon_db_string = addon_db_string .."[|cFF00FF00" .. addon_name .. "|r]: 无"
			else
				addon_db_string = addon_db_string .. "[|cFF00FF00" .. addon_name .. "|r]: "
				for k,db_name in ipairs(db_names) do
					if k ~= 1 then addon_db_string = addon_db_string .. ", " end
					addon_db_string = addon_db_string .. db_name
				end
			end
		end
		tinsert(addon_db_strings,addon_db_string)
	end
	sort(addon_db_strings)
	return addon_db_strings
end


function mod:GetLoadedAddons()
	local loaded = {}
	for i = 1, GetNumAddOns() do
		addon_name,addon_title = GetAddOnInfo(i)
		if IsAddOnLoaded(i) then loaded[#loaded+1] = addon_name end
	end
	self.loaded_addons = loaded
	return loaded
end

function mod:GetInstalledAddons()
	local installed = {}
	for i = 1, GetNumAddOns() do
		addon_name,addon_title = GetAddOnInfo(i)
		installed[#installed+1] = addon_name
	end
	self.installed_addons = installed
	return installed
end

function mod:IsAddonInstalled(addon_name)
	if not addon_name then return false end
	if not self.installed_addons then self:GetInstalledAddons() end
	return tContains(self.installed_addons, addon_name)
end

function mod:GetAceDB(addon_name)
	local db_registry = LibStub("AceDB-3.0").db_registry
	local db_names = self.addon_db[addon_name]
	if (not db_names) or (#db_names == 0) then return nil end
	for k, db_name in pairs(db_names) do
		for db, v in pairs(db_registry) do
			if db.sv == _G[db_name] then return db end
		end
	end
	return nil
end

function mod:GetAddonCategory(addon_name)
	--not_installed, not_loaded, unknown, non_config, blacklist, normal, acedb
	if not self:IsAddonInstalled(addon_name) then return "not_installed" end
	local loaded = self:GetLoadedAddons()
	if not tContains(loaded, addon_name) then return "not_loaded" end
	if self:IsBlockedAddon(addon_name) then return "blocked" end
	if not self.addon_db[addon_name] then return "unknown" end
	if #self.addon_db[addon_name] == 0 then return "non_config" end
	--if not Core.Rule:AddonNotInBlacklist(addon_name) then return "blacklist" end
	if Core.Rule:GetRule(addon_name) then return "rule" 
	elseif self:GetAceDB(addon_name) then return "acedb" 
	else return "normal" end
end

function mod:GetGoodCategoryNames()
	return {"rule","acedb","normal"}
end

function mod:GetAllCategoryNames()
	return {"rule","acedb","normal","non_config","blocked","unknown","not_loaded","not_installed"}
end

function mod:GetCategoryDescName(category)
	local desc_names = {
		["acedb"] = "使用AceDB的插件（可按AceDB规则导出）",
		["normal"] = "正常可导出的插件",
		["rule"] = "已添加导出规则的插件",
		["non_config"] = "无需配置的插件",
		["unknown"] = "未知插件",
		["blocked"] = "已屏蔽插件",
		["not_loaded"] = "已安装但未启用的插件",
		["not_installed"] = "未安装插件",
	}
	return desc_names[category]
end
--/dump APS.AddonDB:IsAce("AddonProfileShare")
