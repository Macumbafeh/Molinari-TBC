local AddOnName = "Molinari"
local MILLING, PROSPECTING, DISENCHANTING, LOCKPICKING

local Molinari = CreateFrame('Button', AddOnName, UIParent, 'SecureActionButtonTemplate')
Molinari:SetScript('OnEvent', function(self, event, ...) self[event](self, ...) end)

local Shine = CreateFrame("Model", AddOnName.."Shine", Molinari)
Shine:SetPoint("TOPLEFT", Molinari, "TOPLEFT", 0.5, 1);
Shine:SetPoint("BOTTOMRIGHT", Molinari, "BOTTOMRIGHT", -0.5, 1.5);
Shine:SetModel("Interface\\Buttons\\UI-AutoCastButton.mdx");
Shine:SetScale(1.2)
Shine:SetSequence(0);
Shine:SetSequenceTime(0, 0);

local scripts = {'OnClick', 'OnMouseUp', 'OnMouseDown'}
function Molinari:OnClick(button, ...)
	if(button ~= 'LeftButton') then
		local _, parent = self:GetPoint()
		if(parent) then
			for _, script in next, scripts do
				local handler = parent:GetScript(script)
				if(handler) then
					handler(parent, button, ...)
				end
			end
		end
	end
end

local function IsSpellKnown(spellID, isPet)
	if not spellID then return end
	local _, offs, numspells;
	local max = 0;
	local bt = isPet and BOOKTYPE_PET or BOOKTYPE_SPELL
	for i = MAX_SKILLLINE_TABS, 1, -1 do
		_, _, offs, numspells = GetSpellTabInfo(i)

		if numspells > 0 then
			max = offs + numspells
			break
		end
	end

	for spellBookID = 1, max do
		local spellName, rank = GetSpellName(spellBookID, bt)
		if spellName and (rank == "" or rank:match("%d+")) then
			local link = GetSpellLink(spellName, rank)
			local ID = tonumber(link and link:gsub("|", "||"):match("spell:(%d+)"))
			if spellID == ID then return true end
		end
	end
	return false
end

function Molinari:Apply(itemLink, spell, r, g, b)
	local parent = GetMouseFocus()
	local slot = parent:GetID()
	local bag = parent:GetParent():GetID()
	if(not bag or bag < 0) then return end

	if(GetTradeTargetItemLink(7) == itemLink) then
		if(type(spell) == 'number') then
			return
		else
			self:SetAttribute('alt-type1', 'macro')
			self:SetAttribute('macrotext', string.format('/cast %s\n/run ClickTargetTradeButton(7)', spell))
		end
	elseif(GetContainerItemLink(bag, slot) == itemLink) then
		if(type(spell) == 'number') then
			self:SetAttribute('alt-type1', 'item')
			self:SetAttribute('item', GetItemInfo(spell))
		else
			self:SetAttribute('alt-type1', 'spell')
			self:SetAttribute('spell', spell)
		end

		self:SetAttribute('target-bag', bag)
		self:SetAttribute('target-slot', slot)
	else
		return
	end

	self:SetAttribute('_entered', true)
	self:SetAllPoints(parent)
	self:Show()
	Shine:Show()
end

local LibProcessable = LibStub('LibProcessable')
function Molinari:OnTooltipSetItem()
if (not IsAltKeyDown()) then return end

	if (not IsSpellKnown(1804)) -- Lockpicking
		or (not IsSpellKnown(2018)) -- Blacksmithing
		or (not IsSpellKnown(13262)) -- Disenchanting
		or (not IsSpellKnown(31252)) then -- Prospecting
		return
	end

	local _, itemLink = self:GetItem()
	if(not itemLink) then return end
	if (InCombatLockdown()) then return end
	if(AuctionFrame and AuctionFrame:IsVisible()) then return end

	local itemID = tonumber(string.match(itemLink, 'item:(%d+):'))
	if(LibProcessable:IsProspectable(itemID) and GetItemCount(itemID) >= 5) then
		Molinari:Apply(itemLink, PROSPECTING, 1, 1/3, 1/3)
	elseif(LibProcessable:IsDisenchantable(itemID)) then
		Molinari:Apply(itemLink, DISENCHANTING, 1/2, 1/2, 1)
	else
		local openable, keyID = LibProcessable:IsOpenable(itemID)
		if(openable) then
			if(keyID) then
				Molinari:Apply(itemLink, keyID, 0, 1, 1)
			else
				Molinari:Apply(itemLink, LOCKPICKING, 0, 1, 1)
			end
		end
	end
end

function Molinari:MODIFIER_STATE_CHANGED(key)
	if(not self:IsShown() and not key and key ~= 'LALT' and key ~= 'RALT') then return end

	if(InCombatLockdown()) then
		self:SetAlpha(0)
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		self:ClearAllPoints()
		self:SetAlpha(1)
		self:Hide()
		Shine:Hide()
	end
end

function Shine:MODIFIER_STATE_CHANGED(key)
	if(not self:IsShown() and not key and key ~= 'LALT' and key ~= 'RALT') then return end

	if(InCombatLockdown()) then
		self:SetAlpha(0)
		self:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		self:ClearAllPoints()
		self:SetAlpha(1)
		self:Hide()
		Shine:Hide()
	end
end

function Molinari:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent('PLAYER_REGEN_ENABLED')
	self:MODIFIER_STATE_CHANGED()
end

function Shine:PLAYER_REGEN_ENABLED()
	self:UnregisterEvent('PLAYER_REGEN_ENABLED')
	self:MODIFIER_STATE_CHANGED()
end

Molinari:RegisterEvent('PLAYER_LOGIN')
Molinari:SetScript('OnEvent', function(self)
	LOCKPICKING = GetSpellInfo(1804)
	DISENCHANTING = GetSpellInfo(13262)
	PROSPECTING = GetSpellInfo(31252)

	GameTooltip:HookScript('OnTooltipSetItem', self.OnTooltipSetItem)

	self:SetScript('OnLeave', self.MODIFIER_STATE_CHANGED)
	Shine:SetScript('OnLeave', self.MODIFIER_STATE_CHANGED)

	self:RegisterEvent('MODIFIER_STATE_CHANGED')
	self:Hide()
	Shine:Hide()
	self:RegisterForClicks('AnyUp')
	self:SetFrameStrata('TOOLTIP')
	self:HookScript('OnClick', self.OnClick)
end)