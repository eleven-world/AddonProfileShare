local Core = LibStub("AceAddon-3.0"):GetAddon("AddonProfileShare")

local mod = {}
Core.Instruction = mod

local alert = [[|cFFFF0000插件仍处于早期开发测试阶段，请备份WTF文件后，谨慎使用！！！！！|r]]

local export_steps = [[1. 输入档案名称和说明
2. 选择需要导出的插件
3. 点击"导出所选插件配置"
4. 等待系统生成选定插件的字符串
5. 生成完成后，复制字符串框中字符串用于分享
6. 可选择复制插件表，用于分享说明
]]

local addon_category_instruction = [[|cffffd100已添加导出规则的插件|r：手写了导出规则的插件，一般会针对性地屏蔽战斗记录、缓存等与设置无关，但又占用很大空间的内容。
|cffffd100使用AceDB的插件|r：使用了AceDB的插件，会导出AceDB中的全局配置和当前设定档配置
|cffffd100正常可导出的插件|r：正常导出插件所有存储的配置和数据
|cffffd100无需配置的插件|r：插件没有配置选项，不需要导入导出任何内容
|cffffd100已屏蔽插件|r：在配置->插件信息库->黑名单中进行屏蔽的插件，不会导入导出任何内容
|cffffd100已安装但未启用的插件|r：禁用的插件，或者按需启用的插件暂未载入]]

local import_steps = [[1. 点击"粘贴字符串"按钮
2. 在弹出的窗口中，使用Crtl+V将字符串粘贴到窗口中
3. 点击"关闭"按钮，等待程序分析字符串内容
4. 分析完成后，如可以导入，选择字符串中需要导入的插件
5. 点击"导入所选插件"按钮
6. 等待程序按顺序将字符串中的配置导入
7. 完成后重载界面
]]

local backup_instruction = [[1. 备份与还原，仅用于同一帐号，否则可能产生未知问题
2. 黑名单与规则无效，程序会备份和还原所有能找到的插件设置
3. 备份内容默认不会被导出，除非手动修改了内置导出规则
]]

local config_instruction = [[|cFFFF0000选项配置请在阅读说明后谨慎使用|r
[规则管理]：管理插件的导入导出规则，如某插件没有规则，则优先按AceDB规则导出，其次为导出该插件所有保存内容
[插件信息库]：插件SavedVaribles信息库，包括数千插件，有信息的插件，才有可能被导入导出，否则程序无法识别
]]
















function mod:Init()
	self:InitOptions()
end

function mod:InitOptions( ... )
	self.options = {
		type = "group",
		name = "说明",
		handler = self,
		order = 1,
		args = {
			about_tab = {
				type = "group",
				name = "关于",
				order = 1,
				inline = true,
				args = {
					title = {
						type = "description",
						name = function () return "|cffffd100" .. select(2,GetAddOnInfo(Core.addon_name)) .. "|r" end,
						fontSize = "large",
						order = 1,
					},
					note = {
						type = "description",
						name = function () return select(3,GetAddOnInfo(Core.addon_name)) end,
						fontSize = "medium",
						order = 2,
					},
					author = {
						type = "description",
						name = "\n|cffffd100Author: |r" .. GetAddOnMetadata(Core.addon_name, "Author"),
						order = 3,
					},
					version = {
						type = "description",
						name = "|cffffd100Version: |r" .. GetAddOnMetadata(Core.addon_name, "Version"),
						order = 4,
					},
					alert = {
						type = "description",
						name = alert,
						order = 5,
					},
				},
			},
			export_tab = {
				type = "group",
				name = "导出字符串",
				order = 2,
				args = {
					operation = {type = "group",name = "操作步骤",inline = true,order = 1,args = { main = { type = "description",fontSize = "medium", name = export_steps}}},
					type_ins = {type = "group",name = "插件类型说明",inline = true,order = 2,args = { main = { type = "description",fontSize = "medium", name = addon_category_instruction}}},
				},
			},
			import_tab = {
				type = "group",
				name = "导入字符串",
				order = 3,
				args = {
					operation = {type = "group",name = "操作步骤",inline = true,order = 1,args = { main = { type = "description",fontSize = "medium", name = import_steps}}},
				},
			},
			backup_tab = {
				type = "group",
				name = "备份与还原",
				order = 4,
				args = {
					operation = {type = "group",name = "说明",inline = true,order = 1,args = { main = { type = "description",fontSize = "medium", name = backup_instruction}}},
				},
			},
			config_tab = {
				type = "group",
				name = "选项配置",
				order = 5,
				args = {
					operation = {type = "group",name = "说明",inline = true,order = 1,args = { main = { type = "description",fontSize = "medium", name = config_instruction}}},
				},
			},
		},
	}
	Core.options.args.config.args.instruction_tab = self.options
end




