-- Déclare la table principale de l'addon
MapMate = MapMate or {}
MapMateUI = MapMateUI or {}
local waypoints = MapMate.waypoints or {}
MapMate.waypoints = waypoints
local pins = {} -- Table pour stocker les pins
local guildMembers = {} -- Table pour stocker les informations des membres de la guilde

-- Chargement de la bibliothèque HereBeDragons
local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Intervalle de mise à jour
local updateInterval = 2 -- En secondes
local movementThreshold = 0.005 -- 5% de la carte (environ 5 mètres)
local timeSinceLastUpdate = 0
local maxTimeBetweenUpdate = 3 -- En secondes
local lastSentPosition = { x = nil, y = nil, mapID = nil } -- Dernière position envoyée

function MapMate:GetClassIcon()
    local _, class = UnitClass("player")
    if class == "DRUID" then
        return "Interface\\AddOns\\MapMate\\Textures\\DRUID"

    elseif class == "HUNTER" then
        return "Interface\\AddOns\\MapMate\\Textures\\HUNTER"
        
    elseif class == "MAGE" then 
        return "Interface\\AddOns\\MapMate\\Textures\\MAGE"

    elseif class == "PALADIN" then
        return "Interface\\AddOns\\MapMate\\Textures\\PALADIN"

    elseif class == "PRIEST" then
        return "Interface\\AddOns\\MapMate\\Textures\\PRIEST"

    elseif class == "ROGUE" then
        return "Interface\\AddOns\\MapMate\\Textures\\ROGUE"

    elseif class == "SHAMAN" then
        return "Interface\\AddOns\\MapMate\\Textures\\SHAMAN"

    elseif class == "WARLOCK" then
        return "Interface\\AddOns\\MapMate\\Textures\\WARLOCK"

    elseif class == "WARRIOR" then
        return "Interface\\AddOns\\MapMate\\Textures\\WARRIOR"
    end
end
local selectedTexture = MapMate:GetClassIcon()
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
                    local class = UnitClass("player")
                    local icon = selectedTexture
                    local message = string.format("%s,%s,%d,%s,%.3f,%.3f,%d,%s", name, playerRank, level, class, x, y, mapID, icon)
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

-- Fonction pour traiter les messages reçus via Addon Message
local function OnAddonMessage(prefix, text, channel, sender)
    if prefix == ADDON_PREFIX and not IsSelf(sender) then
        local name, rank, level, class, x, y, mapID, icon = strsplit(",", text)
        --print("Update ", name, " ", rank, " ", level, " ", class, " ", x, " ", y, " ", mapID, " ", icon)
        x, y, mapID, level = tonumber(x), tonumber(y), tonumber(mapID), tonumber(level)

        if x and y and mapID then
            guildMembers[name] = {
                rank = rank,
                level = level,
                class = class,
                x = x,
                y = y,
                mapID = mapID,
                icon = icon,
            }

            MapMate:CreateGuildMemberPin(name, icon, rank)
        end
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
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        MapMate:RefreshPins()
    end
end)

-- Fonction pour créer ou mettre à jour un pin pour un membre de la guilde
function MapMate:CreateGuildMemberPin(memberName, icon, rank)
    local member = guildMembers[memberName]
    if not member then return end

    MapMate:RemovePinsByTitle(memberName, icon)
    self:AddWaypoint(member.mapID, member.x, member.y, memberName, icon, rank)
end

-- Fonction pour rafraîchir les pins dynamiquement
function MapMate:RefreshPins()
    for memberName, _ in pairs(guildMembers) do
        self:CreateGuildMemberPin(memberName)
    end
end

-- Gestion des événements
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_GUILD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_GUILD" then
        local text, sender = ...
        ProcessGuildMessage(text, sender)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        MapMate:RefreshPins()
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

-- Fonction pour créer deux pins (carte et mini-carte)
function MapMate:CreateMapPin(waypoint, icon, rank)

    local size = MapMateDB.iconSize
    local displayRank = MapMateDB.showRanks
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

    -- Crée un pin pour la carte mondiale
    local worldPin = CreateFrame("Frame", nil, UIParent)
    worldPin:SetSize(18*size, 18*size)

    local worldTexture = worldPin:CreateTexture(nil, "BACKGROUND")
    worldTexture:SetAllPoints()
    worldTexture:SetSize(16*size,16*size)
    worldTexture:SetTexture(icon)
    worldPin.texture = worldTexture
    if displayRank then
        if(rank == "0") then
            local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", worldPin, "CENTER", 0, 1)
            overlayTexture:SetSize(36*size,36*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\GM")
        
        elseif(rank == "1") then
            local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(36*size,36*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Officier")
        elseif(rank == "2") then
            local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(36*size,36*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Veteran2")
        elseif(rank == "3") then
            local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(36*size,36*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Member2")
        end
    end

    local worldAdded = HBDPins:AddWorldMapIconMap("MapMate", worldPin, waypoint.mapID, waypoint.x, waypoint.y, HBD_PINS_WORLDMAP_SHOW_WORLD) -- HBD_PINS_WORLDMAP_SHOW_PARENT si uniquement locale

    -- Crée un pin pour la mini-carte
    local minimapPin = CreateFrame("Frame", nil, UIParent)
    minimapPin:SetSize(12*size, 12*size)

    local minimapTexture = minimapPin:CreateTexture(nil, "BACKGROUND")
    minimapTexture:SetAllPoints()
    minimapTexture:SetTexture(icon) -- Chemin vers une icône personnalisée
    minimapPin.texture = minimapTexture
    if displayRank then
        if(rank == "0") then
            local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(20*size,20*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\GM")
        elseif(rank == "1") then
            local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(20*size,20*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Officier")
        elseif(rank == "2") then
            local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(20*size,20*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Veteran2")
        elseif(rank == "3") then
            local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
            overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
            overlayTexture:SetSize(20*size,20*size)
            overlayTexture:SetTexture("Interface\\AddOns\\MapMate\\Textures\\Member2")
        end
    end

    local minimapAdded = HBDPins:AddMinimapIconMap("MapMate", minimapPin, waypoint.mapID, waypoint.x, waypoint.y, false)

    -- Stocke les deux pins
    pins[waypoint] = {
        world = worldPin,
        minimap = minimapPin,
        title = waypoint.title
    }

    -- Ajoute un tooltip au pin de la carte mondiale
    worldPin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(worldPin, "ANCHOR_RIGHT")
        GameTooltip:SetText(waypoint.title)
        GameTooltip:Show()
    end)
    worldPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Ajoute un tooltip au pin de la mini-carte
    minimapPin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimapPin, "ANCHOR_RIGHT")
        GameTooltip:SetText(waypoint.title)
        GameTooltip:Show()
    end)
    minimapPin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Fonction pour ajouter un waypoint
function MapMate:AddWaypoint(mapID, x, y, title, icon, rank)
    local waypoint = {
        mapID = mapID,
        x = x,
        y = y,
        title = title or "Waypoint",
    }
    table.insert(waypoints, waypoint)
    -- Ajout du pin via HereBeDragons
    self:CreateMapPin(waypoint, icon, rank)
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
            print("Déconnexion détectée : " .. name)
            MapMate:RemovePinsByTitle(Ambiguate(name, "short"))
            -- Exemple : Supprimer une pin
            -- MapMate:RemovePinsByTitle(name)
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




