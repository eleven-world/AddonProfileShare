local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local mod = {}
Core.Rule = mod

function mod:Init()
	self:LoadRule()
	self:MergeRule()
	self.rule_num_per_page = 10
	self:InitOptions()
end


function mod:LoadRule()
	if not Core.db.global.default_rule_list then Core.db.global.default_rule_list = Core:deepCopy(Core.Default.default_rule_list) end
	self.default_rule_list = Core.db.global.default_rule_list
	if not Core.db.profile.custom_rule_list then Core.db.profile.custom_rule_list = {} end
	self.custom_rule_list = Core.db.profile.custom_rule_list
end

function mod:MergeRule()
	self.rule_list = Core:tableMerge(Core:deepCopy(self.default_rule_list),Core:deepCopy(self.custom_rule_list))
end


function mod:InitOptions()
	self.options = {
		type = "group", handler = self, name = "规则管理", order = 6, args = {},
		disabled = function () return Core:ProcessQuene_IsBusy() end,
	}
	self:InitOptionsCustom(self.options.args)
	self:InitOptionsDefault(self.options.args)
	Core.options.args.config.args.rule_tab = self.options
end

function mod:InitOptionsCustom(path)
	self.new_custom_rule = {}
	self.custom_show_index = self.custom_show_index or 1
	local options = {
		type = "group",
	    handler = self,
		name = "自定义规则",
		order = 1,
		args = {
			new_rule = {
				type = "group", name = "新建规则", order = 1, args = {
					addon_name = {
						type = "input", name = "插件名称", width = "full", order = 1,
						get = function () return self.new_custom_rule.addon_name end,
						set = function (info, val) self.new_custom_rule.addon_name = val end,
					},
					profile_name = {
						type = "input", name = "档案名称路径", width = "full", order = 2,
						get = function () return self.new_custom_rule.profile_name end,
						set = function (info, val) self.new_custom_rule.profile_name = val end,
					},
					profile_path = {
						type = "input", name = "档案路径", width = "full", order = 3, multiline = 3,
						get = function () return self.new_custom_rule.profile_path end,
						set = function (info, val) self.new_custom_rule.profile_path = val end,
					},
					value_set = {
						type = "input", name = "变更键值", width = "full", order = 4, multiline = 3,
						get = function () return self.new_custom_rule.value_set end,
						set = function (info, val) self.new_custom_rule.value_set = val end,
					},
					name_rule = {
						type = "input", name = "名称命名规则", width = "full", order = 5,
						get = function () return self.new_custom_rule.name_rule end,
						set = function (info, val) self.new_custom_rule.name_rule = val end,
					},
					new_button = {
						type = "execute", name = "新建规则", width = "full", order = 6,
						func = function () self:NewRule( self.new_custom_rule.addon_name, self.new_custom_rule.profile_name, self.new_custom_rule.profile_path, self.new_custom_rule.value_set, self.new_custom_rule.name_rule ) end,
					},
				},
			},
			rule_list = {
				type = "group", name = "", order = 1, inline = true, args = {
					pageup = {
						type = "execute", name = "<<", func = "CustomPrevPage", width = "half", order = 1,
					},
					pagedown = {
						type = "execute", name = ">>", func = "CustomNextPage", width = "half", order = 2,
					},
					number = {
						type = "description", width = "normal", order = 3,
						name = function () return "   " .. math.modf( self.custom_show_index / self.rule_num_per_page ) + 1 .. " / " .. math.modf( #self.custom_rule_sorted_addon_names / self.rule_num_per_page ) + 1 .. " 页" end,
					},
				},
			},
		},
	}
	self:InitOptionsCustom_RuleList(options.args.rule_list.args)
	path.custom_tab = options
end

function mod:InitOptionsDefault(path)
	self.default_show_index = self.default_show_index or 1
	local options = {
		type = "group", handler = self, name = "内置规则", order = 2,
		args = {
			pageup = {
				type = "execute", name = "<<", func = "DefaultPrevPage", width = "half", order = 1,
			},
			pagedown = {
				type = "execute", name = ">>", func = "DefaultNextPage", width = "half", order = 2,
			},
			number = {
				type = "description", width = "normal", order = 3,
				name = function () return "   " .. math.modf( self.default_show_index / self.rule_num_per_page ) + 1 .. " / " .. math.modf( #self.default_rule_sorted_addon_names / self.rule_num_per_page ) + 1 .. " 页" end,
			},
			reset_button = {
				type = "execute", name = "重置内置规则", func = "ResetDefaultRule", order = 4,
			},
		},
	}
	self:InitOptionsDefault_RuleList(options.args)
	path.default_tab = options
end


function mod:ResetDefaultRule()
	Core.db.global.default_rule_list = Core:deepCopy(Core.Default.default_rule_list)
	self.default_rule_list = Core.db.global.default_rule_list
	self:MergeRule()
	self.default_show_index = 1
	self:InitOptionsDefault_RuleList()	
end


function mod:DefaultPrevPage()
	self.default_show_index = self.default_show_index - self.rule_num_per_page
	if self.default_show_index < 1 then self.default_show_index = 1 end
	self:InitOptionsDefault_RuleList()	
end

function mod:DefaultNextPage()
	if self.default_show_index + self.rule_num_per_page > #self.default_rule_sorted_addon_names then return nil end 
	self.default_show_index = self.default_show_index + self.rule_num_per_page
	self:InitOptionsDefault_RuleList()	
end

function mod:CustomPrevPage()
	self.custom_show_index = self.custom_show_index - self.rule_num_per_page
	if self.custom_show_index < 1 then self.custom_show_index = 1 end
	self:InitOptionsCustom_RuleList()
end


function mod:CustomNextPage()
	if self.custom_show_index + self.rule_num_per_page > #self.custom_rule_sorted_addon_names then return nil end 
	self.custom_show_index = self.custom_show_index + self.rule_num_per_page
	self:InitOptionsCustom_RuleList()
end

function mod:InitOptionsCustom_RuleList(path)
	local path = path or self.options.args.custom_tab.args.rule_list.args
	local options = {
		type = "group", handler = self, name = "自定义规则列表", inline = true, order = 5,
		args = {},
	}
	path.rule_list = options

	self.custom_rule_sorted_addon_names = {}
	for addon,_ in pairs(self.custom_rule_list) do
		tinsert(self.custom_rule_sorted_addon_names, addon)
	end
	sort(self.custom_rule_sorted_addon_names)

	for i = self.custom_show_index, self.custom_show_index + self.rule_num_per_page do
		local addon_name = self.custom_rule_sorted_addon_names[i]
		if addon_name then
			local option = {
				type = "group", inline = true, name = addon_name, order = i,
				args = {
					del = {
						type = "execute", name = "删除", order = 1,
						func = function () self:RemoveRule("custom", addon_name) end,
					},
					rule = {
						type = "description", width = "full", order = 2,
						name = function ()  return self:GetRuleString("custom", addon_name) end, 
					},
				},
			}
			options.args[addon_name] = option
		end
	end	
	Core:RefreshDialog()
end


function mod:InitOptionsDefault_RuleList(path)
	local path = path or self.options.args.default_tab.args
	local options = {
		type = "group", handler = self, name = "内置规则列表", inline = true,  order = 5,
		args = {},
	}
	path.rule_list = options

	self.default_rule_sorted_addon_names = {}
	for addon,_ in pairs(self.default_rule_list) do
		if Core.AddonDB:IsAddonInstalled(addon) then tinsert(self.default_rule_sorted_addon_names, addon) end
	end
	sort(self.default_rule_sorted_addon_names)

	for i = self.default_show_index, self.default_show_index + self.rule_num_per_page do
		local addon_name = self.default_rule_sorted_addon_names[i]
		if addon_name then
			local option = {
				type = "group", inline = true, name = addon_name, order = i,
				args = {
					del = {
						type = "execute", name = "删除", order = 1,
						func = function () self:RemoveRule("default", addon_name) end,
					},
					rule = {
						type = "description", width = "full", order = 2,
						name = function () return self:GetRuleString("default", addon_name) end, 
					},
				},
			}
			options.args[addon_name] = option
		end
	end	
	Core:RefreshDialog()
end

function mod:NewRule( addon_name, profile_name, profile_path, value_set, name_rule )
	if not (addon_name and profile_path) then return nil end
	profile_path = {strsplit("\n",profile_path)}
	if value_set then
		for _, pair_string in pairs({strsplit("\n",value_set)}) do
			local k,v = strsplit(":",pair_string) 
			value_set[k] = v
		end
	end
	self.custom_rule_list[addon_name] = {
		profile_name = profile_name,
		profile_path = profile_path,
		name_rule = name_rule,
	}
	Core:SetStatusText("新增规则："..addon_name)
	self:InitOptionsCustom_RuleList()
end


function mod:RemoveRule( list_type, addon_name )
	if list_type == "custom" then
		self.custom_rule_list[addon_name] = nil
		self:MergeRule()
		self:InitOptionsCustom_RuleList()
	elseif  list_type == "default" then
		self.default_rule_list[addon_name] = nil
		self:MergeRule()
		self:InitOptionsDefault_RuleList()
	end
	Core:SetStatusText("删除规则：".. list_type .. " : "..addon_name)
end

function mod:GetRuleString( list_type, addon_name )	
	local rule
	if list_type == "custom" then
		rule = self.custom_rule_list[addon_name]
	elseif  list_type == "default" then
		rule = self.default_rule_list[addon_name]
	else
		return nil
	end
	local rule_string = ""
	if rule.profile_name then rule_string = rule_string .. "[|cFF00FF00name|r]:" .. rule.profile_name .. "\n"  end 
	if rule.profile_path then rule_string = rule_string .. "[|cFF00FF00path|r]:" .. strjoin(", ", unpack(rule.profile_path))  .. "\n" end 
	if rule.value_set then 
		local value_set = {}
		for key,value in pairs(rule.value_set) do tinsert(value_set, key .. ":" .. (value or "nil")) end
		rule_string = rule_string .. "[|cFF00FF00value_set|r]:" ..  strjoin(", ", unpack(value_set)) .. "\n" end 
	if rule.name_rule then rule_string = rule_string .. "[|cFF00FF00name_rule|r]:" .. rule.name_rule  .. "\n" end 
	return rule_string
end

function mod:GetRule( addon_name )	
	local rule = self.rule_list[addon_name]
	if rule then return rule else return false end
end

function mod:GetParseString(str, param_dict)
	if not str then return nil end
	local str = str
	for k,v in pairs(param_dict) do str = Core:StrReplace(str, k, v) end
	return str
end



