local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")
local _,i,j,k,v

local mod = {}
Core.Backup = mod

function mod:Init()
	self:InitOptions()
	if not Core.db.global.backup then Core.db.global.backup = {} end
	self.backup = Core.db.global.backup 
	self.backup_key = self.backup_key or 1
end


function mod:InitOptions()
	self.options = {
		type = "group",
	    handler = self,
		name = "备份与还原",
		order = 4,
		disabled = function () return Core:ProcessQuene_IsBusy() end,
		args = {
			backup_group = {
				type = "group",
				name = "",
				inline = true,
				order = 1,
				args = {
					backup_header = {
						type = "header",
						name = "备份插件配置",
						order = 1,
					},
					backup_name = {
						type = "input",
						name = "备份名称(可选)",
						get = function() return self.backup_name end,
						set = function(info,val) self.backup_name = val end,
						order = 2,
					},
					backup = {
						type = "execute",
						name = "备份所有插件配置",
						confirm = function () return "确认备份所有插件配置？\n过程可能卡顿" end,
						func = function() self:BackupAllProfiles(self.backup_name) end,
						order = 3,
					},
				},
			},
			restore_group = {
				type = "group",
				name = "",
				inline = true,
				order = 2,
				handler = self,
				disabled = function () if (not self.backup_names) or (#self.backup_names == 0) then return true else return false end end,
				args = {
					restore_header = {
						type = "header",
						name = "还原插件配置",
						order = 1,
					},
					restore_select = {
						type = "select",
						name = "选择备份",
						values = function() return self:GetBackupNames() end,
						get = "GetBackupKeys",
						set = "SetBackupKey",
						width = "full",
						order = 2,
					},
					select_all = {
						type = "execute",
						name = "全选",
						width = "half",
						func = "RestoreAddonList_SelectAll",
						order = 3,
					},
					select_invert = {
						type = "execute",
						name = "反选",
						width = "half",
						func = "RestoreAddonList_SelectInvert",
						order = 4,
					},
					restore_button = {
						type = "execute",
						name = "恢复选择的插件",
						confirm = function () return "确认|cFF00FF00恢复|r以下档案？\n"..self.backup_names[self.backup_key] end,
						func = function() self:RestoreBackup(self.backup_key) end,
						order = 5 ,
					},
					delete_button = {
						type = "execute",
						name = "删除此备份",
						confirm = function () return "确认|cFFFF0000删除|r以下档案？\n"..self.backup_names[self.backup_key] end,
						func = function() self:DeleteBackup(self.backup_key) end,
						order = 6 ,
					},
					addon_list = {
						type = "multiselect",
						name = "备份含有插件列表",
						values = "RestoreAddonList_List",
						get = function ( info, val ) return self:RestoreAddonList_Get(val) end,
						set = function ( info, val1, val2 ) return self:RestoreAddonList_Set(val1, val2) end,
						order = 7 ,
					},
					addon_list_unavailable = {
						type = "multiselect",
						name = "备份含有，但未载入的插件",
						disabled = true,
						values = "RestoreAddonList_ListUnavailable",
						get = function () return false end,
						order = 8 ,
					},
				},
			},
		},
	}
	Core.options.args.backup_tab = self.options
end


function mod:GetBackupNames()
	local backup_names = {}
	for i, v in pairs(self.backup) do
		if v.is_auto_backup then
			backup_names[i] = string.format("|cFFFF0000%s|r  [%s-%s] %s",v.name,v.player_name,v.player_server,v.create_time)
		else
			backup_names[i] = string.format("|cFF00FF00%s|r  [%s-%s] %s",v.name,v.player_name,v.player_server,v.create_time)
		end
	end
	self.backup_names = backup_names
	return backup_names
end

function mod:GetBackupKeys()
	return self.backup_key
end

function mod:SetBackupKey(info, val)
	self.backup_key = val
	self:RestoreAddonList_Update()
	Core:RefreshDialog()
end


function mod:BackupAllProfiles(name)
	local backup_addon_list = {}
	for i = 1, GetNumAddOns() do
		addon_name,_ = GetAddOnInfo(i)
		if IsAddOnLoaded(i) and addon_name ~= Core.addon_name then
			backup_addon_list[addon_name] = true
		end
	end
	return self:BackupAddons(name, backup_addon_list, false)
end


function mod:BackupAddons(name, addon_list, is_auto_backup)
	local backup = {}
	backup.is_auto_backup = is_auto_backup
	backup.name = name or (is_auto_backup and "自动备份") or "未命名档案"
	backup.create_time = date("%Y-%m-%d %H:%M:%S",GetServerTime())
	backup.player_name = UnitName("player")
	backup.player_server = GetRealmName()
	local data = {}
	for addon_name,_ in pairs(addon_list) do
		Core:ProcessQuene_Add(0.1,self,"BackupProfiles", data, addon_name)
	end
	Core:ProcessQuene_Add(0.1,self,"BackupStringGenerate", data, backup)
end

function mod:BackupProfiles(data, addon_name)
	local db_names = Core.AddonDB.addon_db[addon_name]
	if db_names then
		data[addon_name] = {}
		for k,db_name in pairs(db_names) do
			--data[addon_name][db_name] = _G[db_name] and Core:Serialize(Core:deepCopy(_G[db_name]))
			data[addon_name][db_name] = _G[db_name] and Core:DataToString(Core:deepCopy(_G[db_name]))
		end
	end
	if #Core.process_quene == 1 then
		Core:SetStatusText("正在整理备份，会卡顿一会儿...")
	else
		Core:SetStatusText("正在备份插件，可能卡顿...剩余".. (#Core.process_quene - 1) .."  "..addon_name.." 完成!")
	end
end

function mod:BackupStringGenerate(data,backup)
	if data then
		--backup.data_string = Core:DataToString(Core:deepCopy(data))
		backup.data = Core:deepCopy(data)
		self:AddBackup(backup)
		Core:SetStatusText("备份完成")
	end
end

function mod:AddBackup(backup)
	tinsert(self.backup, 1, backup)
	self:RestoreAddonList_Update()
	Core:RefreshDialog()
end

function mod:RestoreAddonList_Update()
	local backup = self.backup[self.backup_key] 
	if not (backup and backup.data) then 
		self.restore_addon_list = {} 
		self.restore_addon_list_unavailable = {} 
		return nil 
	end

	local restore_addon_list = {}
	local restore_addon_list_unavailable = {}
	local data = backup.data
	for addon_name,addon_data in pairs(data) do
		if IsAddOnLoaded(addon_name) then
			restore_addon_list[addon_name] = select(2,GetAddOnInfo(addon_name))
		else
			restore_addon_list_unavailable[addon_name] = addon_name
		end
	end
	self.restore_addon_list = restore_addon_list
	self.restore_addon_list_unavailable = restore_addon_list_unavailable
end

function mod:RestoreAddonList_List()
	if not self.restore_addon_list then self:RestoreAddonList_Update() end
	return self.restore_addon_list
end

function mod:RestoreAddonList_ListUnavailable()
	if not self.restore_addon_list_unavailable then self:RestoreAddonList_Update() end
	return self.restore_addon_list_unavailable
end

function mod:RestoreAddonList_Get(val)
	if not self.restore_addon_list_not_choose then self.restore_addon_list_not_choose = {} end
	return not self.restore_addon_list_not_choose[val]
end

function mod:RestoreAddonList_SelectAll()
	if not self.restore_addon_list_not_choose then self.restore_addon_list_not_choose = {} else wipe(self.restore_addon_list_not_choose) end
end

function mod:RestoreAddonList_SelectInvert()
	if not self.restore_addon_list_not_choose then self.restore_addon_list_not_choose = {} end
	for addon_name, _ in pairs(self.restore_addon_list) do
		self.restore_addon_list_not_choose[addon_name] = not self.restore_addon_list_not_choose[addon_name]
	end
end


function mod:RestoreAddonList_Set(val1,val2)
	if val2 then
		self.restore_addon_list_not_choose[val1] = false
	else
		self.restore_addon_list_not_choose[val1] = true
	end
end



function mod:RestoreBackup(backup_key)
	--local data = Core:StringToData(self.backup[backup_key].data_string)
	local data = self.backup[backup_key].data
	for addon_name,addon_data in pairs(data) do
		if not (self.restore_addon_list_not_choose[addon_name] or self.restore_addon_list_unavailable[addon_name]) then
			Core:ProcessQuene_Add(0.1,self,"RestoreAddon", addon_name, addon_data)
		end
	end
	Core:ProcessQuene_Add(0.1,self,"RestoreAddonComplete")
end

function mod:RestoreAddon(addon_name,addon_data)
	for db_name,db_data_string in pairs(addon_data) do
		-- _G[db_name] = Core:Deserialize(db_data_string)
		_G[db_name] = Core:StringToData(db_data_string)
	end
	if #Core.process_quene == 1 then
		Core:SetStatusText("正在重载界面...")
	else
		Core:SetStatusText("正在恢复插件，可能卡顿...剩余".. (#Core.process_quene - 1) .."  "..addon_name.." 完成!")
	end
end


function mod:RestoreAddonComplete()
	local frame = LibStub("AceConfigDialog-3.0").popup
	frame:Show()
	frame.text:SetText("备份恢复已经完成，请问是否立即重载界面？")
	local height = 61 + frame.text:GetHeight()
	frame:SetHeight(height)

	frame.accept:ClearAllPoints()
	frame.accept:SetText("重载界面")
	frame.accept:SetPoint("BOTTOM", frame, "BOTTOM", 0, 16)
	frame.cancel:Hide()
	frame.accept:SetScript("OnClick", function(self) C_UI.Reload() end)
end

function mod:DeleteBackup(backup_key)
	local v = tremove(self.backup,backup_key)
	Core:SetStatusText(string.format("已删除备份：  %s  [%s-%s] %s",v.name,v.player_name,v.player_server,v.create_time))
	self:RestoreAddonList_Update()
	Core:RefreshDialog()
end