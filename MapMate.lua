-- This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
-- If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Déclare la table principale de l'addon
MapMate = MapMate or {}
MapMateUI = MapMateUI or {}
local waypoints = MapMate.waypoints or {}
MapMate.waypoints = waypoints
local pins = {} -- Table pour stocker les pins
local guildMembers = {} -- Table pour stocker les informations des membres de la guilde
_G["currentLayer"] = 0

-- Chargement de la bibliothèque HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

if not IsAddOnLoaded("Blizzard_DebugTools") then
    LoadAddOn("Blizzard_DebugTools") -- Assurez-vous que la bibliothèque est chargée
end
if not EasyMenu then
    LoadAddOn("Blizzard_UIDropDownMenu") -- Charge UIDropDownMenu si nécessaire
end

-- Intervalle de mise à jour
local updateInterval = 2 -- En secondes
local movementThreshold = 0.005 -- 5% de la carte (environ 5 mètres)
local timeSinceLastUpdate = 0
local maxTimeBetweenUpdate = 3 -- En secondes
local lastSentPosition = { x = nil, y = nil, mapID = nil } -- Dernière position envoyée

-- Fonction pour calculer la distance entre deux points
local function CalculateDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then return math.huge end
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

local playerRank = nil -- Rang du joueur dans la guilde

-- Fonction pour récupérer le rang du joueur
local function GetPlayerGuildRankIndex()
    local playerName = UnitName("player")
    local realmName = GetNormalizedRealmName()
    local fullPlayerName = playerName .. "-" .. realmName
    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if name and name == fullPlayerName then
            return rankIndex
        end
    end

    return nil -- Si le joueur n'est pas trouvé
end

local function ShowCustomContextMenu(pin, playerName)
    -- Crée le frame pour le menu contextuel
    local menuFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menuFrame:SetSize(125, 80) -- Taille du menu
    menuFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 5,
    })
    menuFrame:SetBackdropColor(0, 0, 0, 1)

    -- Positionne le menu au centre de la souris
    local x, y = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    menuFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uiScale, y / uiScale)

    menuFrame:SetFrameStrata("DIALOG")
    menuFrame:SetFrameLevel(99)
    menuFrame:Show()

    -- Crée un bouton pour inviter
    local inviteButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    inviteButton:SetSize(120, 20)
    inviteButton:SetPoint("TOP", menuFrame, "TOP", 0, -5)
    inviteButton:SetText(MapMate_Localize("Invite"))
    inviteButton:SetScript("OnClick", function()
        InviteUnit(playerName)
        menuFrame:Hide()
    end)

    -- Crée un bouton pour chuchoter
    local whisperButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    whisperButton:SetSize(120, 20)
    whisperButton:SetPoint("TOP", inviteButton, "BOTTOM", 0, -5)
    whisperButton:SetText(MapMate_Localize("Wisper"))
    whisperButton:SetScript("OnClick", function()
        ChatFrame_SendTell(playerName)
        menuFrame:Hide()
    end)

    -- Crée un bouton pour fermer
    local closeButton = CreateFrame("Button", nil, menuFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(120, 20)
    closeButton:SetPoint("TOP", whisperButton, "BOTTOM", 0, -5)
    closeButton:SetText(MapMate_Localize("Cancel"))
    closeButton:SetScript("OnClick", function()
        menuFrame:Hide()
    end)

    -- Ajoute un comportement de fermeture automatique si la souris quitte le menu
    menuFrame:SetScript("OnLeave", function()
        -- Vérifie si la souris est encore dans un enfant du menu
        C_Timer.After(0.1, function()
            if not menuFrame:IsMouseOver() then
                menuFrame:Hide()
            end
        end)
    end)

    -- Empêche le menu de disparaître si la souris passe sur un bouton
    local function PreventClose(button)
        button:SetScript("OnEnter", function()
            menuFrame:SetScript("OnLeave", function()
                -- Ne ferme pas tant que la souris est sur un bouton
            end)
        end)
        button:SetScript("OnLeave", function()
            menuFrame:SetScript("OnLeave", function()
                C_Timer.After(0.1, function()
                    if not menuFrame:IsMouseOver() then
                        menuFrame:Hide()
                    end
                end)
            end)
        end)
    end

    PreventClose(inviteButton)
    PreventClose(whisperButton)
    PreventClose(closeButton)
end


-- Fonction pour initialiser le rang
local function InitializePlayerRank()
    playerRank = GetPlayerGuildRankIndex()
    if playerRank then
        return true -- Le rang a été trouvé
    else
        --print("Rang du joueur introuvable, tentative suivante...")
        C_GuildInfo.GuildRoster() -- Rafraîchir les infos de guilde
        return false -- Le rang n'est pas encore disponible
    end
end

-- Attente jusqu'à ce que le rang soit initialisé
local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(self, elapsed)
    if InitializePlayerRank() then
        self:SetScript("OnUpdate", nil) -- Stoppe la boucle dès que le rang est trouvé
    end
end)

-- Déclencher une mise à jour initiale de la guilde
C_GuildInfo.GuildRoster()

-- Préfixe unique pour l'addon
local ADDON_PREFIX = "MapMate"
local INVITE_PREFIX = "MapMateInvite"

if playerRank == nil then
    -- Parcours des membres de la guilde pour trouver le rang
    for i = 1, GetNumGuildMembers() do
        local memberName, memberRank = GetGuildRosterInfo(i)
        local playerName = UnitName("player")
        local realmName = GetNormalizedRealmName()
        local fullPlayerName = playerName .. "-" .. realmName

        if memberName == fullPlayerName then
            playerRank = memberRank
            break
        end
    end
end

-- Inscription du préfixe pour la communication addon
C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
C_ChatInfo.RegisterAddonMessagePrefix(INVITE_PREFIX)

-- Fonction pour envoyer la position via Addon Message
function MapMate:SendGuildPosition()
    if IsInGuild() then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end

        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local x, y = position:GetXY()
            if x and y then
                -- Vérifie si le rang est défini, sinon essaie de le récupérer
                if not playerRank then
                    for i = 1, GetNumGuildMembers() do
                        local memberName, memberRank = GetGuildRosterInfo(i)
                        local playerName = UnitName("player")
                        local realmName = GetNormalizedRealmName()
                        local fullPlayerName = playerName .. "-" .. realmName

                        if memberName == fullPlayerName then
                            playerRank = memberRank
                            break
                        end
                    end
                end

                -- Définit un rang par défaut si toujours `nil`
                playerRank = playerRank or "Membre"

                -- Vérifie si la position a changé significativement ou si trop de temps s'est écoulé
                if CalculateDistance(x, y, lastSentPosition.x, lastSentPosition.y) > movementThreshold
                or timeSinceLastUpdate > maxTimeBetweenUpdate then
                    playerRank = GetPlayerGuildRankIndex()
                    local name = UnitName("player")
                    local level = UnitLevel("player")
                    local _, classFileName = UnitClass("player")
                    local class = classFileName
                    local playerHealthPercent = math.floor(UnitHealth("player") / UnitHealthMax("player") * 100)
                    local autoInvitEnabled = MapMateDB.autoInviteForLayer and 1 or 0
                    local message = string.format("%s,%s,%d,%s,%.3f,%.3f,%d,%d,%d,%d", name, playerRank, level, class, x, y, mapID, playerHealthPercent, currentLayer, autoInvitEnabled)

                    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "GUILD")
                    lastSentPosition = { x = x, y = y, mapID = mapID }
                    timeSinceLastUpdate = 0
                end
            end
        end
    end
end


-- Fonction pour vérifier si le message provient du joueur lui-même
local function IsSelf(sender)
    local playerName = UnitName("player")
    local realmName = GetNormalizedRealmName()
    local fullPlayerName = playerName .. "-" .. realmName
    return sender == fullPlayerName
end

local function TemporarilyMuteSound()
    -- Sauvegarder le volume actuel des effets sonores
    local originalVolume = GetCVar("Sound_EnableSFX")

    -- Désactiver les sons
    SetCVar("Sound_EnableSFX", "0")

    -- Remettre les sons après un court délai
    C_Timer.After(2, function()
        SetCVar("Sound_EnableSFX", originalVolume)
    end)
end

-- Fonction pour traiter les messages reçus via Addon Message
-- Initialiser une table pour stocker les joueurs
local playerList = {}
-- Rendre la liste globale pour qu'elle soit accessible depuis d'autres fichiers
_G["MapMatePlayerList"] = playerList

-- Fonction pour gérer les messages de l'addon
local function OnAddonMessage(prefix, text, channel, sender)

    if prefix == INVITE_PREFIX then

        if not MapMateDB.autoInviteForLayer then
            local responseMessage = "NO" 
            C_ChatInfo.SendAddonMessage(INVITE_PREFIX, responseMessage, "WHISPER", sender)
            return
        end

        if IsInGroup() and not UnitIsGroupLeader("player") then
            local responseMessage = "NOCHIEF" 
            C_ChatInfo.SendAddonMessage(INVITE_PREFIX, responseMessage, "WHISPER", sender)
            return
        end
        
        if text == "MapMateInvite" then
            TemporarilyMuteSound()
            InviteUnit(sender)
        
            -- Répondre à l'expéditeur
            local responseMessage = "OK"
            C_ChatInfo.SendAddonMessage(INVITE_PREFIX, responseMessage, "WHISPER", sender)
        end
    end
    if prefix == ADDON_PREFIX and not IsSelf(sender) and channel == "GUILD" then
        -- Décomposer le message en valeurs individuelles
        local name, rank, level, class, x, y, mapID, healthPercent, layer, autoInvit = strsplit(",", text)

        -- Vérifications et conversions
        name = type(name) == "string" and name or "Unknown"
        rank = type(rank) == "string" and rank or "5"
        level = tonumber(level) or 1 -- Par défaut, niveau 1
        class = type(class) == "string" and class:upper() or "UNKNOWN" -- Par défaut, classe "UNKNOWN"
        x = tonumber(x) or 0 -- Par défaut, 0
        y = tonumber(y) or 0 -- Par défaut, 0
        mapID = tonumber(mapID) or 0 -- Par défaut, 0
        healthPercent = tonumber(healthPercent) or 100
        layer = tonumber(layer) or 0
        autoInvit = tonumber(autoInvit) or 0

        -- Vérifie que les coordonnées sont dans des plages acceptables (0-1 pour x et y)
        if x < 0 or x > 1 then x = 0 end
        if y < 0 or y > 1 then y = 0 end

        -- Vérifier si le joueur est déjà dans la liste
        local playerExists = false
        for _, player in ipairs(playerList) do
            if player.name == name then
                playerExists = true
                -- Si le layer a changé ou les informations diffèrent, mettre à jour
                if player.layer ~= layer then
                    player.rank = rank
                    player.level = level
                    player.class = class
                    player.x = x
                    player.y = y
                    player.mapID = mapID
                    player.healthPercent = healthPercent
                    player.layer = layer
                    player.autoInvit = autoInvit
                end
                break
            end
        end

        -- Si le joueur n'existe pas, l'ajouter à la liste
        if not playerExists then
            table.insert(playerList, {
                name = name,
                rank = rank,
                level = level,
                class = class,
                x = x,
                y = y,
                mapID = mapID,
                healthPercent = healthPercent,
                layer = layer,
                autoInvit = autoInvit,
            })
        end

        -- Créer ou mettre à jour le pin sur la carte pour ce membre
        MapMate:AddWaypoint(mapID, x, y, name, healthPercent, rank, level, class, layer)
    end
end


-- Gestion des événements
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        OnAddonMessage(prefix, text, channel, sender)
    end
end)

-- Mise à jour périodique pour envoyer la position
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= updateInterval then
        MapMate:SendGuildPosition()
    end
end)

-- Fonction pour obtenir les couleurs RGB des classes
function GetClassColorRGB(className)
    local classColors = {
        WARRIOR = {1, 0.78, 0.55},
        PALADIN = {0.96, 0.55, 0.73},
        HUNTER = {0.67, 0.83, 0.45},
        ROGUE = {1, 0.96, 0.41},
        PRIEST = {1, 1, 1},
        DEATHKNIGHT = {0.77, 0.12, 0.23},
        SHAMAN = {0, 0.44, 0.87},
        MAGE = {0.25, 0.78, 0.92},
        WARLOCK = {0.53, 0.53, 0.93},
        MONK = {0, 1, 0.59},
        DRUID = {1, 0.49, 0.04},
        DEMONHUNTER = {0.64, 0.19, 0.79},
        EVOKER = {0.2, 0.58, 0.5}
    }

    -- Récupère les couleurs RGB pour la classe donnée (ou blanc par défaut)
    local color = classColors[className:upper()] or {1, 1, 1}
    return unpack(color) -- Retourne les trois valeurs RGB séparées
end

-- Fonction pour obtenir uniquement l'icône des classes
function GetClassIconPath(className)
    local classIcons = {
        WARRIOR = "Interface\\AddOns\\MapMate\\Textures\\WARRIOR",
        PALADIN = "Interface\\AddOns\\MapMate\\Textures\\PALADIN",
        HUNTER = "Interface\\AddOns\\MapMate\\Textures\\HUNTER",
        ROGUE = "Interface\\AddOns\\MapMate\\Textures\\ROGUE",
        PRIEST = "Interface\\AddOns\\MapMate\\Textures\\PRIEST",
        DEATHKNIGHT = "Interface\\AddOns\\MapMate\\Textures\\DEATHKNIGHT",
        SHAMAN = "Interface\\AddOns\\MapMate\\Textures\\SHAMAN",
        MAGE = "Interface\\AddOns\\MapMate\\Textures\\MAGE",
        WARLOCK = "Interface\\AddOns\\MapMate\\Textures\\WARLOCK",
        MONK = "Interface\\AddOns\\MapMate\\Textures\\MONK",
        DRUID = "Interface\\AddOns\\MapMate\\Textures\\DRUID",
        DEMONHUNTER = "Interface\\AddOns\\MapMate\\Textures\\DEMONHUNTER",
        EVOKER = "Interface\\AddOns\\MapMate\\Textures\\EVOKER"
    }

    -- Retourne le chemin de l'icône ou une icône par défaut si la classe est invalide
    return classIcons[className:upper()] or "Interface\\AddOns\\MapMate\\Textures\\WARRIOR"
end

-- Fonction pour créer deux pins (carte et mini-carte)
function MapMate:CreateMapPin(waypoint, healthPercent, rank, targetLevel, className, layer)
    local size = MapMateDB.iconSize
    local mmSize = MapMateDB.MMIconSize
    local displayRank = MapMateDB.showRanks
    local displayLevel = MapMateDB.displayLevel
    local displaySimpleDots = MapMateDB.simpleDots
    local displayName = MapMateDB.displayName
    local displayHealth = MapMateDB.displayHealth
    local displayLayer = MapMateDB.showPlayersLayer
    local enableMinimapPin = MapMateDB.enableMinimapPin
    local enableMMRank = MapMateDB.showRanksMM
    local displayMMDots = MapMateDB.simpleDotsMM

    -- Supprime les anciens pins s'ils existent
    if pins[waypoint] then
        if pins[waypoint].world then
            HBDPins:RemoveWorldMapIcon("MapMate", pins[waypoint].world)
        end
        if pins[waypoint].minimap then
            HBDPins:RemoveMinimapIcon("MapMate", pins[waypoint].minimap)
        end
        pins[waypoint] = nil
    end

    if not MapMateDB.showPlayersOnMap then
        return
    end

    -- Ignore les joueurs sur d'autres layers
    if MapMateDB.ignorePlayerOnOtherLayers and layer ~= currentLayer and currentLayer ~= 0 then
        return
    end

    -- Crée un pin pour la carte mondiale
    local worldPin = CreateFrame("Frame", nil, UIParent)
    worldPin:SetSize(18 * size, 18 * size)

    local worldTexture = worldPin:CreateTexture(nil, "BACKGROUND")
    worldTexture:SetAllPoints()
    worldTexture:SetSize(16 * size, 16 * size)
    if displaySimpleDots then
        worldTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Pin")
    else
        worldTexture:SetTexture(GetClassIconPath(className))
    end
    worldPin.texture = worldTexture

    -- Ajoute un événement clic droit au pin de la carte mondiale
    worldPin:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ShowCustomContextMenu(worldPin, waypoint.title)
        end
    end)

    -- Affiche la barre de vie
    if displayHealth then
        local healthBarBackground = worldPin:CreateTexture(nil, "ARTWORK")
        healthBarBackground:SetColorTexture(0.2, 0.2, 0.2, 1)
        healthBarBackground:SetSize(18 * size, 3 * size)
        healthBarBackground:SetPoint("BOTTOM", worldPin, "TOP", 0, 13 * size)

        local healthBar = worldPin:CreateTexture(nil, "OVERLAY")
        healthBar:SetColorTexture(0, 1, 0, 1)
        healthBar:SetSize(18 * size * (healthPercent / 100), 3 * size)
        healthBar:SetPoint("LEFT", healthBarBackground, "LEFT")
    end

    -- Affiche le nom au-dessus du pin
    if displayName then
        local nameText = worldPin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("TOP", worldPin, "BOTTOM", 0, -6 * size)
        nameText:SetText(waypoint.title)
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 10 * size, "OUTLINE")
    end

    -- Affiche le niveau en bas des pins
    if displayLevel then
        local levelText = worldPin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        levelText:SetPoint("TOP", worldPin, "TOP", 0, 10 * size)
        levelText:SetText(tostring(targetLevel))
        levelText:SetFont("Fonts\\FRIZQT__.TTF", 10 * size, "OUTLINE")
    end

    -- Affiche la couche (layer)
    if displayLayer and waypoint.layer ~= 0 then
        local targetLayer = worldPin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local offset = displayName and -16 or -6
        targetLayer:SetPoint("TOP", worldPin, "BOTTOM", 0, offset * size)
        targetLayer:SetText("Layer " .. tostring(waypoint.layer))
        targetLayer:SetFont("Fonts\\FRIZQT__.TTF", 10 * size, "OUTLINE")
    end

    -- Applique les icônes de rangs
    if displayRank then
        local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -0.8, -1)
        overlayTexture:SetSize(34 * size, 34 * size)

        if rank == "0" then
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\GM4")
        elseif rank == "1" then
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Officier")
        elseif rank == "2" then
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Veteran2")
        elseif rank == "3" then
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Member2")
        end
    end

    -- Ajoute le pin à la carte mondiale
    local worldAdded = HBDPins:AddWorldMapIconMap("MapMate", worldPin, waypoint.mapID, waypoint.x, waypoint.y, HBD_PINS_WORLDMAP_SHOW_WORLD)

    -- Ajoute un tooltip au pin de la carte mondiale
    local r, g, b = GetClassColorRGB(className)
    worldPin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(worldPin, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(waypoint.title, r, g, b)
        if MapMateDB.showPlayersLayerTooltip and waypoint.layer ~= 0 then
            GameTooltip:AddLine("Layer " .. tostring(waypoint.layer), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    worldPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Crée un pin pour la mini-carte
    local minimapPin = nil
    if enableMinimapPin then
        minimapPin = CreateFrame("Frame", nil, UIParent)
        minimapPin:SetSize(12 * mmSize, 12 * mmSize)

        local minimapTexture = minimapPin:CreateTexture(nil, "BACKGROUND")
        minimapTexture:SetAllPoints()
        if displayMMDots then
            minimapTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Pin")
        else
            minimapTexture:SetTexture(GetClassIconPath(className))
        end
        minimapPin.texture = minimapTexture

        -- Applique les icônes de rangs sur la minimap
        if enableMMRank then
            local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(20 * mmSize, 20 * mmSize)

            if rank == "0" then
                overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\GM4")
            elseif rank == "1" then
                overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Officier")
            elseif rank == "2" then
                overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Veteran2")
            elseif rank == "3" then
                overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Member2")
            end
        end

        -- Ajoute un tooltip au pin de la mini-carte
        minimapPin:SetScript("OnEnter", function()
            GameTooltip:SetOwner(minimapPin, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(waypoint.title, r, g, b)
            GameTooltip:Show()
        end)
        minimapPin:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Ajoute le pin à la mini-carte
        HBDPins:AddMinimapIconMap("MapMate", minimapPin, waypoint.mapID, waypoint.x, waypoint.y, false)
    end

    -- Stocke les deux pins
    pins[waypoint] = {
        world = worldPin,
        minimap = minimapPin,
        title = waypoint.title
    }
end



-- Fonction pour ajouter un waypoint
function MapMate:AddWaypoint(mapID, x, y, title, healthPercent, rank, targetLevel, class, layer)
    MapMate:RemovePinsByTitle(title)
    local waypoint = {
        mapID = mapID,
        x = x,
        y = y,
        title = title or "Waypoint",
        healthPercent = healthPercent,
        layer = layer,
    }
    table.insert(waypoints, waypoint)
    -- Ajout du pin via HereBeDragons
    self:CreateMapPin(waypoint, healthPercent, rank, targetLevel, class, layer)
end

-- Fonction pour supprimer tous les waypoints
function MapMate:ClearAllWaypoints()
    for _, pinSet in pairs(pins) do
        if pinSet.world then
            HBDPins:RemoveWorldMapIcon("MapMate", pinSet.world)
        end
        if pinSet.minimap then
            HBDPins:RemoveMinimapIcon("MapMate", pinSet.minimap)
        end
    end
    waypoints = {}
    pins = {}
    print("Tous les waypoints ont été supprimés.")
end

function MapMate:RemovePinsByTitle(title)
    -- Vérifie que le titre est valide
    if not title then
        print("Erreur : aucun titre fourni pour la suppression.")
        return
    end

    -- Parcourt la table `pins`
    for key, pinSet in pairs(pins) do
        if pinSet.title == title then
            -- Supprime les pins de la carte mondiale
            if pinSet.world then
                HBDPins:RemoveWorldMapIcon("MapMate", pinSet.world)
            end

            -- Supprime les pins de la mini-carte
            if pinSet.minimap then
                HBDPins:RemoveMinimapIcon("MapMate", pinSet.minimap)
            end

            -- Retire l'entrée de la table `pins`
            pins[key] = nil
        end
    end
end

local previousRoster = {}

local function UpdateGuildRoster()
    GuildRoster() -- Demande une mise à jour du roster
    local numGuildMembers = GetNumGuildMembers()
    local currentRoster = {}

    for i = 1, numGuildMembers do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if name then
            currentRoster[name] = online
        end
    end

    -- Comparer les états en ligne
    for name, wasOnline in pairs(previousRoster) do
        if wasOnline and not currentRoster[name] then
            MapMate:RemovePinsByTitle(Ambiguate(name, "short"))
            -- Supprime le joueur de la liste
            for i = #playerList, 1, -1 do
                if playerList[i].name == name then
                    table.remove(playerList, i)
                    print("Removed player from list:", name)
                    break
                end
            end
        end
    end

    -- Mise à jour des données du roster précédent
    previousRoster = currentRoster
end

-- Écouter l'événement
local frame = CreateFrame("Frame")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
    if event == "GUILD_ROSTER_UPDATE" then
        UpdateGuildRoster()
    end
end)

-- Initialisation au chargement de l'addon
GuildRoster()

-- Vérifie si la variable de nova world buff est définie
local function GetLayerFromNWB()
    -- Vérifie si la variable globale NWB_CurrentLayer existe
    if NWB_CurrentLayer ~= nil and NWB_CurrentLayer ~= 0 then
        currentLayer = NWB_CurrentLayer
    else
        currentLayer = 0
        return nil
    end
end

-- Crée un ticker qui exécute la fonction NWB toutes les 5 secondes
C_Timer.NewTicker(5, GetLayerFromNWB)