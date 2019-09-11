-----------------------------------------------------------------------
-- RadialMark (Formerly GnomeCharmer)
-- Charm your friends with your very own raid icon tagger, the gnome way!
--
-- Combines some of the features of ezIcons and JasonTag into one tiny
-- package. Cleaned up and tuned up for your pleasure!
--
-- RADIAL
--
-- Whenever you double-click a mob or a friendly player in the game world, you'll
-- get a circle (radial menu) with all the raid target icons around the cursor.
-- If the target does not have a raid target icon, moving your mouse over any of
-- them will assign that icon to the target. If the target is marked, moving your
-- mouse over that icon will un-mark the target. Clicking with your mouse inside
-- the circle will dismiss the radial menu.

-- DIMMED ICONS
--
-- The addon also tries to keep a live list of raid target icons used (only
-- those set by yourself can be trusted, it doesn't scan targets) and dim out
-- any icons used already so that the unused ones are more prominent in the bar
-- and radial menu.
--
-- This addon was based upon GnomeCharmer by Rabbit. It has been updated to work
-- with WoW classic. Only the double-click radial menu part was ported.
--

local iconsUsed = {}

local function validate(target)
	if not UnitExists(target) then return end
	local can = true
	
	numGroupMembers = GetNumGroupMembers()
	isPlayerGroupLeader = UnitIsGroupLeader("player")
	isPlayerInRaid = IsInRaid();
	isPlayerRaidOfficer = UnitIsGroupAssistant("player")

	-- Both a player not in a group and a player in a group/raid who has permissions
	-- to set marks (leader/assistant)
	if not (numGroupMembers == 0) and (isPlayerInRaid and not isPlayerRaidOfficer) then
		can = nil
	end
	if can == nil then
		DEFAULT_CHAT_FRAME:AddMessage("can is nil")
	end
	if can and not UnitIsUnit("player", target) then
		if not UnitPlayerOrPetInParty(target) and not UnitPlayerOrPetInRaid(target) then
			if UnitIsPlayer(target) and not UnitCanCooperate("player", target) then
				can = nil
			end
		end
	end
	return can
end

local function setIcon(target, id)
	if not validate(target) then return end
	local current = GetRaidTargetIndex(target)
	if current then iconsUsed[current] = nil end
	if current and id == current then id = 0 end
	SetRaidTarget(target, id)
end

-----------------------------------------------------------------------
-- Radial menu
--
-- Most of the code is ripped from ezIcons. Thanks!
--

local radialIcons = {}
do
	local menu = nil
	local function update(self)
		local x, y = GetCursorPosition()
		local s = menu:GetEffectiveScale()
		local mx, my = menu:GetCenter()
		local a, b = (y / s) - my, (x / s) - mx
		local dist = math.floor(math.sqrt(a * a + b * b))
		if dist > 20 then
			if dist < 50 then
				local pos = math.deg(math.atan2(a, b)) + 27.5
				local iconIndex = mod(11 - ceil(pos / 45), 8) + 1
				setIcon("target", iconIndex)
			end
			self:Hide()
		end
	end
	local function hide(self)
		self:Hide()
	end

	local function createRadial()
		menu = CreateFrame("Button", "GnomeCharmerRadial", UIParent)
		menu:SetWidth(100)
		menu:SetHeight(100)
		menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
		menu:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		menu:RegisterEvent("PLAYER_TARGET_CHANGED")
		menu:SetScript("OnUpdate", update)
		menu:SetScript("OnEvent", hide)
		menu:SetScript("OnClick", hide)
		for i = 1, 8 do
			local icon = menu:CreateTexture("GnomeCharmerRadial"..i, "OVERLAY")
			local radians = (0.375 - i / 8) * 360
			icon:SetPoint("CENTER", menu, "CENTER", 36 * cos(radians), 36 * sin(radians))
			icon:SetWidth(18)
			icon:SetHeight(18)
			icon:SetAlpha(iconsUsed[i] and 0.2 or 1)
			icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			SetRaidTargetIconTexture(icon, i)

			radialIcons[i] = icon
		end
	end

	local function showRadial()
		if not validate("target") then return end
		if not menu then createRadial() end

		local x,y = GetCursorPosition()
		local s = menu:GetEffectiveScale()
		menu:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/s, y/s)
		menu:Show()
	end

	local doubleClick, doubleClickX, doubleClickY = nil, 0, 0
	local orig = WorldFrame:GetScript("OnMouseUp")
	WorldFrame:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			local time = GetTime()
			local x, y = GetCursorPosition()
			if doubleClick and time - doubleClick < 0.25 and math.abs(x - doubleClickX) < 20 and math.abs(y - doubleClickY) < 20 then
				showRadial()
				doubleClick = nil
			else
				doubleClick = time
			end
			doubleClickX, doubleClickY = x, y
		end
		if orig then orig() end
	end)
end

-----------------------------------------------------------------------
-- Keep icons dimmed when used and full when available.
--

local function updateAlpha()
	for i = 1, 8 do
		local a = iconsUsed[i] and 0.3 or 1
		if radialIcons and radialIcons[i] then radialIcons[i]:SetAlpha(a) end
		if barIcons and barIcons[i] then barIcons[i]:SetAlpha(a) end
	end
end

hooksecurefunc("SetRaidTarget", function(unit, id)
	if id > 0 and validate(unit) then
		local uid = UnitGUID(unit)
		if uid and iconsUsed[id] == uid then
			iconsUsed[id] = nil
		else
			iconsUsed[id] = uid or true
		end
	elseif id == 0 then
		local uid = UnitGUID(unit)
		if uid then
			for k, v in pairs(iconsUsed) do
				if v == uid then
					iconsUsed[k] = nil
					break
				end
			end
		end
	end
	updateAlpha()
end)

-- Mark icons used on dead mobs as available, except if it's a friendly player.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and arg1 == "GnomeCharmer" then
		if not RadialMarkDB then RadialMarkDB = {
			barShow = true,
			barAlpha = 1,
		} end
	else
		local target = "target"
		if event == "UPDATE_MOUSEOVER_UNIT" then
			target = "mouseover"
		end
		local icon = GetRaidTargetIndex(target)
		if icon then
			if UnitIsDeadOrGhost(target) and not UnitIsPlayer(target) then
				iconsUsed[icon] = nil
			else
				iconsUsed[icon] = true
			end
			updateAlpha()
		end
	end
end)
events:RegisterEvent("ADDON_LOADED")
--events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
--events:RegisterEvent("PLAYER_TARGET_CHANGED")

