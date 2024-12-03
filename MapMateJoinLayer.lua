-- Importation des dépendances globales nécessaires
local menuFrame -- Référence globale pour le menu contextuel
local INVITE_PREFIX = "MapMateInvite"

local function SendMessageToLayer(layerNumber, message)
    -- Fonction pour envoyer un message à un joueur
    local function SendMessageToPlayer(playerName, message)
        C_ChatInfo.SendAddonMessage(INVITE_PREFIX, message, "WHISPER", playerName)
    end

    -- Fonction pour attendre une réponse
    local function WaitForResponse(playerName, onResponse)
        local responded = false
        local frame = CreateFrame("Frame")
        local timeout = GetTime() + 5 -- Timeout après 5 secondes

        frame:RegisterEvent("CHAT_MSG_ADDON")
        frame:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
            local simpleName = Ambiguate(sender, "short")
            if prefix == INVITE_PREFIX and simpleName == playerName then
                responded = true
                frame:UnregisterEvent("CHAT_MSG_ADDON")
                frame:SetScript("OnEvent", nil)
            
                if text == "OK" then
                    -- Accepter le groupe
                    AcceptGroup()
            
                    -- Assurez-vous que la popup est masquée
                    C_Timer.After(0.5, function()
                        StaticPopup_Hide("PARTY_INVITE")
                    end)
                    
                elseif text == "NO" then
                    print(playerName .. " has not activate this option.")
                elseif text == "NOCHIEF" then
                    print(playerName .. " is not the party leader.")
                end
            
                onResponse(true) -- Réponse reçue
            end
            
        end)

        C_Timer.After(5, function()
            if not responded then
                print(playerName .. " did not respond in time.")
                frame:UnregisterEvent("CHAT_MSG_ADDON")
                frame:SetScript("OnEvent", nil)
                onResponse(false) -- Timeout
            end
        end)
    end

    -- Fonction pour gérer la logique principale
    local function ProcessNextPlayer(players, index)
        if index > #players then
            print("Finished sending messages.")
            return
        end

        local player = players[index]
        print("Sending message to " .. player.name)

        SendMessageToPlayer(player.name, message)

        WaitForResponse(player.name, function(success)
            if success then
                print(player.name .. " handled message.")
            else
                print(player.name .. " did not respond.")
            end

            -- Passer au joueur suivant après une petite pause
            C_Timer.After(1, function()
                ProcessNextPlayer(players, index + 1)
            end)
        end)
    end

    -- Filtrer les joueurs dans le layer donné
    local players = {}
    for _, player in pairs(MapMatePlayerList) do
        if player.layer == layerNumber then
            table.insert(players, player)
        end
    end

    -- Lancer le processus pour le premier joueur
    if #players > 0 then
        ProcessNextPlayer(players, 1)
    else
        print("No players found on layer " .. layerNumber)
    end
end

-- Fonction pour afficher un menu contextuel personnalisé
local function ClearMenuChildren(menuFrame)
    -- Parcourt tous les enfants du cadre et les supprime
    for _, child in ipairs({menuFrame:GetChildren()}) do
        child:Hide() -- Masque l'enfant
        child:SetParent(nil) -- Supprime le parent
    end
end

local function UpdateMenuContent(menuFrame)
    -- Supprime tout le contenu existant
    ClearMenuChildren(menuFrame)

    -- Recrée le contenu du menu
    local offsetY = -10

    -- Ajouter le bouton avec checkbox pour Auto Invite
    local autoInviteButton = CreateFrame("Frame", nil, menuFrame, "BackdropTemplate")
    autoInviteButton:SetSize(140, 20)
    autoInviteButton:SetPoint("TOP", menuFrame, "TOP", 0, offsetY)
    local label = autoInviteButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", autoInviteButton, "LEFT", 25, 0)
    label:SetText("   Auto Layer Inv")

    local checkbox = CreateFrame("CheckButton", nil, autoInviteButton, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", autoInviteButton, "LEFT", 5, 0)
    checkbox:SetChecked(MapMateDB.autoInviteForLayer)
    checkbox:SetScript("OnClick", function(self)
        MapMateDB.autoInviteForLayer = self:GetChecked()
        print(MapMateDB.autoInviteForLayer and "Auto Invite enabled" or "Auto Invite disabled")
    end)

    -- Générer des boutons pour chaque layer unique (non nul)
    local uniqueLayers = {}
    for _, player in pairs(MapMatePlayerList) do
        if player.layer ~= 0 and not uniqueLayers[player.layer] then
            uniqueLayers[player.layer] = true
        end
    end

    for layer, _ in pairs(uniqueLayers) do
        offsetY = offsetY - 25
        local layerButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
        layerButton:SetSize(140, 20)
        layerButton:SetPoint("TOP", menuFrame, "TOP", 0, offsetY)
        layerButton:SetText("Join Layer " .. layer)
        layerButton:SetScript("OnClick", function()
            SendMessageToLayer(layer, "MapMateInvite")
        end)
    end

    -- Ajouter le bouton Cancel
    offsetY = offsetY - 25
    local cancelButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(140, 20)
    cancelButton:SetPoint("TOP", menuFrame, "TOP", 0, offsetY)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        menuFrame:Hide()
    end)

    -- Ajuster la hauteur du menu
    local totalHeight = math.abs(offsetY) + 30
    menuFrame:SetHeight(totalHeight)
end

local function ShowCustomContextMenu(anchor)
    if menuFrame and menuFrame:IsShown() then
        menuFrame:Hide()
        return
    end

    -- Crée le cadre pour le menu s'il n'existe pas
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "MapMateContextMenu", UIParent, "BackdropTemplate")
        menuFrame:SetSize(150, 120)
        menuFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        menuFrame:SetBackdropColor(0, 0, 0, 1)
        menuFrame:SetFrameStrata("DIALOG")
        menuFrame:SetFrameLevel(99)
    end

    -- Mettre à jour le contenu
    UpdateMenuContent(menuFrame)

    -- Positionner et afficher le menu
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, -10)
    menuFrame:Show()
end

local function Clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

-- Fonction pour créer le bouton principal sur la carte
local function CreateMapButton()
    local mapButton = CreateFrame("Button", "MapMateMapButton", WorldMapFrame.ScrollContainer, "BackdropTemplate")
    mapButton:SetSize(40, 40)
    mapButton:SetFrameStrata("HIGH")
    mapButton:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)

    -- Charger la position enregistrée ou définir une position par défaut
    local defaultX, defaultY = -10, 20
    local savedX = MapMateDB.buttonPositionX or defaultX
    local savedY = MapMateDB.buttonPositionY or defaultY
    mapButton:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", savedX, savedY)

    -- Texture principale du bouton
    local buttonTexture = mapButton:CreateTexture(nil, "BACKGROUND")
    buttonTexture:SetAllPoints()
    buttonTexture:SetVertexColor(1, 1, 1, 1)
    buttonTexture:SetTexture("Interface\\Icons\\INV_Misc_Map02")
    mapButton.texture = buttonTexture

    -- Ajouter une texture par-dessus le bouton
    local overlayTexture = mapButton:CreateTexture(nil, "OVERLAY")
    overlayTexture:SetSize(40, 40)
    overlayTexture:SetPoint("CENTER", mapButton, "CENTER", 0, 0)
    overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\forbidden")
    overlayTexture:SetAlpha(1)

    mapButton:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    mapButton:SetBackdropColor(0, 0, 0, 1)

    -- Fonction pour mettre à jour l'état du bouton
    local function UpdateButtonState()
        if MapMateDB.showPlayersOnMap then
            overlayTexture:Hide()
        else
            overlayTexture:Show()
        end
    end

    -- Activer le déplacement avec Shift
    local isBeingDragged = false
    mapButton:SetMovable(true)
    mapButton:EnableMouse(true)
    mapButton:RegisterForDrag("LeftButton")

    mapButton:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
            isBeingDragged = true
        end
    end)
    
    mapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    
        local relativeX = self:GetLeft() - WorldMapFrame.ScrollContainer:GetLeft()
        local relativeY = self:GetBottom() - WorldMapFrame.ScrollContainer:GetBottom()
    
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", relativeX, relativeY)
    
        MapMateDB.buttonPositionX = relativeX
        MapMateDB.buttonPositionY = relativeY
    
        print("Button moved to: ", relativeX, relativeY)
    end)

    -- Synchroniser la position avec la carte uniquement si le bouton n'est pas en train d'être déplacé
    local function UpdateButtonPosition()
        if not isBeingDragged then
            local savedX = MapMateDB.buttonPositionX or defaultX
            local savedY = MapMateDB.buttonPositionY or defaultY
            mapButton:ClearAllPoints()
            mapButton:SetPoint("BOTTOMLEFT", WorldMapFrame.ScrollContainer, "BOTTOMLEFT", savedX, savedY)
        end
    end

    -- Attacher l'événement de mise à jour à la carte
    WorldMapFrame.ScrollContainer:HookScript("OnUpdate", UpdateButtonPosition)

    -- Ajouter les clics gauche et droit
    mapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mapButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            MapMateDB.showPlayersOnMap = not MapMateDB.showPlayersOnMap
            UpdateButtonState()
            print(MapMateDB.showPlayersOnMap and "Players shown on the map" or "Players hidden from the map")
        elseif button == "RightButton" then
            ShowCustomContextMenu(mapButton)
        end
    end)

    -- Tooltip pour le bouton
    mapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("MapMate Map Button", 1, 1, 1)
        GameTooltip:AddLine("Left Click: Toggle player visibility", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right Click: Show options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift + Drag: Move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    mapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Mettre à jour l'état initial du bouton
    UpdateButtonState()
end




-- Masque le menu lorsque la carte est fermée
WorldMapFrame:HookScript("OnHide", function()
    if menuFrame and menuFrame:IsShown() then
        menuFrame:Hide()
    end
end)

-- Initialisation de l'addon
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
    if addon == "MapMate" then
        CreateMapButton()
    end
end)



------------------------------------------


-- local function PrintPlayerList()
--     local playerList = _G["MapMatePlayerList"]
    
--     if not playerList then
--         print("Player list is not initialized.")
--         return
--     end

--     for _, player in ipairs(playerList) do
--         print("Name:", player.name, "| Layer:", player.layer)
--     end
-- end


-- C_Timer.NewTicker(5, PrintPlayerList)
