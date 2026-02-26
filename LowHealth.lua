local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")
local nextLowHealthSoundAt = 0

local function Now()
    return (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
end

local function SafeNumber(value)
    return tonumber(value) or 0
end

local function GetPotionData(spellID)
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local _, sID = C_Item.GetItemSpell(itemID)
                if sID == spellID then
                    local count = C_Item.GetItemCount(itemID)
                    return count, C_Item.GetItemIconByID(itemID)
                end
            end
        end
    end
    return 0, nil
end

local function GetReadySpellIcon(spellID)
    local isKnown = false
    if C_Spell.IsSpellKnownOrOverridesKnown then
        isKnown = C_Spell.IsSpellKnownOrOverridesKnown(spellID)
    elseif C_Spell.IsSpellKnown then
        isKnown = C_Spell.IsSpellKnown(spellID)
    end
    if not isKnown and IsPlayerSpell then
        isKnown = IsPlayerSpell(spellID)
    end
    if not isKnown then
        return nil
    end

    local icon = C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    return icon or nil
end

local function ResolveSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellID)
        if n and n ~= "" then return n end
    end
    if GetSpellInfo then
        local n = GetSpellInfo(spellID)
        if n and n ~= "" then return n end
    end
    return nil
end

local function GetTalentRankBySpellID(talentSpellID)
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits) then
        return 0
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return 0
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        return 0
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodeIDs = C_Traits.GetTreeNodes(treeID)
        if nodeIDs then
            for _, nodeID in ipairs(nodeIDs) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.entryIDs then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        local definitionID = entryInfo and entryInfo.definitionID
                        local definitionInfo = definitionID and C_Traits.GetDefinitionInfo(definitionID)
                        if definitionInfo and definitionInfo.spellID == talentSpellID then
                            return tonumber(nodeInfo.currentRank) or 0
                        end
                    end
                end
            end
        end
    end

    return 0
end

local function GetDefaultHealingOptionsPriority()
    if LHH.HealingOptions then
        local priority = {}
        for _, option in ipairs(LHH.HealingOptions) do
            priority[#priority + 1] = option.key
        end
        return priority
    end
    return {"healthstone", "potion", "spell:109304", "spell:6789"}
end

function LHH:GetReadyHealingOptionIcon()
    local priority = self.GetHealingOptionsPriority and self:GetHealingOptionsPriority() or GetDefaultHealingOptionsPriority()

    for _, optionKey in ipairs(priority) do
        if optionKey == "healthstone" then
            local healthstoneIDs = {224464, 5512}
            for _, id in ipairs(healthstoneIDs) do
                if C_Item.GetItemCount(id, false, true) > 0 then
                    local _, duration = C_Item.GetItemCooldown(id)
                    if (duration or 0) == 0 then
                        return C_Item.GetItemIconByID(id)
                    end
                end
            end

        elseif optionKey == "potion" then
            local potCount, potIcon = GetPotionData(self.db.profile.potionSpellID)
            if potCount > 0 and self:IsOptionInternallyReady("potion") then
                return potIcon
            end

        else
            local spellID = tonumber(string.match(tostring(optionKey), "^spell:(%d+)$"))
            if spellID then
                local spellIcon = self:IsOptionInternallyReady(optionKey) and GetReadySpellIcon(spellID)
                if spellIcon then
                    return spellIcon
                end
            end
        end
    end

    return nil
end

function LHH:IsOptionInternallyReady(optionKey)
    self.internalCooldowns = self.internalCooldowns or {}
    local readyAt = self.internalCooldowns[optionKey]
    if not readyAt then
        return true
    end
    return Now() >= readyAt
end

function LHH:RegisterOptionCooldown(optionKey, durationSeconds)
    durationSeconds = tonumber(durationSeconds) or 0
    if durationSeconds <= 0 then
        return
    end
    self.internalCooldowns = self.internalCooldowns or {}
    self.internalCooldowns[optionKey] = Now() + durationSeconds
end

function LHH:ResolveOptionDuration(option)
    local fallbackSeconds = 0
    if option.key == "potion" then
        fallbackSeconds = 300
    end

    if option.fallbackCooldown then
        fallbackSeconds = tonumber(option.fallbackCooldown) or fallbackSeconds
    end

    if option.kind == "spell" and option.spellID == 109304 then
        -- Natural Mending (270581): 30s per rank (up to 2 ranks).
        local naturalMendingRank = GetTalentRankBySpellID(270581)
        if naturalMendingRank > 0 then
            fallbackSeconds = math.max(0, fallbackSeconds - (30 * naturalMendingRank))
        end
    end

    if option.kind == "spell" and option.spellID == 498 then
        -- Unbreakable Spirit (114154): Divine Protection cooldown reduced by 30%.
        local hasUnbreakableSpirit = false
        if IsPlayerSpell then
            hasUnbreakableSpirit = IsPlayerSpell(114154)
        end
        if not hasUnbreakableSpirit then
            hasUnbreakableSpirit = GetTalentRankBySpellID(114154) > 0
        end
        if hasUnbreakableSpirit then
            fallbackSeconds = fallbackSeconds * 0.7
        end
    end

    return fallbackSeconds
end

function LHH:RequestCooldownRebuild()
    if InCombatLockdown and InCombatLockdown() then
        self.cooldownRebuildPending = true
        return
    end
    self.cooldownRebuildPending = false
    self:RebuildCooldownTracking()
end

function LHH:RebuildCooldownTracking()
    self.spellToOptionKey = {}
    self.spellNameToOptionKey = {}
    self.optionCooldownDuration = self.optionCooldownDuration or {}

    if not LHH.HealingOptions then
        return
    end

    for _, option in ipairs(LHH.HealingOptions) do
        self.optionCooldownDuration[option.key] = self:ResolveOptionDuration(option)

        if option.kind == "spell" and option.spellID then
            self.spellToOptionKey[option.spellID] = option.key

            if C_Spell and C_Spell.GetOverrideSpell then
                local overrideID = tonumber(C_Spell.GetOverrideSpell(option.spellID))
                if overrideID and overrideID > 0 then
                    self.spellToOptionKey[overrideID] = option.key
                end
            end

            local optionSpellName = ResolveSpellName(option.spellID) or option.fallbackName
            if optionSpellName and optionSpellName ~= "" then
                self.spellNameToOptionKey[optionSpellName] = option.key
            end
        elseif option.key == "potion" then
            local potionSpellID = tonumber(self.db and self.db.profile and self.db.profile.potionSpellID)
            if potionSpellID then
                self.spellToOptionKey[potionSpellID] = "potion"
                local potionSpellName = ResolveSpellName(potionSpellID)
                if potionSpellName and potionSpellName ~= "" then
                    self.spellNameToOptionKey[potionSpellName] = "potion"
                end
            end
        end
    end
end

function LHH:GetOptionCooldownDuration(optionKey)
    if self.optionCooldownDuration and self.optionCooldownDuration[optionKey] then
        return tonumber(self.optionCooldownDuration[optionKey]) or 0
    end
    return 0
end

function LHH:OnPlayerSpellSucceeded(_, unit, _, spellID)
    if unit ~= "player" then
        return
    end

    spellID = tonumber(spellID)
    if not spellID then
        return
    end

    if not self.spellToOptionKey then
        self:RequestCooldownRebuild()
    end

    local castSpellName = ResolveSpellName(spellID)
    local optionKey = self.spellToOptionKey[spellID]
    if not optionKey and castSpellName then
        optionKey = self.spellNameToOptionKey[castSpellName]
    end

    if optionKey then
        local cooldownSeconds = self:GetOptionCooldownDuration(optionKey)
        if cooldownSeconds > 0 then
            self:RegisterOptionCooldown(optionKey, cooldownSeconds)
        end
        self:RefreshIcon()
    end
end

function LHH:OnSpellsChanged()
    self:RequestCooldownRebuild()
    self:RefreshIcon()
end

function LHH:OnPlayerRegenEnabled()
    if self.cooldownRebuildPending then
        self:RequestCooldownRebuild()
    end
    self:RefreshIcon()
end

function LHH:TryPlayLowHealthSound()
    local path = LSM:Fetch("sound", self.db.profile.soundName)
    if not path then return end

    local requiresOption = self.db.profile.lowHealthSoundRequiresOption
    if requiresOption and not self:GetReadyHealingOptionIcon() then
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local throttle = tonumber(self.db.profile.lowHealthSoundThrottleSeconds) or 0.2
    if throttle < 0 then throttle = 0 end

    if now >= nextLowHealthSoundAt then
        PlaySoundFile(path, "Master")
        nextLowHealthSoundAt = now + throttle
    end
end

function LHH:CreateMainFrame()
    local f = CreateFrame("Frame", "LHH_MainFrame", UIParent)
    f:SetSize(80, 80)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()

    local p = self.db.profile.pos
    f:ClearAllPoints()
    f:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    f:SetScale(self.db.profile.scale)

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if IsControlKeyDown() and IsShiftKeyDown() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        LHH.db.profile.pos = { point = point, x = x, y = y }
    end)
    self.frame = f

    -- Hook the alert specifically in the health specialist module
    if LowHealthFrame then
        LowHealthFrame:HookScript("OnShow", function()
            self:RefreshIcon()
            self.frame:Show()
            self:TryPlayLowHealthSound()
        end)
        LowHealthFrame:HookScript("OnHide", function()
            if not self.configMode then self.frame:Hide() end
        end)
    end
end

function LHH:RefreshIcon()
    if not self.frame then return end
    if self.configMode then
        self.frame.tex:SetTexture(C_Item.GetItemIconByID(5512))
        self.frame:SetAlpha(1)
        return
    end

    local readyIcon = self:GetReadyHealingOptionIcon()

    if readyIcon then
        self.frame.tex:SetTexture(readyIcon)
        self.frame:SetAlpha(1)
    else
        -- If nothing is ready, hide the frame so it doesn't bait you into clicking
        self.frame:SetAlpha(0)
    end
end

