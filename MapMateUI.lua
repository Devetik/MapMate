local MapMateUI = {}
_G["MapMateUI"] = MapMateUI
local AceGUI = LibStub("AceGUI-3.0")

if not MapMateDB then
    MapMateDB = {}
end

-- Paramètres par défaut
local defaults = {
    showRanks = true,
    iconSize = 1.0, -- Taille par défaut en ratio
    minimap = { x = 0, y = 0, hide = false }
}

-- Variable pour la fenêtre de configuration
local configFrame

-- Fonction pour initialiser les paramètres sauvegardés
local function InitializeSettings()
    for key, value in pairs(defaults) do
        if MapMateDB[key] == nil then
            MapMateDB[key] = value
        end
    end
end

-- Création manuelle d'un bouton sur la minimap
local function CreateMinimapButton()
    -- Frame de l'icône
    local minimapButton = CreateFrame("Button", "MapMateMinimapButton", Minimap)
    minimapButton:SetSize(32, 32) -- Taille du bouton
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    
    -- Texture de l'icône
    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map02")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    
    -- Texture pour l'effet "pushed" (quand le bouton est cliqué)
    local pushedTexture = minimapButton:CreateTexture(nil, "OVERLAY")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushedTexture:SetAllPoints()
    minimapButton:SetPushedTexture(pushedTexture)
    
    -- Fonctionnalité de clic
    minimapButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            MapMateUI:ToggleConfigWindow()
        elseif button == "RightButton" then
            print("Clic droit sur l'icône MapMate.")
        end
    end)
    
    -- Déplacement manuel de l'icône
    minimapButton:SetMovable(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    minimapButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Sauvegarder la position
        local x, y = self:GetCenter()
        local mx, my = Minimap:GetCenter()
        MapMateDB.minimap.x = x - mx
        MapMateDB.minimap.y = y - my
    end)
    
    -- Initialiser la position
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", MapMateDB.minimap.x, MapMateDB.minimap.y)
    
    -- Gestion de la visibilité
    if MapMateDB.minimap.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
    end
    
    -- Ajouter un tooltip
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
    
    -- Création de la fenêtre
    configFrame = AceGUI:Create("Frame")
    configFrame:SetTitle("Paramètres MapMate")
    configFrame:SetStatusText("Modifiez les paramètres ci-dessous")
    configFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        configFrame = nil
    end)
    configFrame:SetLayout("List")

    configFrame:SetWidth(300)  -- Largeur en pixels
    configFrame:SetHeight(300) -- Hauteur en pixels

    -- Case à cocher pour afficher les rangs
    local showRanksCheckbox = AceGUI:Create("CheckBox")
    showRanksCheckbox:SetLabel("Afficher les rangs de la guilde")
    showRanksCheckbox:SetValue(MapMateDB.showRanks)
    showRanksCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.showRanks = value
        --print("Afficher les rangs de la guilde :", value and "Activé" or "Désactivé")
    end)
    configFrame:AddChild(showRanksCheckbox)

    -- Slider pour définir la taille des icônes
    local iconSizeSlider = AceGUI:Create("Slider")
    iconSizeSlider:SetLabel("Taille des icônes (%)")
    iconSizeSlider:SetSliderValues(25, 200, 1)
    iconSizeSlider:SetValue(MapMateDB.iconSize * 100)
    iconSizeSlider:SetCallback("OnValueChanged", function(_, _, value)
        MapMateDB.iconSize = value / 100
        --print("Nouvelle taille des icônes :", value .. "%")
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
