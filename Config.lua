local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")

LHH.SoundList = {}
LHH.HealingOptions = {
    { key = "healthstone", kind = "healthstone", fallbackName = "Healthstone" },
    { key = "potion", kind = "potion", fallbackName = "Potion" },
    { key = "spell:108416", kind = "spell", spellID = 108416, fallbackName = "Dark Pact", fallbackCooldown = 60 },
    { key = "spell:185311", kind = "spell", spellID = 185311, fallbackName = "Crimson Vial", fallbackCooldown = 30 },
    { key = "spell:19236", kind = "spell", spellID = 19236, fallbackName = "Desperate Prayer", fallbackCooldown = 90 },
    { key = "spell:109304", kind = "spell", spellID = 109304, fallbackName = "Exhilaration", fallbackCooldown = 120 },
    { key = "spell:6789", kind = "spell", spellID = 6789, fallbackName = "Mortal Coil", fallbackCooldown = 45 },
}

local function RegisterAddonSound(name, path)
    LSM:Register("sound", name, path)

end

for name, path in pairs(LHH.SoundsToRegister) do
    RegisterAddonSound(name, path)
end

local function BuildDefaultHealingOptionsPriority()
    local priority = {}
    for _, option in ipairs(LHH.HealingOptions) do
        priority[#priority + 1] = option.key
    end
    return priority
end

LHH.defaults = {
    profile = {
        pos = { point = "CENTER", x = 0, y = 0 },
        scale = 1.0,
        potionSpellID = 1238009, 
        soundName = "Gasp", 
        lowHealthSoundRequiresOption = false,
        lowHealthSoundThrottleSeconds = 0.2,
        healingOptionsPriority = BuildDefaultHealingOptionsPriority(),
        deathEnabled = true,
        deathSoundThrottleSeconds = 0.5,
        deathSound = "Quest Failed",
    }
}

function LHH:GetHealingOptionDisplayName(optionKey)
    if optionKey == "healthstone" then
        return "Healthstone"
    end
    if optionKey == "potion" then
        return "Potion (Potion Spell ID)"
    end

    local spellID = optionKey and tonumber(string.match(optionKey, "^spell:(%d+)$"))
    if spellID and C_Spell and C_Spell.GetSpellName then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName and spellName ~= "" then
            return spellName
        end
    end

    for _, option in ipairs(LHH.HealingOptions) do
        if option.key == optionKey then
            return option.fallbackName
        end
    end
    return tostring(optionKey or "Unknown")
end

function LHH:GetHealingOptionsPriority()
    local validKeys = {}
    for _, option in ipairs(LHH.HealingOptions) do
        validKeys[option.key] = true
    end

    local source = self.db and self.db.profile and self.db.profile.healingOptionsPriority
    local normalized = {}
    local seen = {}

    if type(source) == "table" then
        for _, optionKey in ipairs(source) do
            optionKey = tostring(optionKey)
            if validKeys[optionKey] and not seen[optionKey] then
                normalized[#normalized + 1] = optionKey
                seen[optionKey] = true
            end
        end
    end

    for _, option in ipairs(LHH.HealingOptions) do
        if not seen[option.key] then
            normalized[#normalized + 1] = option.key
        end
    end

    return normalized
end

function LHH:SetHealingOptionsPriority(priority)
    self.db.profile.healingOptionsPriority = priority
    self:RefreshIcon()
    local aceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    if aceConfigRegistry then
        aceConfigRegistry:NotifyChange("lowHealthHelper")
    end
end

function LHH:MoveHealingOptionsPriority(index, delta)
    local priority = self:GetHealingOptionsPriority()
    local target = index + delta
    if target < 1 or target > #priority then
        return
    end

    priority[index], priority[target] = priority[target], priority[index]
    self:SetHealingOptionsPriority(priority)
end

function LHH:GetOptions()
    local healingOptionsPriorityArgs = {
        healingOptionsPriorityDesc = {
            type = "description",
            name = "Reorder all healing options to control which icon is preferred first.",
            order = 1,
            width = "full",
        },
    }

    for index = 1, #LHH.HealingOptions do
        local rowIndex = index
        local rowOrder = 10 + (index * 10)
        healingOptionsPriorityArgs["rowName" .. index] = {
            type = "description",
            name = function()
                local priority = self:GetHealingOptionsPriority()
                local optionKey = priority[rowIndex]
                return string.format("%d. %s", rowIndex, self:GetHealingOptionDisplayName(optionKey))
            end,
            width = 1.2,
            order = rowOrder,
        }
        healingOptionsPriorityArgs["rowUp" .. index] = {
            type = "execute",
            name = "Up",
            width = 0.35,
            order = rowOrder + 1,
            disabled = function() return rowIndex == 1 end,
            func = function() self:MoveHealingOptionsPriority(rowIndex, -1) end,
        }
        healingOptionsPriorityArgs["rowDown" .. index] = {
            type = "execute",
            name = "Down",
            width = 0.45,
            order = rowOrder + 2,
            disabled = function() return rowIndex == #LHH.HealingOptions end,
            func = function() self:MoveHealingOptionsPriority(rowIndex, 1) end,
        }
        healingOptionsPriorityArgs["rowBreak" .. index] = {
            type = "description",
            name = " ",
            width = "full",
            order = rowOrder + 3,
        }
    end

    return {
        type = "group",
        name = "Low Health Helper",
        args = {
            hpHeader = { type = "header", name = "Low Health Alert", order = 10 },
            preview = {
                type = "toggle",
                name = "Show Preview",
                desc = "Toggle the icon on/off to adjust its appearance.",
                order = 11,
                get = function() return self.configMode end,
                set = function(_, v) 
                    self.configMode = v
                    self:RefreshIcon()
                    if v then self.frame:Show() else self.frame:Hide() end
                end,
            },
            previewDesc = {
                type = "description",
                name = "\n|cffffee00Movement:|r Hold |cffffffffCtrl + Shift|r and drag with your |cffffffffLeft Mouse Button|r to reposition the icon.",
                order = 11.5,
                width = "full",
                fontSize = "medium",
             
            },
            scale = {
                type = "range", name = "Icon Scale", min = 0.5, max = 3.0, step = 0.05, order = 12,
                width = 1.5,
                get = function() return self.db.profile.scale end,
                set = function(_, v) self.db.profile.scale = v; self.frame:SetScale(v) end,
            },
            hpSound = {
                type = "select", 
                name = "Low Health Sound", 
                dialogControl = "LSM30_Sound",
                width = 1.5,
                values = function()
                    local list = {}
                    for name, _ in pairs(LHH.SoundsToRegister) do
                        list[name] = name
                    end
                    return list
                end, 
                order = 13,
                get = function() return self.db.profile.soundName end,
                set = function(_, v) self.db.profile.soundName = v end,
            },
            lowHealthRowBreakA = {
                type = "description",
                name = " ",
                order = 13.1,
                width = "full",
            },
            lowHealthSoundRequiresOption = {
                type = "toggle",
                name = "Only Play Sound If Healing Is Ready",
                desc = "When enabled, the low health sound only plays if a tracked healing option is currently available.",
                order = 14,
                width = 1.5,
                get = function() return self.db.profile.lowHealthSoundRequiresOption end,
                set = function(_, v) self.db.profile.lowHealthSoundRequiresOption = v end,
            },
            lowHealthSoundThrottleSeconds = {
                type = "range",
                name = "Low Health Throttle",
                desc = "Minimum time between low health sound plays.",
                order = 14.1,
                width = 1.5,
                min = 0,
                max = 2,
                step = 0.05,
                isPercent = false,
                get = function() return self.db.profile.lowHealthSoundThrottleSeconds or 0.2 end,
                set = function(_, v) self.db.profile.lowHealthSoundThrottleSeconds = v end,
            },
            lowHealthRowBreakB = {
                type = "description",
                name = " ",
                order = 14.2,
                width = "full",
            },
            potionSpellID = {
                type = "input",
                name = "Potion Spell ID",
                desc = "Enter the Spell ID of the potion you want to track (e.g., 1238009 for Invigorating Healing Potion).",
                order = 15,
                width = 1.5,
                get = function() return tostring(self.db.profile.potionSpellID) end,
                set = function(_, v) 
                    local val = tonumber(v)
                    if val then
                        self.db.profile.potionSpellID = val
                        if self.MarkPotionCacheDirty then self:MarkPotionCacheDirty() end
                        if self.RequestCooldownRebuild then self:RequestCooldownRebuild() end
                        if self.RequestRefreshIcon then self:RequestRefreshIcon() else self:RefreshIcon() end -- Update the icon immediately
                        print("|cff00ff00[LHH]|r Potion Spell ID updated to: " .. val)
                    else
                        print("|cffff0000[LHH] Error:|r Please enter a valid numerical Spell ID.")
                    end
                end,
            },
            healingOptionsPriorityGroup = {
                type = "group",
                name = "Healing Options Priority",
                inline = true,
                order = 16,
                args = healingOptionsPriorityArgs,
            },
            deathHeader = { type = "header", name = "Death Notifications", order = 20 },
            deathEnabled = {
                type = "toggle", name = "Enable Death Alerts", order = 21,
                width = 1.5,
                get = function() return self.db.profile.deathEnabled end,
                set = function(_, v) self.db.profile.deathEnabled = v end,
            },
            deathSound = {
                type = "select", 
                name = "Death Sound", 
                dialogControl = "LSM30_Sound", 
                width = 1.5,
                order = 21.1,
                get = function() return self.db.profile.deathSound end,
                set = function(_, v) self.db.profile.deathSound = v end,
                values = function()
                    local list = {}
                    for name, _ in pairs(LHH.SoundsToRegister) do
                        list[name] = name
                    end
                    return list
                end, 
            },
            deathRowBreakA = {
                type = "description",
                name = " ",
                order = 21.2,
                width = "full",
            },
            deathSoundThrottleSeconds = {
                type = "range",
                name = "Death Throttle",
                desc = "Minimum time between death sound plays.",
                order = 22,
                width = 1.5,
                min = 0,
                max = 2,
                step = 0.05,
                isPercent = false,
                get = function() return self.db.profile.deathSoundThrottleSeconds or 0.5 end,
                set = function(_, v) self.db.profile.deathSoundThrottleSeconds = v end,
            },
        }
    }
end

function LHH:OnInitialize()
    if LHH.SoundsToRegister then
        for name, path in pairs(LHH.SoundsToRegister) do
            LSM:Register("sound", name, path)
        end
    end

    self.db = LibStub("AceDB-3.0"):New("lowHealthHelperDB", self.defaults, true)
    if type(self.db.profile.healingOptionsPriority) ~= "table" and type(self.db.profile.classAbilityPriority) == "table" then
        local legacy = self.db.profile.classAbilityPriority
        local migrated = {"healthstone", "potion"}
        for _, spellID in ipairs(legacy) do
            spellID = tonumber(spellID)
            if spellID then
                migrated[#migrated + 1] = "spell:" .. tostring(spellID)
            end
        end
        self.db.profile.healingOptionsPriority = migrated
        self.db.profile.classAbilityPriority = nil
    end
    self.db.profile.healingOptionsPriority = self:GetHealingOptionsPriority()
    if self.MarkPotionCacheDirty then self:MarkPotionCacheDirty() end
    if self.RequestCooldownRebuild then self:RequestCooldownRebuild() end
    
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

    self:CreateMainFrame()
    
    self:RefreshConfig()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("lowHealthHelper", self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("lowHealthHelper", "Low Health Helper")
    
    local iconID = 538745 
    if self.optionsFrame then
        self.optionsFrame.icon = iconID 
        self.optionsFrame.logo = iconID 
    end

    self:RegisterChatCommand("lhh", function() 
        if Settings and Settings.OpenToCategory then 
            Settings.OpenToCategory(self.optionsFrame.name) 
        end 
    end)

end

function LHH:RefreshConfig()
    if not self.frame then return end
    local p = self.db.profile.pos
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    self.frame:SetScale(self.db.profile.scale) -- Ensures scale persists
end

function LHH:OnEnable()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnInventoryUpdated")
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", "RequestRefreshIcon")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "RequestRefreshIcon")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnPlayerSpellSucceeded")
    self:RegisterEvent("SPELLS_CHANGED", "OnSpellsChanged")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnSpellsChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshRoster")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshRoster")
    self:RegisterEvent("UNIT_HEALTH", "OnUnitUpdate")
    self:RegisterEvent("UNIT_FLAGS", "OnUnitUpdate")
    if self.RequestRefreshIcon then self:RequestRefreshIcon() else self:RefreshIcon() end
end
