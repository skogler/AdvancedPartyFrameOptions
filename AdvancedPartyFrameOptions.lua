-- AdvancedPartyFrameOptions.lua
-- Hides the "Party" label and/or role icons on the party frame.

local ADDON_NAME = "AdvancedPartyFrameOptions"
local L = {
    HIDE_TITLE = "Hide Party Title",
    HIDE_TITLE_DESC = "Hides the 'Party' label above the compact party frame. (Requires /reload)",
    HIDE_ROLE_ICONS = "Hide Role Icons",
    HIDE_ROLE_ICONS_DESC = "Hides the role icons (Tank, Healer, DPS) on the party frames. (Requires /reload)",
    ALWAYS_SHOW = "Always Show Party Frame",
    ALWAYS_SHOW_DESC = "Forces the party frame to be visible even when you are not in a group.",
    STATUS_BAR_TEXTURE = "Status Bar Texture",
    STATUS_BAR_TEXTURE_DESC = "Change the texture of the health bars in the party frames.",
    SHOW_MINIMAP = "Show Minimap Button",
    SHOW_MINIMAP_DESC = "Shows a button on the minimap to quickly open these settings.",
    RELOAD_REQD = "AdvancedPartyFrameOptions: A /reload is required to fully apply or remove these changes.",
}

-- LibSharedMedia support
local LSM = LibStub("LibSharedMedia-3.0", true)
if LSM then
    LSM:Register(LSM.MediaType.STATUSBAR, "Flat", [[Interface\Buttons\WHITE8X8]])
    LSM:Register(LSM.MediaType.STATUSBAR, "Glossy", [[Interface\TargetingFrame\UI-StatusBar]])
    LSM:Register(LSM.MediaType.STATUSBAR, "Minimal", [[Interface\ChatFrame\ChatFrameBackground]])
    -- Register some common ones from AddonProfiler if available (for backwards compatibility with existing settings)
    LSM:Register(LSM.MediaType.STATUSBAR, "Mogit", [[Interface\AddOns\!!AddonProfiler\media\Mogit]])
    LSM:Register(LSM.MediaType.STATUSBAR, "Baud", [[Interface\AddOns\!!AddonProfiler\media\Baud]])
    LSM:Register(LSM.MediaType.STATUSBAR, "Steel", [[Interface\AddOns\!!AddonProfiler\media\Steel]])
    LSM:Register(LSM.MediaType.STATUSBAR, "Glaze", [[Interface\AddOns\!!AddonProfiler\media\Glaze]])
end

-- Default settings
local defaults = {
    hideTitle = true,
    hideRoleIcons = true,
    alwaysShow = false,
    statusBarTexture = "Default",
    showMinimapButton = true,
    minimapPos = 45,
}

-- Core functions
local function UpdateTitle()
    if not CompactPartyFrame or InCombatLockdown() or not AdvancedPartyFrameOptionsDB.hideTitle then return end
    local title = CompactPartyFrameTitle
    if title then title:Hide() end
    for _, child in ipairs({ CompactPartyFrame:GetRegions() }) do
        if child:GetObjectType() == "FontString" then
            local text = child:GetText()
            if text and text:lower() == "party" then child:Hide() end
        end
    end
end

local function ApplyStatusBarTexture(frame)
    if not frame or not AdvancedPartyFrameOptionsDB.statusBarTexture or AdvancedPartyFrameOptionsDB.statusBarTexture == "Default" then return end

    -- Abort immediately if it's a nameplate or another frame flagged to ignore standard requirements.
    -- This property is safe to read and reliably identifies nameplates in the Blizzard UI.
    if frame.ignoreCUFNameRequirement then return end

    -- Check unit early to skip nameplates before calling any methods
    local unit = frame.unit
    if unit and unit:find("nameplate") then return end

    local isTargetFrame = false
    if unit then
        if unit:find("^party") or unit:find("^raid") or unit == "player" then
            isTargetFrame = true
        end
    end

    -- Fallback: Check frame names if unit isn't set yet.
    -- We've already excluded nameplates above, so calling GetName is now safe.
    if not isTargetFrame then
        local name = frame.GetName and frame:GetName()
        if name and (name:find("^CompactPartyFrameMember") or name:find("^CompactRaidFrame") or name:find("^CompactRaidGroup")) then
            isTargetFrame = true
        end
    end

    -- Only proceed for Party, Raid, or Player frames
    if not isTargetFrame then return end

    -- Ensure healthBar exists and is a valid StatusBar object
    if not frame.healthBar or not frame.healthBar.GetObjectType or frame.healthBar:GetObjectType() ~= "StatusBar" then return end
    
    local texturePath
    if LSM then
        texturePath = LSM:Fetch(LSM.MediaType.STATUSBAR, AdvancedPartyFrameOptionsDB.statusBarTexture)
    end
    
    if texturePath then
        -- Apply to Health Bar
        local hTex = frame.healthBar:GetStatusBarTexture()
        if hTex then
            hTex:SetAtlas(nil)
            hTex:SetHorizTile(false)
            hTex:SetVertTile(false)
        end
        frame.healthBar:SetStatusBarTexture(texturePath)
        
        -- Apply to Power Bar
        if frame.powerBar and frame.powerBar.GetObjectType and frame.powerBar:GetObjectType() == "StatusBar" then
            local pTex = frame.powerBar:GetStatusBarTexture()
            if pTex then
                pTex:SetAtlas(nil)
                pTex:SetHorizTile(false)
                pTex:SetVertTile(false)
            end
            frame.powerBar:SetStatusBarTexture(texturePath)
        end
    end
end

local function UpdateAll()
    if InCombatLockdown() then return end
    
    if AdvancedPartyFrameOptionsDB.hideTitle then UpdateTitle() end
    
    if AdvancedPartyFrameOptionsDB.hideRoleIcons then
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember"..i]
            if frame and frame.roleIcon then frame.roleIcon:Hide() end
        end
    end

    -- Always Show Logic (Safe method)
    if AdvancedPartyFrameOptionsDB.alwaysShow and not IsInGroup() and CompactPartyFrame then
        CompactPartyFrame:Show()
        if CompactPartyFrameMember1 then
            CompactPartyFrameMember1:Show()
            ApplyStatusBarTexture(CompactPartyFrameMember1)
        end
    end
    
    -- Iterate through potential compact unit frames
    for i = 1, 40 do
        local frames = {
            _G["CompactRaidFrame"..i],
            _G["CompactPartyFrameMember"..i],
            _G["CompactRaidGroup1Member"..i],
            _G["CompactRaidGroup2Member"..i],
            _G["CompactRaidGroup3Member"..i],
            _G["CompactRaidGroup4Member"..i],
            _G["CompactRaidGroup5Member"..i],
            _G["CompactRaidGroup6Member"..i],
            _G["CompactRaidGroup7Member"..i],
            _G["CompactRaidGroup8Member"..i],
        }
        for _, frame in pairs(frames) do
            if frame and frame.healthBar then
                ApplyStatusBarTexture(frame)
            end
        end
    end
end

-- Options Interface
local function SetupOptions()
    local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)
    
    local function OnSettingChanged()
        UpdateAll()
        print("|cffff0000" .. L.RELOAD_REQD .. "|r")
    end

    -- Visual Toggles
    local hideTitle = Settings.RegisterAddOnSetting(category, "hideTitle", "hideTitle", AdvancedPartyFrameOptionsDB, Settings.VarType.Boolean, L.HIDE_TITLE, defaults.hideTitle)
    Settings.CreateCheckbox(category, hideTitle, L.HIDE_TITLE_DESC)
    hideTitle:SetValueChangedCallback(OnSettingChanged)

    local hideIcons = Settings.RegisterAddOnSetting(category, "hideRoleIcons", "hideRoleIcons", AdvancedPartyFrameOptionsDB, Settings.VarType.Boolean, L.HIDE_ROLE_ICONS, defaults.hideRoleIcons)
    Settings.CreateCheckbox(category, hideIcons, L.HIDE_ROLE_ICONS_DESC)
    hideIcons:SetValueChangedCallback(OnSettingChanged)

    local alwaysShow = Settings.RegisterAddOnSetting(category, "alwaysShow", "alwaysShow", AdvancedPartyFrameOptionsDB, Settings.VarType.Boolean, L.ALWAYS_SHOW, defaults.alwaysShow)
    Settings.CreateCheckbox(category, alwaysShow, L.ALWAYS_SHOW_DESC)
    alwaysShow:SetValueChangedCallback(UpdateAll)

    -- Dropdowns
    local function GetTextureOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("Default", "Default")
        
        if LSM then
            local statusbars = LSM:List(LSM.MediaType.STATUSBAR)
            local preferred = {
                "Flat",
                "Blizzard Raid Bar",
                "Glamour",
                "Minimal",
                "Platy: Bevelled",
                "Platy: Solid",
                "Healbot"
            }
            
            for _, k in ipairs(statusbars) do
                if k ~= "Default" then
                    local match = false
                    local nameLower = k:lower()
                    for _, p in ipairs(preferred) do
                        if nameLower:find(p:lower(), 1, true) then
                            match = true
                            break
                        end
                    end
                    
                    if match then
                        local path = LSM:Fetch(LSM.MediaType.STATUSBAR, k)
                        local label = k
                        if path then
                            label = "|T" .. path .. ":12:60:0:0:1:1:0:1:0:1|t " .. k
                        end
                        container:Add(k, label)
                    end
                end
            end
        end
        
        return container:GetData()
    end
    local texture = Settings.RegisterAddOnSetting(category, "statusBarTexture", "statusBarTexture", AdvancedPartyFrameOptionsDB, Settings.VarType.String, L.STATUS_BAR_TEXTURE, defaults.statusBarTexture)
    Settings.CreateDropdown(category, texture, GetTextureOptions, L.STATUS_BAR_TEXTURE_DESC)
    texture:SetValueChangedCallback(UpdateAll)

    -- Minimap
    local minimap = Settings.RegisterAddOnSetting(category, "showMinimapButton", "showMinimapButton", AdvancedPartyFrameOptionsDB, Settings.VarType.Boolean, L.SHOW_MINIMAP, defaults.showMinimapButton)
    Settings.CreateCheckbox(category, minimap, L.SHOW_MINIMAP_DESC)
    minimap:SetValueChangedCallback(function() if AdvancedPartyFrameOptions.UpdateMinimapButton then AdvancedPartyFrameOptions.UpdateMinimapButton() end end)

    Settings.RegisterAddOnCategory(category)
    AdvancedPartyFrameOptions.categoryID = category:GetID()
end

-- Minimap Button
local function CreateMinimapButton()
    local btn = CreateFrame("Button", "AdvancedPartyFrameOptionsMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetToplevel(true)
    btn:SetMovable(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface/Minimap/UI-Minimap-Background")
    background:SetPoint("CENTER", 0, 0)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface/Icons/Achievement_GuildPerk_EverybodysFriend")
    icon:SetPoint("CENTER", 0, 0)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)
    btn:SetScript("OnClick", function() Settings.OpenToCategory(AdvancedPartyFrameOptions.categoryID) end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ADDON_NAME)
        GameTooltip:AddLine("Click to open settings", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    local function UpdatePosition()
        local angle = math.rad(AdvancedPartyFrameOptionsDB.minimapPos or 45)
        -- Standard minimap radius is roughly width/2. Adding a small offset (e.g., 5-10) 
        -- ensures it stays on the border.
        local radius = (Minimap:GetWidth() / 2) + 5
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
        btn:SetShown(AdvancedPartyFrameOptionsDB.showMinimapButton)
    end
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            
            -- Convert cursor to the same coordinate space as Minimap center
            cx, cy = cx / scale, cy / scale
            
            local angle = math.atan2(cy - my, cx - mx)
            AdvancedPartyFrameOptionsDB.minimapPos = math.deg(angle)
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    AdvancedPartyFrameOptions.UpdateMinimapButton = UpdatePosition
    UpdatePosition()
end

-- Event handling
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local function HookUpdateVisibility()
    if CompactPartyFrame and not CompactPartyFrame.APFOHooked then
        hooksecurefunc(CompactPartyFrame, "UpdateVisibility", function(self)
            if AdvancedPartyFrameOptionsDB.alwaysShow and not IsInGroup() and not InCombatLockdown() then
                self:Show()
                if CompactPartyFrameMember1 then
                    CompactPartyFrameMember1:Show()
                end
            end
        end)
        CompactPartyFrame.APFOHooked = true
    end
end

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not AdvancedPartyFrameOptionsDB then AdvancedPartyFrameOptionsDB = {} end
        for k, v in pairs(defaults) do if AdvancedPartyFrameOptionsDB[k] == nil then AdvancedPartyFrameOptionsDB[k] = v end end
        SetupOptions()
    elseif event == "PLAYER_LOGIN" then
        if AdvancedPartyFrameOptionsDB.hideRoleIcons then hooksecurefunc("CompactUnitFrame_UpdateRoleIcon", function(f) if f.roleIcon then f.roleIcon:Hide() end end) end
        if AdvancedPartyFrameOptionsDB.hideTitle and CompactPartyFrame then hooksecurefunc(CompactPartyFrame, "Show", UpdateTitle) end
        
        hooksecurefunc("CompactUnitFrame_SetUpFrame", ApplyStatusBarTexture)
        hooksecurefunc("CompactUnitFrame_UpdateHealth", ApplyStatusBarTexture)
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ApplyStatusBarTexture)
        hooksecurefunc("CompactUnitFrame_UpdatePower", ApplyStatusBarTexture)
        
        HookUpdateVisibility()
        UpdateAll()
        CreateMinimapButton()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        HookUpdateVisibility()
        UpdateAll()
    end
end)

_G.AdvancedPartyFrameOptions = { UpdateAll = UpdateAll }
