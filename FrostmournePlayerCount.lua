local ADDON_NAME = "FrostmournePlayerCount"

------------------------------------------------------------
-- Configuration
------------------------------------------------------------
local UPDATE_INTERVAL = 300        -- 5 minutes
local RESPONSE_TIMEOUT = 10        -- seconds
local INITIAL_DELAY = 3            -- seconds


------------------------------------------------------------
-- Test window (Compact & Movable)
------------------------------------------------------------
local frame = CreateFrame("Frame", "FrostmournePlayerCount", UIParent)
frame:SetWidth(250)
frame:SetHeight(60)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

-- Enable Dragging
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)


------------------------------------------------------------
-- Output (Centered)
------------------------------------------------------------
frame.output = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.output:SetPoint("CENTER", frame, "CENTER", 0, 0)
frame.output:SetWidth(230)
frame.output:SetHeight(40)
frame.output:SetJustifyH("CENTER")
frame.output:SetJustifyV("MIDDLE")
frame.output:SetText("Waiting for first server check...")


------------------------------------------------------------
-- State Variables
------------------------------------------------------------
local waiting = false
local response = {}

local initialElapsed = 0
local updateElapsed = 0
local responseElapsed = 0
local initialized = false


------------------------------------------------------------
-- Display Logic
------------------------------------------------------------
local function DisplayResponse()
    if #response == 0 then
        frame.output:SetText("No player count data found.")
        return
    end
    frame.output:SetText(table.concat(response, "\n"))
end

local function FinishSuccess()
    waiting = false
    responseElapsed = 0
    DisplayResponse()
end

local function SendTestCommand()
    if waiting then return end
    
    response = {}
    waiting = true
    responseElapsed = 0
    
    frame.output:SetText("Fetching population...")
    
    SendChatMessage(".server info", "GUILD")
end


------------------------------------------------------------
-- Chat Filters to Hide the Spam
------------------------------------------------------------
local function SystemFilter(self, event, msg)
    local cleanMsg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    cleanMsg = string.gsub(cleanMsg, "|r", "")

    if string.find(cleanMsg, "Whitemane") or 
       string.find(cleanMsg, "Rev:") or
       string.find(cleanMsg, "Online players:") or 
       string.find(cleanMsg, "Server uptime:") or 
       string.find(cleanMsg, "Server time:") or 
       string.find(cleanMsg, "Update time diff:") then
        
        if waiting and string.find(cleanMsg, "Online players:") then
            local players, alliance, horde = string.match(cleanMsg, "Online players:%s*(%d+)%s*Alliance:%s*([%d%.]+%%)%s*Horde:%s*([%d%.]+%%)")
            
            if not players then
                players = string.match(cleanMsg, "^Online players:%s*(%d+)")
            end

            if players then
                table.insert(response, "|cffffd200Online Players:|r " .. players)
                if alliance and horde then
                    table.insert(response, "|cff0070ddAlliance:|r " .. alliance .. "   |cffc41e3aHorde:|r " .. horde)
                end
                FinishSuccess()
            end
        end
        
        return true
    end
    return false
end

local function ChatMsgFilter(self, event, msg)
    if msg == ".server info" then
        return true
    end
    return false
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", ChatMsgFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatMsgFilter)


------------------------------------------------------------
-- Slash Command
------------------------------------------------------------
SLASH_FROSTMOORNETEST1 = "/fpc"

SlashCmdList["FROSTMOURNEPC"] = function(msg)
    SendTestCommand()
end


------------------------------------------------------------
-- OnUpdate Loop
------------------------------------------------------------
frame:SetScript("OnUpdate", function(self, delta)

    if not initialized then
        initialElapsed = initialElapsed + delta
        if initialElapsed >= INITIAL_DELAY then
            initialized = true
            initialElapsed = 0
            SendTestCommand()
        end
    end

    if waiting then
        responseElapsed = responseElapsed + delta
        if responseElapsed >= RESPONSE_TIMEOUT then
            waiting = false
            responseElapsed = 0
            frame.output:SetText("|cffff0000Server timeout.|r")
        end
    end

    updateElapsed = updateElapsed + delta
    if updateElapsed >= UPDATE_INTERVAL then
        updateElapsed = 0
        if not waiting then
            SendTestCommand()
        end
    end
end)


------------------------------------------------------------
-- Initialization
------------------------------------------------------------
print("|cff00ff00[" .. ADDON_NAME .. "]|r Loaded. Use /fpc to refresh manually.")