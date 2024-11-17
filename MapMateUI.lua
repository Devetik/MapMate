local MapMateUI = {}
_G["MapMateUI"] = MapMateUI
local AceGUI = LibStub("AceGUI-3.0")

if not MapMateDB then
    MapMateDB = {}
end

-- Paramètres par défaut
local defaults = {
    showRanks = true,
    iconSize = 1.0,
    lockIcon = false,
    displayLevel = true,
    minimap = { x = 0, y = 0, hide = false }
}

-- Variable pour la fenêtre de configuration
local configFrame
local minimapButton -- Variable globale pour le bouton minimap

-- Fonction pour initialiser les paramètres sauvegardés
local function InitializeSettings()
    for key, value in pairs(defaults) do
        if MapMateDB[key] == nil then
            MapMateDB[key] = value
        end
    end
end

-- Fonction pour mettre à jour le statut de verrouillage de l'icône
local function UpdateMinimapButtonLock()
    if minimapButton then
        minimapButton:SetMovable(not MapMateDB.lockIcon)
        print(MapMateDB.lockIcon and "Icône verrouillée." or "Icône déverrouillée.")
    end
end

-- Création manuelle d'un bouton sur la minimap
local function CreateMinimapButton()
    minimapButton = CreateFrame("Button", "MapMateMinimapButton", Minimap)
    minimapButton:SetSize(32, 32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)

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
            print("Clic droit sur l'icône MapMate.")
        end
    end)

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

    if MapMateDB.minimap.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("MapMate", 1, 1, 1)
        GameTooltip:AddLine("Clic gauche : Ouvrir/fermer les paramètres.", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : Options supplémentaires.", 1, 1, 1)
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Appliquer le statut initial de verrouillage
    UpdateMinimapButtonLock()
end

-- Gestion de l'ouverture et fermeture de la fenêtre
function MapMateUI:ToggleConfigWindow()
    if configFrame and configFrame:IsShown() then
        configFrame:Hide()
    else
        self:ShowConfigWindow()
    end
end

-- Affichage de la fenêtre de paramètres
function MapMateUI:ShowConfigWindow()
    if configFrame then
        configFrame:Show()
        return
    end

    configFrame = AceGUI:Create("Frame")
    configFrame:SetTitle("Paramètres MapMate")
    configFrame:SetStatusText("Modifiez les paramètres ci-dessous")
    configFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        configFrame = nil
    end)
    configFrame:SetLayout("List")

    configFrame:SetWidth(300)
    configFrame:SetHeight(300)

    local showRanksCheckbox = AceGUI:Create("CheckBox")
    showRanksCheckbox:SetLabel("Afficher les rangs de la guilde")
    showRanksCheckbox:SetValue(MapMateDB.showRanks)
    showRanksCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showRanks = value
    end)
    configFrame:AddChild(showRanksCheckbox)

    local displayLevel = AceGUI:Create("CheckBox")
    displayLevel:SetLabel("Affiche le niveau des joueurs")
    displayLevel:SetValue(MapMateDB.displayLevel)
    displayLevel:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.displayLevel = value
    end)
    configFrame:AddChild(displayLevel)

    local lockButton = AceGUI:Create("CheckBox")
    lockButton:SetLabel("Lock l'icône")
    lockButton:SetValue(MapMateDB.lockIcon)
    lockButton:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.lockIcon = value
        UpdateMinimapButtonLock() -- Met à jour le statut de verrouillage
    end)
    configFrame:AddChild(lockButton)

    local iconSizeSlider = AceGUI:Create("Slider")
    iconSizeSlider:SetLabel("Taille des icônes (%)")
    iconSizeSlider:SetSliderValues(25, 200, 1)
    iconSizeSlider:SetValue(MapMateDB.iconSize * 100)
    iconSizeSlider:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.iconSize = value / 100
    end)
    configFrame:AddChild(iconSizeSlider)
end

-- Fonction d'initialisation
function MapMateUI:Initialize()
    InitializeSettings()
    CreateMinimapButton()
end

-- Gestionnaire d'événements
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "MapMate" then
        MapMateUI:Initialize()
    end
end)
