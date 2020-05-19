local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local mod = {}
Core.Backup = mod

function mod:Init()
	-- self.new_rule = {}
	-- if not Core.settings.blacklist then Core.settings.blacklist = Core:deepCopy(self.default_blacklist) end
	-- self.blacklist = Core.settings.blacklist
	self:InitOptions()
	if not Core.db.global.backup then 
		Core.db.global.backup = {} 
	end
	self.backup = Core.db.global.backup 
	-- self:RuleListUpdate()
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
						name = "备份管理",
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
					restore_button = {
						type = "execute",
						name = "恢复到选择备份",
						confirm = function () return "确认|cFF00FF00恢复|r以下档案？\n"..self.backup_names[self.backup_key] end,
						func = function() self:RestoreBackup(self.backup_key) end,
						order = 3 ,
					},
					delete_button = {
						type = "execute",
						name = "删除选择备份",
						confirm = function () return "确认|cFFFF0000删除|r以下档案？\n"..self.backup_names[self.backup_key] end,
						func = function() self:DeleteBackup(self.backup_key) end,
						order = 4 ,
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
		backup_names[i] = string.format("%s  [%s-%s] %s",v.name,v.player_name,v.player_server,v.create_time)
	end
	self.backup_names = backup_names
	return backup_names
end

function mod:GetBackupKeys()
	self.backup_key = self.backup_key or 1
	return self.backup_key
end

function mod:SetBackupKey(info, val)
	self.backup_key = val
end

function mod:BackupAllProfiles(name)
	local backup = {}
	backup.name = name or "未命名档案"
	backup.create_time = date("%Y-%m-%d %H:%M:%S",GetServerTime())
	backup.player_name = UnitName("player")
	backup.player_server = GetRealmName()
	local data = {}
	local i
	for i = 1, GetNumAddOns() do
		addon_name,_ = GetAddOnInfo(i)
		if IsAddOnLoaded(i) and addon_name ~= Core.addon_name then
			Core:ProcessQuene_Add(0.2,self,"BackupProfiles", data, addon_name)
		end
	end
	Core:ProcessQuene_Add(0.2,self,"BackupStringGenerate", data, backup)
	
end

function mod:BackupProfiles(data, addon_name)
	local db_names = Core.AddonDB.addon_db[addon_name]
	if db_names then
		data[addon_name] = {}
		for k,db_name in pairs(db_names) do
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
		backup.data_string = Core:DataToString(Core:deepCopy(data))
		self:AddBackup(backup)
		Core:SetStatusText("备份完成")
	end
end

function mod:AddBackup(backup)
	tinsert(self.backup, 1, backup)
	Core:RefreshDialog()
end


function mod:RestoreBackup(backup_key)
	local data = Core:StringToData(self.backup[backup_key].data_string)
	for addon_name,addon_data in pairs(data) do
		Core:ProcessQuene_Add(0.2,self,"RestoreAddon", addon_name, addon_data)
	end
	Core:ProcessQuene_Add(0.2,self,"RestoreAddonComplete")
end

function mod:RestoreAddon(addon_name,addon_data)
	for db_name,db_data_string in pairs(addon_data) do
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
end