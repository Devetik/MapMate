-- Déclare la table principale de l'addon
Astralith = Astralith or {}
local waypoints = Astralith.waypoints or {}
Astralith.waypoints = waypoints
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

function Astralith:GetClassIcon()
    local _, class = UnitClass("player")
    if class == "DRUID" then
        return "Interface\\AddOns\\Astralith\\Textures\\DRUID"

    elseif class == "HUNTER" then
        return "Interface\\AddOns\\Astralith\\Textures\\HUNTER"
        
    elseif class == "MAGE" then 
        return "Interface\\AddOns\\Astralith\\Textures\\MAGE"

    elseif class == "PALADIN" then
        return "Interface\\AddOns\\Astralith\\Textures\\PALADIN"

    elseif class == "PRIEST" then
        return "Interface\\AddOns\\Astralith\\Textures\\PRIEST"

    elseif class == "ROGUE" then
        return "Interface\\AddOns\\Astralith\\Textures\\ROGUE"

    elseif class == "SHAMAN" then
        return "Interface\\AddOns\\Astralith\\Textures\\SHAMAN"

    elseif class == "WARLOCK" then
        return "Interface\\AddOns\\Astralith\\Textures\\WARLOCK"

    elseif class == "WARRIOR" then
        return "Interface\\AddOns\\Astralith\\Textures\\WARRIOR"
    end
end
local selectedTexture = Astralith:GetClassIcon()
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
local ADDON_PREFIX = "Astralith"

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
function Astralith:SendGuildPosition()
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

                -- if timeSinceLastUpdate > maxTimeBetweenUpdate * 4 then
                --     playerRank = GetPlayerGuildRankIndex()
                -- end
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

            Astralith:CreateGuildMemberPin(name, icon, rank)
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
        Astralith:RefreshPins()
    end
end)

-- Fonction pour créer ou mettre à jour un pin pour un membre de la guilde
function Astralith:CreateGuildMemberPin(memberName, icon, rank)
    local member = guildMembers[memberName]
    if not member then return end

    Astralith:RemovePinsByTitle(memberName, icon)
    self:AddWaypoint(member.mapID, member.x, member.y, memberName, icon, rank)
end

-- Fonction pour rafraîchir les pins dynamiquement
function Astralith:RefreshPins()
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
        Astralith:RefreshPins()
    end
end)

-- Mise à jour périodique pour envoyer la position
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate >= updateInterval then
        Astralith:SendGuildPosition()
    end
end)

-- Fonction pour créer deux pins (carte et mini-carte)
function Astralith:CreateMapPin(waypoint, icon, rank)

    -- Supprime les anciens pins s'ils existent
    if pins[waypoint] then
        if pins[waypoint].world then
            HBDPins:RemoveWorldMapIcon("Astralith", pins[waypoint].world)
        end
        if pins[waypoint].minimap then
            HBDPins:RemoveMinimapIcon("Astralith", pins[waypoint].minimap)
        end
        pins[waypoint] = nil
    end

    -- Crée un pin pour la carte mondiale
    local worldPin = CreateFrame("Frame", nil, UIParent)
    worldPin:SetSize(18, 18)

    local worldTexture = worldPin:CreateTexture(nil, "BACKGROUND")
    worldTexture:SetAllPoints()
    worldTexture:SetSize(16,16)
    worldTexture:SetTexture(icon)
    worldPin.texture = worldTexture

    if(rank == "0") then
        local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", worldPin, "CENTER", 0, 1)
        overlayTexture:SetSize(36,36)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\GM")
    
    elseif(rank == "1") then
        local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(36,36)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Officier")
    elseif(rank == "2") then
        local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(36,36)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Veteran2")
    elseif(rank == "3") then
        local overlayTexture = worldPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", worldPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(36,36)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Member2")
    end

    local worldAdded = HBDPins:AddWorldMapIconMap("Astralith", worldPin, waypoint.mapID, waypoint.x, waypoint.y, HBD_PINS_WORLDMAP_SHOW_WORLD) -- HBD_PINS_WORLDMAP_SHOW_PARENT si uniquement locale

    -- Crée un pin pour la mini-carte
    local minimapPin = CreateFrame("Frame", nil, UIParent)
    minimapPin:SetSize(12, 12)

    local minimapTexture = minimapPin:CreateTexture(nil, "BACKGROUND")
    minimapTexture:SetAllPoints()
    minimapTexture:SetTexture(icon) -- Chemin vers une icône personnalisée
    minimapPin.texture = minimapTexture

    if(rank == "0") then
        local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(20,20)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\GM")
    
    elseif(rank == "1") then
        local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(20,20)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Officier")
    elseif(rank == "2") then
        local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(20,20)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Veteran2")
    elseif(rank == "3") then
        local overlayTexture = minimapPin:CreateTexture(nil, "OVERLAY")
        overlayTexture:SetPoint("CENTER", minimapPin, "CENTER", -1.3, -0.5)
        overlayTexture:SetSize(20,20)
        overlayTexture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\Member2")
    end

    local minimapAdded = HBDPins:AddMinimapIconMap("Astralith", minimapPin, waypoint.mapID, waypoint.x, waypoint.y, false)

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
function Astralith:AddWaypoint(mapID, x, y, title, icon, rank)
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
function Astralith:ClearAllWaypoints()
    for _, pinSet in pairs(pins) do
        if pinSet.world then
            HBDPins:RemoveWorldMapIcon("Astralith", pinSet.world)
        end
        if pinSet.minimap then
            HBDPins:RemoveMinimapIcon("Astralith", pinSet.minimap)
        end
    end
    waypoints = {}
    pins = {}
    print("Tous les waypoints ont été supprimés.")
end

function Astralith:RemovePinsByTitle(title)
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
                HBDPins:RemoveWorldMapIcon("Astralith", pinSet.world)
            end

            -- Supprime les pins de la mini-carte
            if pinSet.minimap then
                HBDPins:RemoveMinimapIcon("Astralith", pinSet.minimap)
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
            Astralith:RemovePinsByTitle(Ambiguate(name, "short"))
            -- Exemple : Supprimer une pin
            -- Astralith:RemovePinsByTitle(name)
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

-- Commandes slash
SLASH_ASTRALITH1 = "/astr"
SlashCmdList["ASTRALITH"] = function(msg)
    local cmd, arg1, arg2, arg3 = strsplit(" ", msg)
    if cmd == "add" and arg1 and arg2 and arg3 then
        local mapID = tonumber(arg1)
        local x = tonumber(arg2) / 100
        local y = tonumber(arg3) / 100
        if mapID and x and y then
            Astralith:AddWaypoint(mapID, x, y, "Point Custom")
        else
            print("Utilisation : /astr add <mapID> <x> <y>")
        end
    elseif cmd == "clear" then
        Astralith:ClearAllWaypoints()
    elseif cmd == "relo" then
        Astralith:RemovePinsByTitle("Ævi")
    else
        print("Commandes :")
        print("/astr add <mapID> <x> <y> - Ajoute un point")
        print("/astr clear - Supprime tous les points")
        print("/astr relo - Ajoute un point à votre position actuelle")
    end
end
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
-- Ajouter le bouton sur la minimap
local isConfigWindowShown = false
function Astralith:CreateMinimapButton()
    local minimapButton = CreateFrame("Button", "AstralithMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)

    -- Texture du bouton
    local texture = minimapButton:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\AddOns\\Astralith\\Textures\\MinimapIcon")
    texture:SetAllPoints(minimapButton)
    minimapButton.texture = texture

    -- Déplacement du bouton autour de la minimap
    local angle = 10 -- Position initiale
    local function UpdateMinimapButtonPosition()
        local radius = 80
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    UpdateMinimapButtonPosition()

    minimapButton:SetScript("OnDragStart", function()
        minimapButton:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            local px, py = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            angle = math.atan2(my / scale - py, mx / scale - px)
            UpdateMinimapButtonPosition()
        end)
    end)
    minimapButton:SetScript("OnDragStop", function()
        minimapButton:SetScript("OnUpdate", nil)
    end)

    -- Clic pour ouvrir la fenêtre de sélection
    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            Astralith:ShowTextureSelector()
        end
    end)

    -- Tooltip
    minimapButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(minimapButton, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Astralith")
        GameTooltip:AddLine("Clic gauche : Sélectionner une texture")
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Créer une fenêtre pour la sélection de texture
function Astralith:ShowTextureSelector()
    if Astralith.textureSelector then
        Astralith.textureSelector:Show()
        return
    end

    local frame = CreateFrame("Frame", "AstralithTextureSelector", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(400, 300)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -10)
    frame.title:SetText("Sélectionnez une texture")

    local scrollFrame = CreateFrame("ScrollFrame", "AstralithTextureScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(350, 1000)
    scrollFrame:SetScrollChild(content)

    local textures = {
        "Interface\\AddOns\\Astralith\\Textures\\Pin",
        "Interface\\AddOns\\Astralith\\Textures\\DRUID",
        "Interface\\AddOns\\Astralith\\Textures\\HUNTER",
        "Interface\\AddOns\\Astralith\\Textures\\MAGE",
        "Interface\\AddOns\\Astralith\\Textures\\PALADIN",
        "Interface\\AddOns\\Astralith\\Textures\\PRIEST",
        "Interface\\AddOns\\Astralith\\Textures\\ROGUE",
        "Interface\\AddOns\\Astralith\\Textures\\SHAMAN",
        "Interface\\AddOns\\Astralith\\Textures\\WARLOCK",
        "Interface\\AddOns\\Astralith\\Textures\\WARRIOR",
        "Interface\\AddOns\\Astralith\\Textures\\DRUID2",
        "Interface\\AddOns\\Astralith\\Textures\\HUNTER2",
        "Interface\\AddOns\\Astralith\\Textures\\MAGE2",
        "Interface\\AddOns\\Astralith\\Textures\\PALADIN2",
        "Interface\\AddOns\\Astralith\\Textures\\PRIEST2",
        "Interface\\AddOns\\Astralith\\Textures\\ROGUE2",
        "Interface\\AddOns\\Astralith\\Textures\\SHAMAN2",
        "Interface\\AddOns\\Astralith\\Textures\\WARLOCK2",
        "Interface\\AddOns\\Astralith\\Textures\\WARRIOR2",
        "Interface\\AddOns\\Astralith\\Textures\\DEATHKNIGHT",
        -- Ajoutez d'autres textures ici
    }

    local function CreateTextureButton(texturePath, yOffset)
        local button = CreateFrame("Button", nil, content)
        button:SetSize(300, 50)
        button:SetPoint("TOP", 0, yOffset)

        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(50, 50)
        icon:SetPoint("LEFT", 5, 0)
        icon:SetTexture(texturePath)

        local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        label:SetText(texturePath:match("([^\\]+)$"))

        button:SetScript("OnClick", function()
            Astralith:SendSelectedTexture(texturePath)
            frame:Hide()
        end)
    end

    local yOffset = -10
    for _, texture in ipairs(textures) do
        CreateTextureButton(texture, yOffset)
        yOffset = yOffset - 60
    end

    Astralith.textureSelector = frame
    frame:Show()
end

-- Envoyer la texture sélectionnée à la guilde
function Astralith:SendSelectedTexture(texturePath)
    selectedTexture = texturePath
end

-- Traitement des messages reçus pour changer la texture
local function OnAddonMessage(prefix, text, channel, sender)
    if prefix == ADDON_PREFIX and not IsSelf(sender) then
        local command, name, texturePath = strsplit(",", text)
        if command == "SET_TEXTURE" then
            print(name .. " a sélectionné : " .. texturePath)
            guildMembers[name].icon = texturePath
            Astralith:RefreshPins()
        else
            -- Autres traitements
        end
    end
end

-- Initialisation
Astralith:CreateMinimapButton()

