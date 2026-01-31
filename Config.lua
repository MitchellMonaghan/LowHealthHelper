local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")

-- Register Custom Media
LSM:Register("sound", "Gasp", "Interface\\AddOns\\LowHealthHelper\\Media\\PowerAurasMedia\\Sounds\\Gasp.ogg")
LSM:Register("sound", "Quest Abandoned", 567478)

-- DEFAULTS (Moved here for better organization)
LHH.defaults = {
    profile = {
        pos = { point = "CENTER", x = 0, y = 0 },
        scale = 1.0,
        potionSpellID = 431416, 
        soundName = "Gasp", 
        deathEnabled = true,
        deathSound = "Quest Abandoned",
    }
}

function LHH:GetOptions()
    return {
        type = "group",
        name = "Low Health Helper",
        args = {
            hpHeader = { type = "header", name = "Low Health Alert", order = 10 },
            preview = {
                type = "toggle", name = "Show Preview", order = 11,
                get = function() return self.configMode end,
                set = function(_, v) self.configMode = v; self:RefreshIcon(); self.frame:SetShown(v) end,
            },
            scale = {
                type = "range", name = "Icon Scale", min = 0.5, max = 3.0, step = 0.05, order = 12,
                get = function() return self.db.profile.scale end,
                set = function(_, v) self.db.profile.scale = v; self.frame:SetScale(v) end,
            },
            hpSound = {
                type = "select", name = "Low Health Sound", dialogControl = "LSM30_Sound", values = LSM:HashTable("sound"), order = 13,
                get = function() return self.db.profile.soundName end,
                set = function(_, v) self.db.profile.soundName = v end,
            },
            deathHeader = { type = "header", name = "Death Notifications", order = 20 },
            deathEnabled = {
                type = "toggle", name = "Enable Death Alerts", order = 21,
                get = function() return self.db.profile.deathEnabled end,
                set = function(_, v) self.db.profile.deathEnabled = v end,
            },
            deathSound = {
                type = "select", name = "Death Sound", dialogControl = "LSM30_Sound", values = LSM:HashTable("sound"), order = 22,
                get = function() return self.db.profile.deathSound end,
                set = function(_, v) self.db.profile.deathSound = v end,
            },
        }
    }
end

function LHH:OnInitialize()
    -- Initialize DB using the defaults defined in this file
    self.db = LibStub("AceDB-3.0"):New("lowHealthHelperDB", self.defaults, true)
    
    self:CreateMainFrame()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("lowHealthHelper", self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("lowHealthHelper", "Low Health Helper")
    
    if self.optionsFrame then 
        self.optionsFrame.logo = C_Item.GetItemIconByID(5512) 
    end

    self:RegisterChatCommand("lhh", function() 
        if Settings and Settings.OpenToCategory then Settings.OpenToCategory(self.optionsFrame.name) end 
    end)

    if LowHealthFrame then
        LowHealthFrame:HookScript("OnShow", function()
            self:RefreshIcon(); self.frame:Show()
            local path = LSM:Fetch("sound", self.db.profile.soundName)
            if path then PlaySoundFile(path, "Master") end
        end)
        LowHealthFrame:HookScript("OnHide", function() if not self.configMode then self.frame:Hide() end end)
    end
end

function LHH:OnEnable()
    self:RegisterEvent("BAG_UPDATE", "RefreshIcon")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "RefreshIcon")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshRoster")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshRoster")
    self:RegisterEvent("UNIT_HEALTH", "OnUnitUpdate")
    self:RegisterEvent("UNIT_FLAGS", "OnUnitUpdate")
end