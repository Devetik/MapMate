-- Importation des bibliothèques nécessaires
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local MapMateUI = {}
_G["MapMateUI"] = MapMateUI

if not MapMateDB then
    MapMateDB = {}
end
local defaultX, defaultY = 0, 0
local function IsLeatrixMapActive()
    return _G["LeaMapsDB"] ~= nil
end

if IsLeatrixMapActive() then
    defaultX, defaultY = 911, 579
else
    defaultX, defaultY = 0.82, 0.067
end

if not MapMateDB.buttonPosition then
    MapMateDB.buttonPosition = { x = defaultX, y = defaultY }
end

-- Paramètres par défaut
local defaults = {
    showRanks = true,
    iconSize = 1.0,
    lockIcon = false,
    displayLevel = true,
    simpleDots = false,
    displayName = false,
    displayHealth = false,
    ignorePlayerOnOtherLayers = false,
    showPlayersLayer = false,
    showPlayersLayerTooltip = true,
    hideMiniMapButton = false,
    enableMinimapPin = true,
    MMIconSize = 1.0,
    simpleDotsMM = false,
    showRanksMM = true,
    showPlayersOnMap = true,
    autoInviteForLayer = true,
    minimap = { x = -70, y = 0, hide = false },
    buttonPosition = { x = defaultX, y = defaultY },
}

-- Initialisation des paramètres sauvegardés
local function InitializeSettings()
    for key, value in pairs(defaults) do
        if MapMateDB[key] == nil then
            MapMateDB[key] = value
        end
    end
end

-- Gestion de l'icône minimap
local minimapButton

-- Fonction pour mettre à jour le statut de verrouillage
local function UpdateMinimapButtonLock()
    if minimapButton then
        minimapButton:SetMovable(not MapMateDB.lockIcon)
    end
end

local function UpdateMinimapButtonVisibility()
    if minimapButton then
        if MapMateDB.hideMiniMapButton then
            minimapButton:Hide()
        else
            minimapButton:Show()
        end
    end
end

-- Création manuelle d'un bouton sur la minimap
local function CreateMinimapButton()
    minimapButton = CreateFrame("Button", "MapMateMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetMovable(true) -- Rendre le bouton déplaçable

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map02")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")

    local pushedTexture = minimapButton:CreateTexture(nil, "OVERLAY")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushedTexture:SetAllPoints()
    minimapButton:SetPushedTexture(pushedTexture)

    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            MapMateUI:ToggleConfigWindow()
        elseif button == "RightButton" then
            print("Right-click on the MapMate icon.")
        end
    end)
    
    -- Ajoutez cette ligne pour enregistrer les clics gauche et droit
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        if not MapMateDB.lockIcon then
            self:StartMoving()
        end
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        MapMateDB.minimap.x = x - mx
        MapMateDB.minimap.y = y - my
    end)

    minimapButton:SetPoint("CENTER", Minimap, "CENTER", MapMateDB.minimap.x, MapMateDB.minimap.y)

    if MapMateDB.hideMiniMapButton then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("MapMate", 1, 1, 1)
        GameTooltip:AddLine("Left Click: Open Custom Settings", 1, 1, 1)
        GameTooltip:AddLine("Right Click: Show Info", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Appliquer le statut initial de verrouillage et de visibilité
    UpdateMinimapButtonVisibility()
    UpdateMinimapButtonLock()
end

local function ResetToDefaults()
    for key, value in pairs(defaults) do
        MapMateDB[key] = value
    end
    print("MapMate settings have been reset to defaults.")
    
    -- Réinitialiser la position du bouton
    MapMateDB.minimap.x = defaults.minimap.x
    MapMateDB.minimap.y = defaults.minimap.y

    MapMateDB.buttonPosition.x = defaults.buttonPosition.x
    MapMateDB.buttonPosition.y = defaults.buttonPosition.y

    -- Appliquer les changements
    UpdateMinimapButtonLock()
    UpdateMinimapButtonVisibility()

    if minimapButton then
        minimapButton:ClearAllPoints()
        minimapButton:SetPoint("CENTER", Minimap, "CENTER", MapMateDB.minimap.x, MapMateDB.minimap.y)
    end
end


local options = {
    name = "|TInterface\\AddOns\\MapMate\\Textures\\GM4:16|t MapMate Options",
    handler = MapMateUI,
    type = "group",
    args = {
        general = {
            type = "group",
            name = "General Settings",
            inline = false,
            order = 1, -- Définit l'ordre du groupe
            args = {
                lockIcon = {
                    type = "toggle",
                    name = MapMate_Localize("Icon Lock"),
                    desc = "Prevent moving the minimap button.",
                    order = 1,
                    get = function() return MapMateDB.lockIcon end,
                    set = function(_, value)
                        MapMateDB.lockIcon = value
                        UpdateMinimapButtonLock()
                    end,
                },
                minimapHide = {
                    type = "toggle",
                    name = MapMate_Localize("Icon Hide"),
                    desc = "Enable or disable the minimap icon.",
                    order = 2,
                    get = function() return MapMateDB.hideMiniMapButton end,
                    set = function(_, value)
                        MapMateDB.hideMiniMapButton = value
                        UpdateMinimapButtonVisibility()
                    end,
                },
            },
        },
        display = {
            type = "group",
            name = "Map Settings",
            inline = false,
            order = 2,
            args = {
                showRanks = {
                    type = "toggle",
                    name = "Show Guild Member Ranks",
                    desc = "Enable or disable showing guild member ranks on the map.",
                    order = 1, -- Définit l'ordre de cet argument
                    get = function() return MapMateDB.showRanks end,
                    set = function(_, value) MapMateDB.showRanks = value end,
                },
                simpleDots = {
                    type = "toggle",
                    name = "Simple Dots",
                    desc = "Enable or disable simplified dot icons.",
                    order = 2,
                    get = function() return MapMateDB.simpleDots end,
                    set = function(_, value) MapMateDB.simpleDots = value end,
                },
                displayLevel = {
                    type = "toggle",
                    name = "Show Levels",
                    desc = "Enable or disable showing player levels.",
                    order = 3,
                    get = function() return MapMateDB.displayLevel end,
                    set = function(_, value) MapMateDB.displayLevel = value end,
                },
                displayName = {
                    type = "toggle",
                    name = "Show Names",
                    desc = "Enable or disable showing player names.",
                    order = 4,
                    get = function() return MapMateDB.displayName end,
                    set = function(_, value) MapMateDB.displayName = value end,
                },
                displayHealth = {
                    type = "toggle",
                    name = "Show Health",
                    desc = "Enable or disable showing player health.",
                    order = 5,
                    get = function() return MapMateDB.displayHealth end,
                    set = function(_, value) MapMateDB.displayHealth = value end,
                },
                iconSize = {
                    type = "range",
                    name = "Icon Size",
                    desc = "Adjust the size of the icons on the map.",
                    order = 6,
                    min = 0.5,
                    max = 2.0,
                    step = 0.1,
                    get = function() return MapMateDB.iconSize end,
                    set = function(_, value) MapMateDB.iconSize = value end,
                },
            },
        },
        displayMM = {
            type = "group",
            name = "MiniMap Settings",
            inline = false,
            order = 3,
            args = {
                enableMinimapPin = {
                    type = "toggle",
                    name = MapMate_Localize("Enable Minimap Pins"),
                    desc = "Enable or disable showing player pins on the minimap.",
                    order = 1,
                    get = function() return MapMateDB.enableMinimapPin end,
                    set = function(_, value) 
                        MapMateDB.enableMinimapPin = value 
                        -- Force une mise à jour de l'interface des options
                        AceConfigRegistry:NotifyChange("MapMate")
                    end,
                },
                enableRank = {
                    type = "toggle",
                    name = MapMate_Localize("Display Rank On MM"),
                    desc = "Enable or disable showing player rank on the minimap.",
                    order = 2,
                    get = function() return MapMateDB.showRanksMM end,
                    set = function(_, value) MapMateDB.showRanksMM = value end,
                    disabled = function() return not MapMateDB.enableMinimapPin end,
                },
                showAsDot = {
                    type = "toggle",
                    name = MapMate_Localize("Simple Dots MM"),
                    desc = "Display players as simple dots on the minimap. Instead of class icons.",
                    order = 3,
                    get = function() return MapMateDB.simpleDotsMM end,
                    set = function(_, value) MapMateDB.simpleDotsMM = value end,
                    disabled = function() return not MapMateDB.enableMinimapPin end,
                },
                MMiconSize = {
                    type = "range",
                    name = MapMate_Localize("MMIcon Size"),
                    desc = "Adjust the size of the icons on the MiniMap.",
                    order = 4,
                    min = 0.5,
                    max = 2.0,
                    step = 0.1,
                    get = function() return MapMateDB.MMIconSize end,
                    set = function(_, value) MapMateDB.MMIconSize = value end,
                    disabled = function() return not MapMateDB.enableMinimapPin end,
                },
            },
        },
        layers = {
            type = "group",
            name = "Layer Settings",
            inline = false,
            order = 4,
            args = {
                ignorePlayerOnOtherLayers = {
                    type = "toggle",
                    name = "Ignore Players on Other Layers",
                    desc = "Enable or disable ignoring players on other layers.",
                    order = 1,
                    get = function() return MapMateDB.ignorePlayerOnOtherLayers end,
                    set = function(_, value) MapMateDB.ignorePlayerOnOtherLayers = value end,
                },
                showPlayersLayer = {
                    type = "toggle",
                    name = "Show Player Layers",
                    desc = "Enable or disable showing player layers.",
                    order = 2,
                    get = function() return MapMateDB.showPlayersLayer end,
                    set = function(_, value) MapMateDB.showPlayersLayer = value end,
                },
                showPlayersLayerTooltip = {
                    type = "toggle",
                    name = "Show Layer Tooltips",
                    desc = "Enable or disable showing tooltips for player layers.",
                    order = 3,
                    get = function() return MapMateDB.showPlayersLayerTooltip end,
                    set = function(_, value) MapMateDB.showPlayersLayerTooltip = value end,
                },
            },
        },
        reset = {
            type = "execute",
            name = "Reset to Defaults",
            desc = "Reset all settings to their default values.",
            order = 99, -- Place le bouton à la fin
            func = function()
                ResetToDefaults()
            end,
        
        },
    },
}


AceConfig:RegisterOptionsTable("MapMate", options)
AceConfigDialog:AddToBlizOptions("MapMate", "|TInterface\\AddOns\\MapMate\\Textures\\GM4:16|t MapMate")

-- Gestion de la fenêtre de configuration personnalisée
local configFrame
function MapMateUI:ToggleConfigWindow()
    if configFrame and configFrame:IsShown() then
        configFrame:Hide()
    else
        MapMateUI:ShowConfigWindow()
    end
end

-- Stockage des widgets dépendants
MapMateUI.widgets = {}

-- Fonction pour mettre à jour l'état des options dépendantes
local function UpdateDependentOptions()
    if MapMateUI.widgets.simpleDotsMM then
        MapMateUI.widgets.simpleDotsMM:SetDisabled(not MapMateDB.enableMinimapPin)
    end
    if MapMateUI.widgets.showRanksMM then
        MapMateUI.widgets.showRanksMM:SetDisabled(not MapMateDB.enableMinimapPin)
    end
    if MapMateUI.widgets.MMiconSizeSlider then
        MapMateUI.widgets.MMiconSizeSlider:SetDisabled(not MapMateDB.enableMinimapPin)
    end
end

-- Affichage de la fenêtre de paramètres
function MapMateUI:ShowConfigWindow()
    if configFrame then
        configFrame:Show()
        return
    end

    configFrame = AceGUI:Create("Frame")
    configFrame:SetTitle("|TInterface\\AddOns\\MapMate\\Textures\\GM4:16|t       MapMate      |TInterface\\AddOns\\MapMate\\Textures\\GM4:16|t")
    configFrame:SetStatusText(MapMate_Localize("Edit Parameters"))
    configFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        configFrame = nil
    end)
    configFrame:SetLayout("List")

    configFrame:SetWidth(400)
    configFrame:SetHeight(600)

    -- Ajout d'un séparateur pour le general
    local titleGHeading = AceGUI:Create("Heading")
    titleGHeading:SetText(MapMate_Localize("General Settings")) -- ToDo
    titleGHeading:SetFullWidth(true) -- Le titre occupe toute la largeur
    configFrame:AddChild(titleGHeading)

    --------------------------------------------------
    -- Conteneur pour aligner les éléments côte à côte
    local generalSettingsGroup = AceGUI:Create("SimpleGroup")
    generalSettingsGroup:SetFullWidth(true)
    generalSettingsGroup:SetLayout("Flow") -- Permet de disposer les enfants en ligne

    -- Ajout de lockButton
    local lockButton = AceGUI:Create("CheckBox")
    lockButton:SetLabel(MapMate_Localize("Icon Lock"))
    lockButton:SetValue(MapMateDB.lockIcon)
    lockButton:SetWidth(180) -- Largeur pour contrôler l'espace
    lockButton:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.lockIcon = value
        UpdateMinimapButtonLock()
    end)
    generalSettingsGroup:AddChild(lockButton)

    -- Ajout de hideButton
    local hideButton = AceGUI:Create("CheckBox")
    hideButton:SetLabel(MapMate_Localize("Icon Hide"))
    hideButton:SetValue(MapMateDB.hideMiniMapButton)
    hideButton:SetWidth(180) -- Largeur pour contrôler l'espace
    hideButton:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.hideMiniMapButton = value
        UpdateMinimapButtonVisibility()
    end)
    generalSettingsGroup:AddChild(hideButton)
    -- Ajouter le conteneur au frame principal
    configFrame:AddChild(generalSettingsGroup)
    -- Fin de conteneur
    ------------------------------------------------------


    -- Ajout d'un séparateur pour la map
    local titleMapHeading = AceGUI:Create("Heading")
    titleMapHeading:SetText(MapMate_Localize("Map Settings")) -- ToDo
    titleMapHeading:SetFullWidth(true) -- Le titre occupe toute la largeur
    configFrame:AddChild(titleMapHeading)

    local showRanksCheckbox = AceGUI:Create("CheckBox")
    showRanksCheckbox:SetLabel(MapMate_Localize("Show Guild Member Rank"))
    showRanksCheckbox:SetFullWidth(true)
    showRanksCheckbox:SetValue(MapMateDB.showRanks)
    showRanksCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showRanks = value
    end)
    configFrame:AddChild(showRanksCheckbox)

    local simpleDots = AceGUI:Create("CheckBox")
    simpleDots:SetLabel(MapMate_Localize("Simple Dots"))
    simpleDots:SetFullWidth(true)
    simpleDots:SetValue(MapMateDB.simpleDots)
    simpleDots:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.simpleDots = value
    end)
    configFrame:AddChild(simpleDots)

    -- Display Level checkbox
    local displayLevel = AceGUI:Create("CheckBox")
    displayLevel:SetLabel(MapMate_Localize("Show Guild Member Level"))
    displayLevel:SetValue(MapMateDB.displayLevel)
    displayLevel:SetFullWidth(true)
    displayLevel:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.displayLevel = value
    end)
    configFrame:AddChild(displayLevel)
    
    -- Display Name checkbox
    local displayName = AceGUI:Create("CheckBox")
    displayName:SetLabel(MapMate_Localize("displayName"))
    displayName:SetValue(MapMateDB.displayName)
    displayName:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.displayName = value
    end)
    configFrame:AddChild(displayName)
        
    -- Display Health checkbox
    local displayHealth = AceGUI:Create("CheckBox")
    displayHealth:SetLabel(MapMate_Localize("displayHealth"))
    displayHealth:SetValue(MapMateDB.displayHealth)
    displayHealth:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.displayHealth = value
    end)
    configFrame:AddChild(displayHealth)

    local iconSizeSlider = AceGUI:Create("Slider")
    iconSizeSlider:SetLabel(MapMate_Localize("Icon Size"))
    iconSizeSlider:SetSliderValues(25, 200, 1)
    iconSizeSlider:SetValue(MapMateDB.iconSize * 100)
    iconSizeSlider:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.iconSize = value / 100
    end)
    configFrame:AddChild(iconSizeSlider)

    -- Ajout d'un séparateur pour la minimap
    local titleMMHeading = AceGUI:Create("Heading")
    titleMMHeading:SetText(MapMate_Localize("Minimap Settings")) -- ToDo
    titleMMHeading:SetFullWidth(true) -- Le titre occupe toute la largeur
    configFrame:AddChild(titleMMHeading)


    -- Checkbox principale pour activer/désactiver les pins de la minimap
    local enableMinimapPin = AceGUI:Create("CheckBox")
    enableMinimapPin:SetLabel(MapMate_Localize("Enable Minimap Pins"))
    enableMinimapPin:SetFullWidth(true)
    enableMinimapPin:SetValue(MapMateDB.enableMinimapPin)
    enableMinimapPin:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.enableMinimapPin = value
        UpdateDependentOptions() -- Met à jour immédiatement les dépendances
    end)
    configFrame:AddChild(enableMinimapPin)

    -- Checkbox dépendante
    local showRanksMM = AceGUI:Create("CheckBox")
    showRanksMM:SetLabel(MapMate_Localize("Display Rank On MM"))
    showRanksMM:SetValue(MapMateDB.showRanksMM)
    showRanksMM:SetFullWidth(true)
    showRanksMM:SetDisabled(not MapMateDB.enableMinimapPin) -- Initialement désactivée si nécessaire
    showRanksMM:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showRanksMM = value
    end)
    configFrame:AddChild(showRanksMM)

    local simpleDotsMM = AceGUI:Create("CheckBox")
    simpleDotsMM:SetLabel(MapMate_Localize("Simple Dots MM"))
    simpleDotsMM:SetValue(MapMateDB.simpleDotsMM)
    simpleDotsMM:SetFullWidth(true)
    simpleDotsMM:SetDisabled(not MapMateDB.enableMinimapPin) -- Initialement désactivée si nécessaire
    simpleDotsMM:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.simpleDotsMM = value
    end)
    configFrame:AddChild(simpleDotsMM)

    local MMiconSizeSlider = AceGUI:Create("Slider")
    MMiconSizeSlider:SetLabel(MapMate_Localize("MMIcon Size"))
    MMiconSizeSlider:SetSliderValues(25, 200, 1)
    MMiconSizeSlider:SetValue(MapMateDB.MMIconSize * 100)
    MMiconSizeSlider:SetDisabled(not MapMateDB.enableMinimapPin) -- Initialement désactivée si nécessaire
    MMiconSizeSlider:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.MMIconSize = value / 100
    end)
    configFrame:AddChild(MMiconSizeSlider)

    -- Ajout d'un séparateur pour les layers
    local titleHeading = AceGUI:Create("Heading")
    titleHeading:SetText(MapMate_Localize("Layers Settings"))
    titleHeading:SetFullWidth(true) -- Le titre occupe toute la largeur
    configFrame:AddChild(titleHeading)

    --Message d'avertissement
    local yellowText = AceGUI:Create("Label")
    yellowText:SetText(MapMate_Localize("NWB_Warning"))
    yellowText:SetFullWidth(true) -- S'étend sur toute la largeur du conteneur
    yellowText:SetColor(1, 1, 0) -- Définit la couleur en jaune (RVB : Rouge, Vert, Bleu)
    configFrame:AddChild(yellowText)

    local ignorePlayerOnOtherLayers = AceGUI:Create("CheckBox")
    ignorePlayerOnOtherLayers:SetLabel(MapMate_Localize("ignorePlayerOnOtherLayers"))
    ignorePlayerOnOtherLayers:SetValue(MapMateDB.ignorePlayerOnOtherLayers)
    ignorePlayerOnOtherLayers:SetFullWidth(true)
    ignorePlayerOnOtherLayers:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.ignorePlayerOnOtherLayers = value
    end)
    configFrame:AddChild(ignorePlayerOnOtherLayers)

    local showPlayersLayer = AceGUI:Create("CheckBox")
    showPlayersLayer:SetLabel(MapMate_Localize("showPlayersLayer"))
    showPlayersLayer:SetValue(MapMateDB.showPlayersLayer)
    showPlayersLayer:SetFullWidth(true)
    showPlayersLayer:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showPlayersLayer = value
    end)
    configFrame:AddChild(showPlayersLayer)

    local showPlayersLayerTooltip = AceGUI:Create("CheckBox")
    showPlayersLayerTooltip:SetLabel(MapMate_Localize("showPlayersLayerTooltip"))
    showPlayersLayerTooltip:SetValue(MapMateDB.showPlayersLayerTooltip)
    showPlayersLayerTooltip:SetFullWidth(true)
    showPlayersLayerTooltip:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showPlayersLayerTooltip = value
    end)
    configFrame:AddChild(showPlayersLayerTooltip)

    MapMateUI.widgets.simpleDotsMM = simpleDotsMM
    MapMateUI.widgets.MMiconSizeSlider = MMiconSizeSlider
    MapMateUI.widgets.showRanksMM = showRanksMM
    UpdateDependentOptions()
end

-- Initialisation de l'addon
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    InitializeSettings()
    CreateMinimapButton()
    print("MapMate loaded! Use /mapmate to configure options.")
end)

-- Ajout de la commande /mapmate pour ouvrir la fenêtre de configuration
SLASH_MAPMATE1 = "/mapmate"
SlashCmdList["MAPMATE"] = function()
    MapMateUI:ToggleConfigWindow()
end
