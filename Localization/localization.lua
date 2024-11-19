-- Détecte la langue locale
local L = {}
local locale = GetLocale()

-- Traductions en anglais (par défaut)
L["MapMate"] = "MapMate"
L["Welcome to MapMate!"] = "Welcome to MapMate!"
L["Show Guild Member Rank"] = "Show Guild Member Rank"
L["Show Guild Member Level"] = "Show Guild Member Level"
L["Icon Lock"] = "Lock Icon"
L["Invite"] = "Invite"
L["Wisper"] = "Whisper"
L["Cancel"] = "Cancel"
L["Icon Size"] = "Icon Size (%)"
L["MapMate Parameter"] = "MapMate Parameter"
L["Edit Parameters"] = "Edit Parameters"
L["Left Click"] = "Left click to open/close parameters."
L["Simple Dots"] = "Show players as simple dots"
L["displayName"] = "Show players name"
L["displayHealth"] = "Show players health"

-- Traductions en français
if locale == "frFR" then
    L["MapMate"] = "MapMate"
    L["Welcome to MapMate!"] = "Bienvenue sur MapMate !"
    L["Show Guild Member Rank"] = "Afficher du rang des membres de la guilde"
    L["Show Guild Member Level"] = "Afficher le niveau des membres de la guilde"
    L["Icon Lock"] = "Verrouiller l'icône"
    L["Invite"] = "Inviter"
    L["Wisper"] = "Chuchoter"
    L["Cancel"] = "Annuler"
    L["Icon Size"] = "Taille des icônes (%)"
    L["MapMate Parameter"] = "Paramètres de MapMate"
    L["Edit Parameters"] = "Modifier les paramètres"
    L["Left Click"] = "Clic gauche : Ouvrir/fermer les paramètres."
    L["Simple Dots"] = "Afficher les joueurs sous forme de points"
    L["displayName"] = "Afficher le nom des joueurs"
    L["displayHealth"] = "Afficher la vie des joueurs"
end

-- Fonction globale pour accéder aux traductions
function MapMate_Localize(key)
    return L[key] or key
end
