local addonName, ns = ...
local LHH = LibStub("AceAddon-3.0"):NewAddon("lowHealthHelper", "AceEvent-3.0", "AceConsole-3.0")
_G.LHH = LHH

function LHH_OnCompartmentClick()
    -- This opens your addon settings when the healthstone icon is clicked in the compartment
    if LHH and LHH.optionsFrame then
        Settings.OpenToCategory(LHH.optionsFrame.name)
    end
end