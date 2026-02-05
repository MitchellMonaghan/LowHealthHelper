local LHH = _G.LHH
local LSM = LibStub("LibSharedMedia-3.0")
local deadCache = {}

function LHH:RefreshRoster()
    wipe(deadCache)
    if IsInGroup() then
        local prefix = IsInRaid() and "raid" or "party"
        local num = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
        for i = 1, num do
            local unit = prefix .. i
            deadCache[unit] = UnitIsDeadOrGhost(unit)
        end
    end
end

function LHH:OnUnitUpdate(event, unit)
    if not self.db or not self.db.profile.deathEnabled then return end
    if not unit then return end
    
    if not (unit:match("^raid%d+$") or unit:match("^party%d+$")) then return end

    local isDead = UnitIsDeadOrGhost(unit)
    local wasDead = deadCache[unit]

    if wasDead == nil then
        deadCache[unit] = isDead
        return
    end

    if not wasDead and isDead then
        local name = UnitName(unit) or "Someone"
        local soundPath = LSM:Fetch("sound", self.db.profile.deathSound)
        
        if self.db.profile.deathEnabled and soundPath then 
            PlaySoundFile(soundPath, "Master") 
            self:Print("|cffff0000" .. name .. " died!|r")
        end
    end
    deadCache[unit] = isDead
end