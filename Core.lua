local AddonProfileShare = LibStub("AceAddon-3.0"):NewAddon("AddonProfileShare")
--APS = AddonProfileShare
local Core = AddonProfileShare

Core.addon_name = "AddonProfileShare"
Core.compatible = GetAddOnMetadata(Core.addon_name, "X-Compatible")
Core.version = GetAddOnMetadata(Core.addon_name, "Version")
Core.player_name = UnitName("player")
Core.player_server = GetRealmName()


local AceSerializer = LibStub:GetLibrary("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local _,i,j,k,v


Core.db_defaults = {}

function Core:OnInitialize()
	self.loading = true
	self:CoreInit()
	self:ModInit()
	self:OptionsInit()
	self:ProcessQuene_Init()
	self.loading = false
end


function Core:CoreInit()
	self.db = LibStub("AceDB-3.0"):New("AddonProfileShare_DB",self.db_defaults,"default")
	self:InitializeOptions()
end


function Core:ModInit()
	self.AddonDB:Init()
	self.Rule:Init()
	self.Import:Init()
	self.Export:Init()
	self.Backup:Init()
	self.Instruction:Init()
end



function Core:OptionsInit()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(self.addon_name, self.options)
	LibStub("AceConfig-3.0"):RegisterOptionsTable(self.addon_name.."BlizOptions", self.bliz_options)
	AceConfigDialog:AddToBlizOptions(self.addon_name.."BlizOptions", self.addon_name)
	LibStub("AceConsole-3.0"):RegisterChatCommand("aps", function() AceConfigDialog:Open(self.addon_name) end)
	AceConfigDialog:SetDefaultSize(self.addon_name, 858, 660)
end

function Core:InitializeOptions()
	self.bliz_options = {
	    name = self.addon_name,
	    handler = AddonProfileShare,
	    type = 'group',
	    args = {
	    	open = {
				type = "execute",
				name = "打开配置",
				func = function() 
						HideUIPanel(InterfaceOptionsFrame)
						HideUIPanel(GameMenuFrame)
						AceConfigDialog:Open(self.addon_name) 
					end,
	    	},
	    },
	}
	self.options = {
	    name = self.addon_name,
	    handler = self,
	    type = 'group',
	    childGroups = "tab",
	    args = {
	    	config = {
	    		type = 'group',
	    		name = "配置",
	    		args = {},
	    	},
	    },
	}
end

function Core:RefreshDialog()
	AceConfigRegistry:NotifyChange(self.addon_name)
end

--LibStub("AceConfigDialog-3.0").OpenFrames["AddonProfileShare"]
function Core:SetStatusText(text)
	local f = AceConfigDialog.OpenFrames[self.addon_name]
	if not f then return nil end
	f:SetStatusText(text)
end

function Core:DataToString(data)
	local data_string = AceSerializer:Serialize(data)
	local compressed_string = LibDeflate:CompressDeflate(data_string)
	local encode_string = LibDeflate:EncodeForPrint(compressed_string)
	return encode_string
end

function Core:StringToData(profile_string)
	local decode_string = LibDeflate:DecodeForPrint(profile_string)
	if not decode_string then return nil end
    local decompressed_string = LibDeflate:DecompressDeflate(decode_string)
	if not decompressed_string then return nil end
	local success,addon_data =  AceSerializer:Deserialize(decompressed_string)
	if success and type(addon_data) == "table" then 
		return addon_data
	end
	return nil
end


function Core:ProcessQuene_Init()
	self.process_quene = {}
	self.next_process_time = GetTime()
	local process_quene_frame = self.process_quene_frame or CreateFrame("Frame")
	process_quene_frame:SetScript("OnUpdate", function() self:ProcessQuene_Process() end)
end

function Core:ProcessQuene_Process()
	if #self.process_quene == 0 then return nil	end
	if GetTime() < self.next_process_time then return nil end
	local process = self.process_quene[#self.process_quene]
	tremove(self.process_quene)
	local sleep_time,mod,process_func,args = unpack(process)
	local success, res1, res2 = pcall(mod[process_func],mod,unpack(args))
	-- if success then
	-- 	print(process_func .. --[[(select(4,unpack(process)) or "") ..]] "success!")
	-- 	--print(unpack(args))
	-- else
	-- 	print(process_func .. --[[(select(4,unpack(process)) or "") ..]]"failed!")
	-- 	print(res1, res2)
	-- 	--print(unpack(args))
	-- end
	self:ProcessQuene_Sleep(sleep_time)
end

function Core:ProcessQuene_Sleep(interval)
	self.next_process_time = GetTime() + interval
end


function Core:ProcessQuene_Add(sleep_time,mod,process_func,...)
	tinsert(self.process_quene,1,{sleep_time,mod,process_func,{...}})
end

--
function Core:ProcessQuene_IsBusy()
	if #self.process_quene > 0 then return true else return false end
end



function Core:BulkPasteWindow(paste_mod,paste_target,close_callback,title,status)
	if not paste_mod and paste_target then return end
	--local close_callback = paste_mod[close_callback]() or function() end
	local frame = AceGUI:Create("Frame")
	frame:SetTitle(title or "大量粘贴窗口")
	frame:SetStatusText(status or '请在上方粘贴字符串，然后点击"关闭"-->')
	frame:SetWidth(600)
	frame:SetHeight(200)
	frame:SetCallback("OnClose", function(widget) if close_callback then pcall(paste_mod[close_callback],paste_mod) end  AceGUI:Release(widget) end)
	frame:SetLayout("Flow")

	--code from WeakAuras
	local input = AceGUI:Create("MultiLineEditBox");
	input:SetRelativeWidth(1);
	input:SetFullHeight(true)
	input.button:Hide();
	input.frame:SetClipsChildren(true);
	frame:AddChild(input);

	local textBuffer, i, lastPaste = {}, 0, 0
	local function clearBuffer(self)
		self:SetScript('OnUpdate', nil)
		local pasted = strtrim(table.concat(textBuffer))
		input.editBox:ClearFocus();
		pasted = pasted:match( "^%s*(.-)%s*$" );
		if (#pasted > 20) then
			paste_mod[paste_target] = pasted
			-- WeakAuras.Import(pasted);
			-- input:SetLabel(L["Processed %i chars"]:format(i));
			input.editBox:SetMaxBytes(2500);
			input.editBox:SetText(strsub(pasted, 1, 2500));
		end
	end

	input.editBox:SetScript('OnChar', function(self, c)
		if lastPaste ~= GetTime() then
		  textBuffer, i, lastPaste = {}, 0, GetTime()
		  self:SetScript('OnUpdate', clearBuffer)
		end
		i = i + 1
		textBuffer[i] = c
	end)

	input.editBox:SetText("");
	input.editBox:SetMaxBytes(2500);
	--input.editBox:SetScript("OnEscapePressed", function() group:Close(); end);
	input.editBox:SetScript("OnMouseUp", nil);
	input:SetLabel("请在下方粘贴内容");
	input:SetFocus();
end



function Core:deepCopy(orig)
	local function copy3(obj, seen)
		-- Handle non-tables and previously-seen tables.
		if type(obj) ~= 'table' then 
			if type(obj) == "function" or type(obj) == "userdata" then
				return nil
			else
				return obj
			end
			--return obj
		end
		if seen and seen[obj] then 
			return nil
			--return seen[obj]
		end

		-- New table; mark it as seen an copy recursively.
		local s = seen or {}
		local res = {}
		s[obj] = res
		for k, v in next, obj do res[copy3(k, s)] = copy3(v, s) end
		return setmetatable(res, getmetatable(obj))
	end
	return copy3(orig)
end


function Core:tableMerge(t1, t2)
	local function tableMerge(t1, t2)
		if type(t2) == "table" then
		    for k,v in pairs(t2) do
		        if type(v) == "table" then
		            if type(t1[k] or false) == "table" then
		                tableMerge(t1[k] or {}, t2[k] or {})
		            else
		                t1[k] = v
		            end
		        else
		            t1[k] = v
		        end
		    end
		end
	    return t1
	end
    return tableMerge(t1, t2)
end


function Core:StrReplace(text, old, new)
	local function StrReplace(text, old, new)
		local b,e = text:find(old,1,true)
		if b==nil then
			return text
		else
			return StrReplace(text:sub(1,b-1) .. new .. text:sub(e+1), old, new)
		end
	end
	return StrReplace(text, old, new)
end