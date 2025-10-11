------------------------------------------------------------------------------------------------------
-- Necrosis LdC
--
-- Créateur initial (US) : Infernal (http://www.revolvus.com/games/interface/necrosis/)
-- Implémentation de base (FR) : Tilienna Thorondor
-- Reprise du projet : Lomig & Nyx des Larmes de Cenarius, Kael'Thas
--
-- Skins et voix Françaises : Eliah, Ner'zhul
-- Version Allemande par Arne Meier et Halisstra, Lothar
-- Remerciements spéciaux pour Sadyre (JoL)
-- Version 05.09.2006-1
------------------------------------------------------------------------------------------------------

-- Configuration par défaut
-- Se charge en cas d'absence de configuration ou de changement de version
Default_NecrosisConfig = {
	Version = NecrosisData.Version,
	SoulshardContainer = 4,
	SoulshardSort = false,
	SoulshardDestroy = false,
	ShadowTranceAlert = true,
	ShowSpellTimers = true,
	AntiFearAlert = true,
	NecrosisLockServ = true,
	NecrosisAngle = 180,
	StonePosition = { true, true, true, true, true, true, true, true },
	NecrosisToolTip = true,
	NoDragAll = false,
	PetMenuPos = 34,
	BuffMenuPos = 34,
	CurseMenuPos = 34,
	StoneMenuPos = 34,
	ChatMsg = true,
	ChatType = true,
	ShowCount = true,
	CountType = 1,
	ShadowTranceScale = 100,
	NecrosisButtonScale = 90,
	NecrosisColor = "Rose",
	Sound = true,
	SpellTimerPos = 1,
	SpellTimerJust = "LEFT",
	Circle = 1,
	Graphical = true,
	Yellow = true,
	SensListe = 1,
	PetName = {
		[1] = " ",
		[2] = " ",
		[3] = " ",
		[4] = " ",
	},
	DominationUp = false,
	AmplifyUp = false,
	SM = false,
	SteedSummon = false,
	DemonSummon = true,
	BanishScale = 100,
	LastStone = "",
}

NecrosisConfig = {}
local Debug = false
local Loaded = false

-- Détection des initialisations du mod
local NecrosisRL = true

-- Grouped state: Spell casting tracking (reduced upvalue count)
local SpellCast = {
	Name = nil,
	Rank = nil,
	TargetName = nil,
	TargetLevel = nil,
	Time = 0,
}

-- Initialisation des tableaux gérant les Timers
-- Un pour les sorts à timer, l'autre pour les groupes de mobs
-- Le dernier permet l'association d'un timer à une frame graphique
SpellTimer = {}
local SpellGroup = {
	Name = { "Rez", "Main", "Cooldown" },
	SubName = { " ", " ", " " },
	Visible = { true, true, true },
}

-- Reusable buffers for graphical timers (avoid per-frame allocations)
local GraphicalTimer = {
	texte = {},
	TimeMax = {},
	Time = {},
	titre = {},
	temps = {},
	Gtimer = {},
}

-- Clears GraphicalTimer arrays for reuse
local function ClearGraphicalTimers()
	-- Remove all elements from each array to properly reset their lengths
	while table.getn(GraphicalTimer.texte) > 0 do
		table.remove(GraphicalTimer.texte)
	end
	while table.getn(GraphicalTimer.TimeMax) > 0 do
		table.remove(GraphicalTimer.TimeMax)
	end
	while table.getn(GraphicalTimer.Time) > 0 do
		table.remove(GraphicalTimer.Time)
	end
	while table.getn(GraphicalTimer.titre) > 0 do
		table.remove(GraphicalTimer.titre)
	end
	while table.getn(GraphicalTimer.temps) > 0 do
		table.remove(GraphicalTimer.temps)
	end
	while table.getn(GraphicalTimer.Gtimer) > 0 do
		table.remove(GraphicalTimer.Gtimer)
	end
end

local TimerTable = {}
for i = 1, 50, 1 do
	TimerTable[i] = false
end

-- Grouped state: Menu system (reduced upvalue count)
local MenuState = {
	-- Pet menu
	PetShow = false,
	PetMenuShow = false,
	AlphaPetMenu = 1,
	AlphaPetVar = 0,
	PetVisible = false,

	-- Buff menu
	BuffShow = false,
	BuffMenuShow = false,
	AlphaBuffMenu = 1,
	AlphaBuffVar = 0,
	BuffVisible = false,

	-- Curse menu
	CurseShow = false,
	CurseMenuShow = false,
	AlphaCurseMenu = 1,
	AlphaCurseVar = 0,
	CurseVisible = false,

	-- Stone menu
	StoneMenuShow = false,
	StoneShow = false,
	AlphaStoneMenu = 1,
	AlphaStoneVar = 0,
	StoneVisible = false,

	-- Last cast tracking
	LastDemon = 0,
	LastBuff = 0,
	LastCurse = 0,
	LastCurseClick = "LeftButton",
}

-- Liste des boutons disponible pour le démoniste dans chaque menu
local PetMenuCreate = {}
local BuffMenuCreate = {}
local StoneMenuCreate = {}
local CurseMenuCreate = {}

-- Grouped state: Mount tracking (reduced upvalue count)
local MountState = {
	Available = false,
	Mounted = false,
	TellMounted = true,
}

local PlayerCombat = false

-- Grouped state: Shadow Trance and Anti-Fear (reduced upvalue count)
local BuffAlert = {
	-- Shadow Trance
	ShadowTrance = false,
	ShadowTranceID = -1,

	-- Anti-Fear
	AntiFearInUse = false,
	AFCurrentTargetImmune = false,
	AFBlink1 = 0,
	AFBlink2 = 0,
	AFImageType = { "", "Immu", "Prot" },
}

-- Grouped state: Soul Shard tracking (reduced upvalue count)
local ShardState = {
	Count = 0,
	Slot = {},
	SlotID = 1,
	MP = 0,
	Time = 0,
}

-- Variables utilisées pour la gestion des composants d'invocation
-- (principalement comptage)
local InfernalStone = 0
local DemoniacStone = 0

-- Variables utilisées pour la gestion des boutons d'invocation et d'utilisation des pierres
-- [1]=Soulstone, [2]=Healthstone, [3]=Spellstone, [4]=Firestone, [5]=Felstone, [6]=Wrathstone, [7]=Voidstone
local StoneIndexToNameTable =
	{ "Soulstone", "Healthstone", "Spellstone", "Firestone", "Felstone", "Wrathstone", "Voidstone" }
local StoneIDInSpellTable = { 0, 0, 0, 0, 0, 0, 0 }
local ItemswitchLocation = { nil, nil }
local ItemOnHand = false

-- Stone data organized by stone type
local Stones = {
	Soulstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
		UsedOnTarget = false,
		Waiting = false,
		Cooldown = false,
		Advice = false,
		Target = "",
	},
	Healthstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Spellstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Firestone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Felstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Wrathstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Voidstone = {
		OnHand = false,
		Location = { nil, nil },
		Mode = 1,
	},
	Hearthstone = {
		OnHand = false,
		Location = { nil, nil },
	},
}

-- Variables utilisées dans la gestion des démons
local DemonType = nil
local DemonEnslaved = false

-- Grouped state: Trading system (reduced upvalue count)
local TradeState = {
	Request = false,
	Trading = false,
	TradingNow = 0,
}

-- Gestion des sacs à fragment d'âme
local BagIsSoulPouch = { nil, nil, nil, nil, nil }

-- Variable contenant les derniers messages invoqués
local PetMess = 0
local SteedMess = 0
local RezMess = 0
local TPMess = 0

-- Permet la gestion des tooltips dans Necrosis (sans la frame des pièces de monnaie)
local lOriginal_GameTooltip_ClearMoney

local Necrosis_In = true

------------------------------------------------------------------------------------------------------
-- FONCTIONS NECROSIS APPLIQUEES A L'ENTREE DANS LE JEU
------------------------------------------------------------------------------------------------------

function Necrosis_DebugSoulstoneTimer()
	local start = GetTime()
	local duration = 10
	SpellGroup, SpellTimer, TimerTable =
		Necrosis_InsertTimerStone("Soulstone", start, duration, SpellGroup, SpellTimer, TimerTable)
end

-- Fonction appliquée au chargement
function Necrosis_OnLoad()
	-- Permet de repérer les sorts lancés
	Necrosis_Hook("UseAction", "Necrosis_UseAction", "before")
	Necrosis_Hook("CastSpell", "Necrosis_CastSpell", "before")
	Necrosis_Hook("CastSpellByName", "Necrosis_CastSpellByName", "before")

	-- Enregistrement des événements interceptés par Necrosis
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
	this:RegisterEvent("PLAYER_LEAVING_WORLD")
	NecrosisButton:RegisterEvent("BAG_UPDATE")
	NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
	NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
	NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA")
	NecrosisButton:RegisterEvent("PLAYER_REGEN_DISABLED")
	NecrosisButton:RegisterEvent("PLAYER_REGEN_ENABLED")
	NecrosisButton:RegisterEvent("UNIT_PET")
	NecrosisButton:RegisterEvent("SPELLCAST_START")
	NecrosisButton:RegisterEvent("SPELLCAST_FAILED")
	NecrosisButton:RegisterEvent("SPELLCAST_INTERRUPTED")
	NecrosisButton:RegisterEvent("SPELLCAST_STOP")
	NecrosisButton:RegisterEvent("LEARNED_SPELL_IN_TAB")
	NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
	NecrosisButton:RegisterEvent("PLAYER_TARGET_CHANGED")
	NecrosisButton:RegisterEvent("TRADE_REQUEST")
	NecrosisButton:RegisterEvent("TRADE_REQUEST_CANCEL")
	NecrosisButton:RegisterEvent("TRADE_SHOW")
	NecrosisButton:RegisterEvent("TRADE_CLOSED")

	-- Enregistrement des composants graphiques
	NecrosisButton:RegisterForDrag("LeftButton")
	NecrosisButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	NecrosisButton:SetFrameLevel(1)

	-- Enregistrement de la commande console
	SlashCmdList["NecrosisCommand"] = Necrosis_SlashHandler
	SLASH_NecrosisCommand1 = "/necro"
end

-- Fonction appliquée une fois les paramètres des mods chargés
function Necrosis_LoadVariables()
	if Loaded or UnitClass("player") ~= NECROSIS_UNIT_WARLOCK then
		return
	end

	Necrosis_Initialize()
	Loaded = true

	-- Détection du type de démon présent à la connexion
	DemonType = UnitCreatureFamily("pet")
end

------------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
------------------------------------------------------------------------------------------------------

local function SetStoneMenuTexturesForMenuOpen()
	if NecrosisConfig.LastStone ~= "" then
		NecrosisStoneMenuButton:SetNormalTexture(
			"Interface\\AddOns\\Necrosis\\UI\\" .. NecrosisConfig.LastStone .. "Button-03"
		)
	end
end

local function ApplyStoneTextureToStoneMenuButton(stoneType)
	if MenuState.StoneMenuShow then
		SetStoneMenuTexturesForMenuOpen()
	else
		if Stones[stoneType].OnHand then
			NecrosisStoneMenuButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\" .. stoneType .. "Button-02")
		else
			NecrosisStoneMenuButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\" .. stoneType .. "Button-01")
		end
		NecrosisStoneMenuButton:SetHighlightTexture("Interface\\AddOns\\Necrosis\\UI\\" .. stoneType .. "Button-03", "BLEND")
	end
end

local function SetStoneMenuTextures()
	if NecrosisConfig.LastStone ~= "" then
		ApplyStoneTextureToStoneMenuButton(NecrosisConfig.LastStone)
	end
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS NECROSIS
------------------------------------------------------------------------------------------------------

local textTimersDisplay = ""

-- Fonction lancée à la mise à jour de l'interface (main) -- toutes les 0,1 secondes environ
function Necrosis_OnUpdate()
	-- La fonction n'est utilisée que si Necrosis est initialisé et le joueur un Démoniste --
	if (not Loaded) and UnitClass("player") ~= NECROSIS_UNIT_WARLOCK then
		return
	end
	-- La fonction n'est utilisée que si Necrosis est initialisé et le joueur un Démoniste --

	-- Gestion des fragments d'âme : Tri des fragment toutes les secondes
	local curTime = GetTime()
	if (curTime - ShardState.Time) >= 1 then
		ShardState.Time = curTime
		if ShardState.MP > 0 then
			Necrosis_SoulshardSwitch("MOVE")
		end
	end

	----------------------------------------------------------
	-- Gestion des sorts du Démoniste
	----------------------------------------------------------

	-- Gestion du menu d'invocation des démons
	if MenuState.PetShow then
		if curTime >= MenuState.AlphaPetVar and MenuState.AlphaPetMenu > 0 and not MenuState.PetVisible then
			MenuState.AlphaPetVar = curTime + 0.1
			NecrosisPetMenu1:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu2:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu3:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu4:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu5:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu6:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu7:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu8:SetAlpha(MenuState.AlphaPetMenu)
			NecrosisPetMenu9:SetAlpha(MenuState.AlphaPetMenu)
			MenuState.AlphaPetMenu = MenuState.AlphaPetMenu - 0.1
		end
		if MenuState.AlphaPetMenu <= 0 then
			Necrosis_PetMenu()
		end
	end

	-- Gestion du menu des Buffs
	if MenuState.BuffShow then
		if curTime >= MenuState.AlphaBuffVar and MenuState.AlphaBuffMenu > 0 and not MenuState.BuffVisible then
			MenuState.AlphaBuffVar = curTime + 0.1
			NecrosisBuffMenu1:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu2:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu3:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu4:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu5:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu6:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu7:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu8:SetAlpha(MenuState.AlphaBuffMenu)
			NecrosisBuffMenu9:SetAlpha(MenuState.AlphaBuffMenu)
			MenuState.AlphaBuffMenu = MenuState.AlphaBuffMenu - 0.1
		end
		if MenuState.AlphaBuffMenu <= 0 then
			Necrosis_BuffMenu()
		end
	end

	-- Gestion du menu des Curses
	if MenuState.CurseShow then
		if curTime >= MenuState.AlphaCurseVar and MenuState.AlphaCurseMenu > 0 and not MenuState.CurseVisible then
			MenuState.AlphaCurseVar = curTime + 0.1
			NecrosisCurseMenu1:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu2:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu3:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu4:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu5:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu6:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu7:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu8:SetAlpha(MenuState.AlphaCurseMenu)
			NecrosisCurseMenu9:SetAlpha(MenuState.AlphaCurseMenu)
			MenuState.AlphaCurseMenu = MenuState.AlphaCurseMenu - 0.1
		end
		if MenuState.AlphaCurseMenu <= 0 then
			Necrosis_CurseMenu()
		end
	end

	-- Gestion du menu des Stones
	if MenuState.StoneShow then
		if curTime >= MenuState.AlphaStoneVar and MenuState.AlphaStoneMenu > 0 and not MenuState.StoneVisible then
			MenuState.AlphaStoneVar = curTime + 0.1
			NecrosisStoneMenu1:SetAlpha(MenuState.AlphaStoneMenu)
			NecrosisStoneMenu2:SetAlpha(MenuState.AlphaStoneMenu)
			NecrosisStoneMenu3:SetAlpha(MenuState.AlphaStoneMenu)
			NecrosisStoneMenu4:SetAlpha(MenuState.AlphaStoneMenu)
			MenuState.AlphaStoneMenu = MenuState.AlphaStoneMenu - 0.1
		end
		if MenuState.AlphaStoneMenu <= 0 then
			Necrosis_StoneMenu()
		end
	end

	-- Gestion du talent "Crépuscule"
	if NecrosisConfig.ShadowTranceAlert then
		local Actif = false
		local TimeLeft = 0
		Necrosis_UnitHasTrance()
		if BuffAlert.BuffAlert.ShadowTranceID ~= -1 then
			Actif = true
		end
		if Actif and not BuffAlert.BuffAlert.ShadowTrance then
			BuffAlert.BuffAlert.ShadowTrance = true
			Necrosis_Msg(NECROSIS_NIGHTFALL_TEXT.Message, "USER")
			if NecrosisConfig.Sound then
				PlaySoundFile(NECROSIS_SOUND.BuffAlert.ShadowTrance)
			end
			local ShadowTranceIndex, cancel =
				GetPlayerBuff(BuffAlert.BuffAlert.ShadowTranceID, "HELPFUL|HARMFUL|PASSIVE")
			TimeLeft = floor(GetPlayerBuffTimeLeft(ShadowTranceIndex))
			NecrosisShadowTranceTimer:SetText(TimeLeft)
			ShowUIPanel(NecrosisShadowTranceButton)
		end
		if not Actif and BuffAlert.BuffAlert.ShadowTrance then
			HideUIPanel(NecrosisShadowTranceButton)
			BuffAlert.BuffAlert.ShadowTrance = false
		end
		if Actif and BuffAlert.BuffAlert.ShadowTrance then
			local ShadowTranceIndex, cancel =
				GetPlayerBuff(BuffAlert.BuffAlert.ShadowTranceID, "HELPFUL|HARMFUL|PASSIVE")
			TimeLeft = floor(GetPlayerBuffTimeLeft(ShadowTranceIndex))
			NecrosisShadowTranceTimer:SetText(TimeLeft)
		end
	end

	-- Gestion des Antifears
	if NecrosisConfig.AntiFearAlert then
		local Actif = false -- must be False, or a number from 1 to BuffAlert.AFImageType[] max element.

		-- Checking if we have a target. Any fear need a target to be casted on
		if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
			-- Checking if the target has natural immunity (only NPC target)
			if not UnitIsPlayer("target") then
				for index = 1, table.getn(NECROSIS_ANTI_FEAR_UNIT), 1 do
					if UnitCreatureType("target") == NECROSIS_ANTI_FEAR_UNIT[index] then
						Actif = 2 -- Immun
						break
					end
				end
			end

			-- We'll start to parse the target buffs, as his class doesn't give him natural permanent immunity
			if not Actif then
				for index = 1, table.getn(NECROSIS_ANTI_FEAR_SPELL.Buff), 1 do
					if Necrosis_UnitHasBuff("target", NECROSIS_ANTI_FEAR_SPELL.Buff[index]) then
						Actif = 3 -- Prot
						break
					end
				end

				-- No buff found, let's try the debuffs
				for index = 1, table.getn(NECROSIS_ANTI_FEAR_SPELL.Debuff), 1 do
					if Necrosis_UnitHasEffect("target", NECROSIS_ANTI_FEAR_SPELL.Debuff[index]) then
						Actif = 3 -- Prot
						break
					end
				end
			end

			-- an immunity has been detected before, but we still don't know why => show the button anyway
			if BuffAlert.BuffAlert.AFCurrentTargetImmune and not Actif then
				Actif = 1
			end
		end

		if Actif then
			-- Antifear button is currently not visible, we have to change that
			if not BuffAlert.BuffAlert.AntiFearInUse then
				BuffAlert.BuffAlert.AntiFearInUse = true
				Necrosis_Msg(NECROSIS_MESSAGE.Information.FearProtect, "USER")
				NecrosisAntiFearButton:SetNormalTexture(
					"Interface\\Addons\\Necrosis\\UI\\AntiFear" .. BuffAlert.BuffAlert.AFImageType[Actif] .. "-02"
				)
				if NecrosisConfig.Sound then
					PlaySoundFile(NECROSIS_SOUND.Fear)
				end
				ShowUIPanel(NecrosisAntiFearButton)
				BuffAlert.BuffAlert.AFBlink1 = curTime + 0.6
				BuffAlert.BuffAlert.AFBlink2 = 2

			-- Timer to make the button blink
			elseif curTime >= BuffAlert.BuffAlert.AFBlink1 then
				if BuffAlert.BuffAlert.AFBlink2 == 1 then
					BuffAlert.BuffAlert.AFBlink2 = 2
				else
					BuffAlert.BuffAlert.AFBlink2 = 1
				end
				BuffAlert.BuffAlert.AFBlink1 = curTime + 0.4
				NecrosisAntiFearButton:SetNormalTexture(
					"Interface\\Addons\\Necrosis\\UI\\AntiFear"
						.. BuffAlert.BuffAlert.AFImageType[Actif]
						.. "-0"
						.. BuffAlert.BuffAlert.AFBlink2
				)
			end
		elseif BuffAlert.BuffAlert.AntiFearInUse then -- No antifear on target, but the button is still visible => gonna hide it
			BuffAlert.BuffAlert.AntiFearInUse = false
			HideUIPanel(NecrosisAntiFearButton)
		end
	end

	-- Gestion du Timer des sorts
	if not NecrosisSpellTimerButton:IsVisible() then
		ShowUIPanel(NecrosisSpellTimerButton)
	end

	if NecrosisConfig.CountType == 3 then
		NecrosisShardCount:SetText("")
	end
	local update = false
	if (curTime - SpellCast.Time) >= 1 then
		SpellCast.Time = curTime
		update = true
	end

	-- On met à jour les boutons toutes les secondes
	-- On accepte le trade de la pierre de soin si transfert en cours
	if update then
		if TradeState.Trading then
			TradeState.TradingNow = TradeState.TradingNow - 1
			if TradeState.TradingNow == 0 then
				AcceptTrade()
				TradeState.Trading = false
			end
		end
		Necrosis_UpdateIcons()
	end

	-- Parcours du tableau des Timers
	if SpellTimer then
		if update then
			ClearGraphicalTimers()
			textTimersDisplay = ""
			for index = 1, table.getn(SpellTimer), 1 do
				if SpellTimer[index] then
					if GetTime() <= SpellTimer[index].TimeMax then
						-- Création de l'affichage des timers
						textTimersDisplay, SpellGroup, GraphicalTimer, TimerTable = Necrosis_DisplayTimer(
							textTimersDisplay,
							index,
							SpellGroup,
							SpellTimer,
							GraphicalTimer,
							TimerTable
						)
					end
					-- On enlève les timers terminés
					if curTime >= (SpellTimer[index].TimeMax - 0.5) and SpellTimer[index].TimeMax ~= -1 then
						-- Si le timer était celui de la Pierre d'âme, on prévient le Démoniste
						if SpellTimer[index].Name == NECROSIS_SPELL_TABLE[11].Name then
							Necrosis_Msg(NECROSIS_MESSAGE.Information.SoulstoneEnd, "USER")
							SpellTimer[index].Target = ""
							SpellTimer[index].TimeMax = -1
							if NecrosisConfig.Sound then
								PlaySoundFile(NECROSIS_SOUND.SoulstoneEnd)
							end
							Necrosis_RemoveFrame(SpellTimer[index].Gtimer, TimerTable)
							-- On met à jour l'apparence du bouton de la pierre d'âme
							Necrosis_UpdateIcons()
						-- Sinon on enlève le timer silencieusement (mais pas en cas d'enslave)
						elseif SpellTimer[index].Name ~= NECROSIS_SPELL_TABLE[10].Name then
							SpellTimer, TimerTable = Necrosis_RetraitTimerParIndex(index, SpellTimer, TimerTable)
							index = 0
							break
						end
					end
					-- Si le Démoniste n'est plus sous l'emprise du Sacrifice
					if SpellTimer and SpellTimer[index].Name == NECROSIS_SPELL_TABLE[17].Name then -- Sacrifice
						if
							not Necrosis_UnitHasEffect("player", SpellTimer[index].Name)
							and SpellTimer[index].TimeMax ~= nil
						then
							SpellTimer, TimerTable = Necrosis_RetraitTimerParIndex(index, SpellTimer, TimerTable)
							index = 0
							break
						end
					end
					-- Si la cible visée n'est plus atteinte par un sort lancé [résists]
					if
						SpellTimer
						and (SpellTimer[index].Type == 4 or SpellTimer[index].Type == 5)
						and SpellTimer[index].Target == UnitName("target")
					then
						-- On triche pour laisser le temps au mob de bien sentir qu'il est débuffé ^^
						if
							curTime >= ((SpellTimer[index].TimeMax - SpellTimer[index].Time) + 1.5)
							and SpellTimer[index] ~= 6
						then
							if not Necrosis_UnitHasEffect("target", SpellTimer[index].Name) then
								SpellTimer, TimerTable = Necrosis_RetraitTimerParIndex(index, SpellTimer, TimerTable)
								index = 0
								break
							end
						end
					end
				end
			end
		end
	else
		for i = 1, 10, 1 do
			local frameName = "NecrosisTarget" .. i .. "Text"
			local frameItem = getglobal(frameName)
			if frameItem:IsShown() then
				frameItem:Hide()
			end
		end
	end

	if NecrosisConfig.ShowSpellTimers or NecrosisConfig.Graphical then
		-- Si affichage de timer texte
		if not NecrosisConfig.Graphical then
			-- Coloration de l'affichage des timers
			textTimersDisplay = Necrosis_MsgAddColor(textTimersDisplay)
			-- Affichage des timers
			NecrosisListSpells:SetText(textTimersDisplay)
		else
			NecrosisListSpells:SetText("")
		end
		for i = 4, table.getn(SpellGroup.Name) do
			SpellGroup.Visible[i] = false
		end
	else
		if NecrosisSpellTimerButton:IsVisible() then
			NecrosisListSpells:SetText("")
			HideUIPanel(NecrosisSpellTimerButton)
		end
	end
end

-- Fonction lancée selon l'événement intercepté
function Necrosis_OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		Necrosis_In = true
	elseif event == "PLAYER_LEAVING_WORLD" then
		Necrosis_In = false
	end

	-- Traditionnel test : Le joueur est-il bien Démoniste ?
	-- Le jeu est-il bine chargé ?
	if (not Loaded) or not Necrosis_In or UnitClass("player") ~= NECROSIS_UNIT_WARLOCK then
		return
	end

	-- Si le contenu des sacs a changé, on vérifie que les Fragments d'âme sont toujours dans le bon sac
	if event == "BAG_UPDATE" then
		if NecrosisConfig.SoulshardSort then
			Necrosis_SoulshardSwitch("CHECK")
		else
			Necrosis_BagExplore()
		end
	-- Gestion de la fin de l'incantation des sorts
	elseif event == "SPELLCAST_STOP" then
		Necrosis_SpellManagement()
	-- Quand le démoniste commence à incanter un sort, on intercepte le nom de celui-ci
	-- On sauve également le nom de la cible du sort ainsi que son niveau
	elseif event == "SPELLCAST_START" then
		SpellCast.Name = arg1
		SpellCast.TargetName = UnitName("target")
		if not SpellCast.TargetName then
			SpellCast.TargetName = ""
		end
		SpellCast.TargetLevel = UnitLevel("target")
		if not SpellCast.TargetLevel then
			SpellCast.TargetLevel = ""
		end
	-- Quand le démoniste stoppe son incantation, on relache le nom de celui-ci
	elseif (event == "SPELLCAST_FAILED") or (event == "SPELLCAST_INTERRUPTED") then
		SpellCast.Name = nil
		SpellCast.Rank = nil
		SpellCast.TargetName = nil
		SpellCast.TargetLevel = nil
	-- Flag si une fenetre de Trade est ouverte, afin de pouvoir trader automatiquement les pierres de soin
	elseif event == "TRADE_REQUEST" or event == "TRADE_SHOW" then
		TradeState.Request = true
	elseif event == "TRADE_REQUEST_CANCEL" or event == "TRADE_CLOSED" then
		TradeState.Request = false
	-- AntiFear button hide on target change
	elseif event == "PLAYER_TARGET_CHANGED" then
		if NecrosisConfig.AntiFearAlert and BuffAlert.BuffAlert.AFCurrentTargetImmune then
			BuffAlert.BuffAlert.AFCurrentTargetImmune = false
		end
	-- AntiFear immunity on cast detection
	elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
		if NecrosisConfig.AntiFearAlert then
			for spell, creatureName in string.gfind(arg1, NECROSIS_ANTI_FEAR_SRCH) do
				-- We check if the casted spell on the immune target is Fear or Death Coil
				if spell == NECROSIS_SPELL_TABLE[13].Name or spell == NECROSIS_SPELL_TABLE[19].Name then
					BuffAlert.AFCurrentTargetImmune = true
					break
				end
			end
		end

	-- Si le Démoniste apprend un nouveau sort / rang de sort, on récupère la nouvelle liste des sorts
	-- Si le Démoniste apprend un nouveau sort de buff ou d'invocation, on recrée les boutons
	elseif event == "LEARNED_SPELL_IN_TAB" then
		Necrosis_SpellSetup()
		Necrosis_CreateMenu()
		Necrosis_ButtonSetup()

	-- A la fin du combat, on arrête de signaler le Crépuscule
	-- On enlève les timers de sorts ainsi que les noms des mobs
	elseif event == "PLAYER_REGEN_ENABLED" then
		PlayerCombat = false
		SpellGroup, SpellTimer, TimerTable = Necrosis_RetraitTimerCombat(SpellGroup, SpellTimer, TimerTable)
		for i = 1, 10, 1 do
			local frameName = "NecrosisTarget" .. i .. "Text"
			local frameItem = getglobal(frameName)
			if frameItem:IsShown() then
				frameItem:Hide()
			end
		end
	-- Quand le démoniste change de démon
	elseif event == "UNIT_PET" and arg1 == "player" then
		Necrosis_ChangeDemon()
	-- Actions personnelles -- "Buffs"
	elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then
		Necrosis_SelfEffect("BUFF")
	-- Actions personnelles -- "Debuffs"
	elseif event == "CHAT_MSG_SPELL_AURA_GONE_SELF" or event == "CHAT_MSG_SPELL_BREAK_AURA" then
		Necrosis_SelfEffect("DEBUFF")
	elseif event == "PLAYER_REGEN_DISABLED" then
		PlayerCombat = true
		-- Fin de l'écran de chargement
	end
	return
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS NECROSIS "ON EVENT"
------------------------------------------------------------------------------------------------------

-- Events : PLAYER_ENTERING_WORLD et PLAYER_LEAVING_WORLD
-- Fonction appliquée à chaque écran de chargement
-- Quand on sort d'une zone, on arrête de surveiller les envents
-- Quand on rentre dans une zone, on reprend la surveillance
-- Cela permet d'éviter un temps de chargement trop long du mod
function Necrosis_RegisterManagement(RegistrationType)
	if RegistrationType == "IN" then
		NecrosisButton:RegisterEvent("BAG_UPDATE")
		NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
		NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
		NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_BREAK_AURA")
		NecrosisButton:RegisterEvent("PLAYER_REGEN_DISABLED")
		NecrosisButton:RegisterEvent("PLAYER_REGEN_ENABLED")
		NecrosisButton:RegisterEvent("UNIT_PET")
		NecrosisButton:RegisterEvent("SPELLCAST_START")
		NecrosisButton:RegisterEvent("SPELLCAST_FAILED")
		NecrosisButton:RegisterEvent("SPELLCAST_INTERRUPTED")
		NecrosisButton:RegisterEvent("SPELLCAST_STOP")
		NecrosisButton:RegisterEvent("LEARNED_SPELL_IN_TAB")
		NecrosisButton:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
		NecrosisButton:RegisterEvent("PLAYER_TARGET_CHANGED")
		NecrosisButton:RegisterEvent("TRADE_REQUEST")
		NecrosisButton:RegisterEvent("TRADE_REQUEST_CANCEL")
		NecrosisButton:RegisterEvent("TRADE_SHOW")
		NecrosisButton:RegisterEvent("TRADE_CLOSED")
	else
		NecrosisButton:UnregisterEvent("BAG_UPDATE")
		NecrosisButton:UnregisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
		NecrosisButton:UnregisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
		NecrosisButton:UnregisterEvent("CHAT_MSG_SPELL_BREAK_AURA")
		NecrosisButton:UnregisterEvent("PLAYER_REGEN_DISABLED")
		NecrosisButton:UnregisterEvent("PLAYER_REGEN_ENABLED")
		NecrosisButton:UnregisterEvent("UNIT_PET")
		NecrosisButton:UnregisterEvent("SPELLCAST_START")
		NecrosisButton:UnregisterEvent("SPELLCAST_FAILED")
		NecrosisButton:UnregisterEvent("SPELLCAST_INTERRUPTED")
		NecrosisButton:UnregisterEvent("SPELLCAST_STOP")
		NecrosisButton:UnregisterEvent("LEARNED_SPELL_IN_TAB")
		NecrosisButton:UnregisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
		NecrosisButton:UnregisterEvent("PLAYER_TARGET_CHANGED")
		NecrosisButton:UnregisterEvent("TRADE_REQUEST")
		NecrosisButton:UnregisterEvent("TRADE_REQUEST_CANCEL")
		NecrosisButton:UnregisterEvent("TRADE_SHOW")
		NecrosisButton:UnregisterEvent("TRADE_CLOSED")
	end
	return
end

-- event : UNIT_PET
-- Permet de timer les asservissements, ainsi que de prévenir pour les ruptures d'asservissement
-- Change également le nom du pet au remplacement de celui-ci
function Necrosis_ChangeDemon()
	-- Si le nouveau démon est un démon asservi, on place un timer de 5 minutes
	if Necrosis_UnitHasEffect("pet", NECROSIS_SPELL_TABLE[10].Name) then
		if not DemonEnslaved then
			DemonEnslaved = true
			SpellGroup, SpellTimer, TimerTable =
				Necrosis_InsertTimerParTable(10, "", "", SpellGroup, SpellTimer, TimerTable)
		end
	else
		-- Quand le démon asservi est perdu, on retire le Timer et on prévient le Démoniste
		if DemonEnslaved then
			DemonEnslaved = false
			SpellTimer, TimerTable = Necrosis_RetraitTimerParNom(NECROSIS_SPELL_TABLE[10].Name, SpellTimer, TimerTable)
			if NecrosisConfig.Sound then
				PlaySoundFile(NECROSIS_SOUND.EnslaveEnd)
			end
			Necrosis_Msg(NECROSIS_MESSAGE.Information.EnslaveBreak, "USER")
		end
	end

	-- Si le démon n'est pas asservi on définit son titre, et on met à jour son nom dans Necrosis
	DemonType = UnitCreatureFamily("pet")
	for i = 1, 4, 1 do
		if
			DemonType == NECROSIS_PET_LOCAL_NAME[i]
			and NecrosisConfig.PetName[i] == " "
			and UnitName("pet") ~= UNKNOWNOBJECT
		then
			NecrosisConfig.PetName[i] = UnitName("pet")
			NecrosisLocalization()
			break
		end
	end

	return
end

-- events : CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS, CHAT_MSG_SPELL_AURA_GONE_SELF et CHAT_MSG_SPELL_BREAK_AURA
-- Permet de gérer les effets apparaissants et disparaissants sur le démoniste
-- Basé sur le CombatLog
function Necrosis_SelfEffect(action)
	if action == "BUFF" then
		-- Insertion d'un timer quand le Démoniste subit "Sacrifice"
		if arg1 == NECROSIS_TRANSLATION.SacrificeGain then
			SpellGroup, SpellTimer, TimerTable =
				Necrosis_InsertTimerParTable(17, "", "", SpellGroup, SpellTimer, TimerTable)
		end
		-- Changement du bouton de monture quand le Démoniste chevauche
		if string.find(arg1, NECROSIS_SPELL_TABLE[1].Name) or string.find(arg1, NECROSIS_SPELL_TABLE[2].Name) then
			MountState.Mounted = true
			if
				NecrosisConfig.SteedSummon
				and MountState.TellMounted
				and NecrosisConfig.ChatMsg
				and NECROSIS_PET_MESSAGE[6]
				and not NecrosisConfig.SM
			then
				local tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[6]))
				while tempnum == SteedMess and table.getn(NECROSIS_PET_MESSAGE[6]) >= 2 do
					tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[6]))
				end
				SteedMess = tempnum
				for i = 1, table.getn(NECROSIS_PET_MESSAGE[6][tempnum]) do
					Necrosis_Msg(Necrosis_MsgReplace(NECROSIS_PET_MESSAGE[6][tempnum][i]), "SAY")
				end
				MountState.TellMounted = false
			end
			NecrosisMountButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\MountButton-02")
		end
		-- Changement du bouton de la domination corrompue si celle-ci est activée + Timer de cooldown
		if string.find(arg1, NECROSIS_SPELL_TABLE[15].Name) and NECROSIS_SPELL_TABLE[15].ID ~= nil then
			DominationUp = true
			NecrosisPetMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Domination-02")
		end
		-- Changement du bouton de la malédiction amplifiée si celle-ci est activée + Timer de cooldown
		if string.find(arg1, NECROSIS_SPELL_TABLE[42].Name) and NECROSIS_SPELL_TABLE[42].ID ~= nil then
			AmplifyUp = true
			NecrosisCurseMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Amplify-02")
		end
	else
		-- Changement du bouton de monture quand le Démoniste est démonté
		if string.find(arg1, NECROSIS_SPELL_TABLE[1].Name) or string.find(arg1, NECROSIS_SPELL_TABLE[2].Name) then
			MountState.Mounted = false
			MountState.TellMounted = true
			NecrosisMountButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\MountButton-01")
		end
		-- Changement du bouton de Domination quand le Démoniste n'est plus sous son emprise
		if string.find(arg1, NECROSIS_SPELL_TABLE[15].Name) and NECROSIS_SPELL_TABLE[15].ID ~= nil then
			DominationUp = false
			NecrosisPetMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Domination-01")
		end
		-- Changement du bouton de la malédiction amplifiée quand le Démoniste n'est plus sous son emprise
		if string.find(arg1, NECROSIS_SPELL_TABLE[42].Name) and NECROSIS_SPELL_TABLE[42].ID ~= nil then
			AmplifyUp = false
			NecrosisCurseMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Amplify-01")
		end
	end
	return
end

-- event : SPELLCAST_STOP
-- Permet de gérer tout ce qui touche aux sorts une fois leur incantation réussie
function Necrosis_SpellManagement()
	local SortActif = false
	if SpellCast.Name then
		-- Si le sort lancé à été une Résurrection de Pierre d'âme, on place un timer
		if SpellCast.Name == NECROSIS_SPELL_TABLE[11].Name then
			if SpellCast.TargetName == UnitName("player") then
				SpellCast.TargetName = ""
			end
			-- Si les messages sont actifs et que la pierre est posée sur un joueur ciblé, hop, message !
			if (NecrosisConfig.ChatMsg or NecrosisConfig.SM) and Stones.Soulstone.UsedOnTarget then
				Stones.Soulstone.Target = SpellCast.TargetName
				Stones.Soulstone.Advice = true
			end
			SpellGroup, SpellTimer, TimerTable =
				Necrosis_InsertTimerParTable(11, SpellCast.TargetName, "", SpellGroup, SpellTimer, TimerTable)
		-- Si le sort était un rituel d'invocation, alors on écrit une phrase a caractère informatif aux joueurs
		elseif
			(SpellCast.Name == NECROSIS_TRANSLATION.SummoningRitual)
			and (NecrosisConfig.ChatMsg or NecrosisConfig.SM)
			and NECROSIS_INVOCATION_MESSAGES
		then
			local tempnum = random(1, table.getn(NECROSIS_INVOCATION_MESSAGES))
			while tempnum == TPMess and table.getn(NECROSIS_INVOCATION_MESSAGES) >= 2 do
				tempnum = random(1, table.getn(NECROSIS_INVOCATION_MESSAGES))
			end
			TPMess = tempnum
			for i = 1, table.getn(NECROSIS_INVOCATION_MESSAGES[tempnum]) do
				Necrosis_Msg(
					Necrosis_MsgReplace(NECROSIS_INVOCATION_MESSAGES[tempnum][i], SpellCast.TargetName),
					"WORLD"
				)
			end
		-- Pour les autres sorts castés, tentative de timer si valable
		else
			for spell = 1, table.getn(NECROSIS_SPELL_TABLE), 1 do
				if SpellCast.Name == NECROSIS_SPELL_TABLE[spell].Name and not (spell == 10) then
					-- Si le timer existe déjà sur la cible, on le met à jour
					for thisspell = 1, table.getn(SpellTimer), 1 do
						if
							SpellTimer[thisspell].Name == SpellCast.Name
							and SpellTimer[thisspell].Target == SpellCast.TargetName
							and SpellTimer[thisspell].TargetLevel == SpellCast.TargetLevel
							and NECROSIS_SPELL_TABLE[spell].Type ~= 4
							and spell ~= 16
						then
							-- Si c'est sort lancé déjà présent sur un mob, on remet le timer à fond
							if spell ~= 9 or (spell == 9 and not Necrosis_UnitHasEffect("target", SpellCast.Name)) then
								SpellTimer[thisspell].Time = NECROSIS_SPELL_TABLE[spell].Length
								SpellTimer[thisspell].TimeMax = floor(GetTime() + NECROSIS_SPELL_TABLE[spell].Length)
								if spell == 9 and SpellCast.Rank == 1 then
									SpellTimer[thisspell].Time = 20
									SpellTimer[thisspell].TimeMax = floor(GetTime() + 20)
								end
							end
							SortActif = true
							break
						end
						-- Si c'est un banish sur une nouvelle cible, on supprime le timer précédent
						if
							SpellTimer[thisspell].Name == SpellCast.Name
							and spell == 9
							and (
								SpellTimer[thisspell].Target ~= SpellCast.TargetName
								or SpellTimer[thisspell].TargetLevel ~= SpellCast.TargetLevel
							)
						then
							SpellTimer, TimerTable = Necrosis_RetraitTimerParIndex(thisspell, SpellTimer, TimerTable)
							SortActif = false
							break
						end

						-- Si c'est un fear, on supprime le timer du fear précédent
						if SpellTimer[thisspell].Name == SpellCast.Name and spell == 13 then
							SpellTimer, TimerTable = Necrosis_RetraitTimerParIndex(thisspell, SpellTimer, TimerTable)
							SortActif = false
							break
						end
						if SortActif then
							break
						end
					end
					-- Si le timer est une malédiction, on enlève la précédente malédiction sur la cible
					if (NECROSIS_SPELL_TABLE[spell].Type == 4) or (spell == 16) then
						for thisspell = 1, table.getn(SpellTimer), 1 do
							-- Mais on garde le cooldown de la malédiction funeste
							if SpellTimer[thisspell].Name == NECROSIS_SPELL_TABLE[16].Name then
								SpellTimer[thisspell].Target = ""
								SpellTimer[thisspell].TargetLevel = ""
							end
							if
								SpellTimer[thisspell].Type == 4
								and SpellTimer[thisspell].Target == SpellCast.TargetName
								and SpellTimer[thisspell].TargetLevel == SpellCast.TargetLevel
							then
								SpellTimer, TimerTable =
									Necrosis_RetraitTimerParIndex(thisspell, SpellTimer, TimerTable)
								break
							end
						end
						SortActif = false
					end
					if not SortActif and NECROSIS_SPELL_TABLE[spell].Type ~= 0 and spell ~= 10 then
						if spell == 9 then
							if SpellCast.Rank == 1 then
								NECROSIS_SPELL_TABLE[spell].Length = 20
							else
								NECROSIS_SPELL_TABLE[spell].Length = 30
							end
						end

						SpellGroup, SpellTimer, TimerTable = Necrosis_InsertTimerParTable(
							spell,
							SpellCast.TargetName,
							SpellCast.TargetLevel,
							SpellGroup,
							SpellTimer,
							TimerTable
						)
						break
					end
				end
			end
		end
	end
	SpellCast.Name = nil
	SpellCast.Rank = nil
	return
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS DE L'INTERFACE -- LIENS XML
------------------------------------------------------------------------------------------------------

-- En cliquant droit sur Necrosis, on affiche ou masque les deux panneaux de configurations
function Necrosis_Toggle(button)
	if button == "LeftButton" then
		if NECROSIS_SPELL_TABLE[41].ID then
			CastSpell(NECROSIS_SPELL_TABLE[41].ID, "spell")
		end
		return
	elseif NecrosisGeneralFrame:IsVisible() then
		HideUIPanel(NecrosisGeneralFrame)
		return
	else
		if NecrosisConfig.SM then
			Necrosis_Msg("!!! Short Messages : <brightGreen>On", "USER")
		end
		ShowUIPanel(NecrosisGeneralFrame)
		NecrosisGeneralTab_OnClick(1)
		return
	end
end

-- Fonction permettant le déplacement d'éléments de Necrosis sur l'écran
function Necrosis_OnDragStart(button)
	if button == "NecrosisIcon" then
		GameTooltip:Hide()
	end
	button:StartMoving()
end

-- Fonction arrêtant le déplacement d'éléments de Necrosis sur l'écran
function Necrosis_OnDragStop(button)
	if button == "NecrosisIcon" then
		Necrosis_BuildTooltip("OVERALL")
	end
	button:StopMovingOrSizing()
end

-- Fonction alternant Timers graphiques et Timers textes
function Necrosis_HideGraphTimer()
	for i = 1, 50, 1 do
		local elements = { "Text", "Bar", "Texture", "OutText" }
		if NecrosisConfig.Graphical then
			if TimerTable[i] then
				for j = 1, 4, 1 do
					frameName = "NecrosisTimer" .. i .. elements[j]
					frameItem = getglobal(frameName)
					frameItem:Show()
				end
			end
		else
			for j = 1, 4, 1 do
				frameName = "NecrosisTimer" .. i .. elements[j]
				frameItem = getglobal(frameName)
				frameItem:Hide()
			end
		end
	end
end

-- Fonction gérant les bulles d'aide
function Necrosis_BuildTooltip(button, type, anchor)
	-- Si l'affichage des bulles d'aide est désactivé, Bye bye !
	if not NecrosisConfig.NecrosisToolTip then
		return
	end

	-- On regarde si la domination corrompue, le gardien de l'ombre ou l'amplification de malédiction sont up (pour tooltips)
	local start, duration, start2, duration2, start3, duration3
	if NECROSIS_SPELL_TABLE[15].ID then
		start, duration = GetSpellCooldown(NECROSIS_SPELL_TABLE[15].ID, BOOKTYPE_SPELL)
	else
		start = 1
		duration = 1
	end
	if NECROSIS_SPELL_TABLE[43].ID then
		start2, duration2 = GetSpellCooldown(NECROSIS_SPELL_TABLE[43].ID, BOOKTYPE_SPELL)
	else
		start2 = 1
		duration2 = 1
	end
	if NECROSIS_SPELL_TABLE[42].ID then
		start3, duration3 = GetSpellCooldown(NECROSIS_SPELL_TABLE[42].ID, BOOKTYPE_SPELL)
	else
		start3 = 1
		duration3 = 1
	end

	-- Création des bulles d'aides....
	GameTooltip:SetOwner(button, anchor)
	GameTooltip:SetText(NecrosisTooltipData[type].Label)
	-- ..... pour le bouton principal
	if type == "Main" then
		GameTooltip:AddLine(NecrosisTooltipData.Main.Soulshard .. ShardState.Count)
		GameTooltip:AddLine(NecrosisTooltipData.Main.InfernalStone .. InfernalStone)
		GameTooltip:AddLine(NecrosisTooltipData.Main.DemoniacStone .. DemoniacStone)
		GameTooltip:AddLine(
			NecrosisTooltipData.Main.Soulstone .. NecrosisTooltipData[type].Stone[Stones.Soulstone.OnHand]
		)
		GameTooltip:AddLine(
			NecrosisTooltipData.Main.Healthstone .. NecrosisTooltipData[type].Stone[Stones.Healthstone.OnHand]
		)
		GameTooltip:AddLine(
			NecrosisTooltipData.Main.Firestone .. NecrosisTooltipData[type].Stone[Stones.Firestone.OnHand]
		)
		GameTooltip:AddLine(
			NecrosisTooltipData.Main.Spellstone .. NecrosisTooltipData[type].Stone[Stones.Spellstone.OnHand]
		)
		-- Affichage du nom du démon, ou s'il est asservi, ou "Aucun" si aucun démon n'est présent
		if DemonType then
			GameTooltip:AddLine(NecrosisTooltipData.Main.CurrentDemon .. DemonType)
		elseif DemonEnslaved then
			GameTooltip:AddLine(NecrosisTooltipData.Main.EnslavedDemon)
		else
			GameTooltip:AddLine(NecrosisTooltipData.Main.NoCurrentDemon)
		end
	-- ..... pour le menu des pierres
	elseif type == "StoneMenu" then
		if NecrosisConfig.LastStone ~= "" then
			if NecrosisConfig.LastStone == "Firestone" then
				GameTooltip:AddLine(
					NecrosisTooltipData.LastStone.MiddleClick[Stones.Firestone.Mode] .. NECROSIS_ITEM["Firestone"]
				)
				if Stones.Firestone.Mode == 1 then
					GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[4]].Mana .. " Mana")
				end
			elseif NecrosisConfig.LastStone == "Felstone" then
				GameTooltip:AddLine(
					NecrosisTooltipData.LastStone.MiddleClick[Stones.Felstone.Mode] .. NECROSIS_ITEM["Felstone"]
				)
				if Stones.Felstone.Mode == 1 then
					GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[5]].Mana .. " Mana")
				end
			elseif NecrosisConfig.LastStone == "Wrathstone" then
				GameTooltip:AddLine(
					NecrosisTooltipData.LastStone.MiddleClick[Stones.Wrathstone.Mode] .. NECROSIS_ITEM["Wrathstone"]
				)
				if Stones.Wrathstone.Mode == 1 then
					GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[6]].Mana .. " Mana")
				end
			elseif NecrosisConfig.LastStone == "Voidstone" then
				GameTooltip:AddLine(
					NecrosisTooltipData.LastStone.MiddleClick[Stones.Voidstone.Mode] .. NECROSIS_ITEM["Voidstone"]
				)
				if Stones.Voidstone.Mode == 1 then
					GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[7]].Mana .. " Mana")
				end
			end
		end
	-- ..... pour les boutons de pierre
	elseif string.find(type, "stone") then
		-- Pierre d'âme
		if type == "Soulstone" then
			-- On affiche le nom de la pierre et l'action que produira le clic sur le bouton
			-- Et aussi le Temps de recharge
			if Stones.Soulstone.Mode == 1 or Stones.Soulstone.Mode == 3 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[1]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Soulstone.Location[1], Stones.Soulstone.Location[2])
			local itemName = tostring(NecrosisTooltipTextLeft6:GetText())
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Soulstone.Mode])
			if string.find(itemName, NECROSIS_TRANSLATION.Cooldown) then
				GameTooltip:AddLine(itemName)
			end
		-- Pierre de vie
		elseif type == "Healthstone" then
			-- Idem
			if Stones.Healthstone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[2]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Healthstone.Location[1], Stones.Healthstone.Location[2])
			local itemName = tostring(NecrosisTooltipTextLeft6:GetText())
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Healthstone.Mode])
			if string.find(itemName, NECROSIS_TRANSLATION.Cooldown) then
				GameTooltip:AddLine(itemName)
			end
		-- Pierre de sort
		elseif type == "Spellstone" then
			-- Idem
			if Stones.Spellstone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[3]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Spellstone.Location[1], Stones.Spellstone.Location[2])
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Spellstone.Mode])
			local itemName = tostring(NecrosisTooltipTextLeft7:GetText())
			if string.find(itemName, NECROSIS_TRANSLATION.Cooldown) then
				GameTooltip:AddLine(itemName)
			end
		elseif type == "Firestone" then
			if Stones.Firestone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[4]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Firestone.Location[1], Stones.Firestone.Location[2])
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Firestone.Mode])
		elseif type == "Felstone" then
			if Stones.Felstone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[5]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Felstone.Location[1], Stones.Felstone.Location[2])
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Felstone.Mode])
		elseif type == "Wrathstone" then
			if Stones.Wrathstone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[6]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Wrathstone.Location[1], Stones.Wrathstone.Location[2])
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Wrathstone.Mode])
		elseif type == "Voidstone" then
			if Stones.Voidstone.Mode == 1 then
				GameTooltip:AddLine(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[7]].Mana .. " Mana")
			end
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(Stones.Voidstone.Location[1], Stones.Voidstone.Location[2])
			GameTooltip:AddLine(NecrosisTooltipData[type].Text[Stones.Voidstone.Mode])
		end
	-- ..... pour le bouton des Timers
	elseif type == "SpellTimer" then
		Necrosis_MoneyToggle()
		NecrosisTooltip:SetBagItem(Stones.Hearthstone.Location[1], Stones.Hearthstone.Location[2])
		local itemName = tostring(NecrosisTooltipTextLeft5:GetText())
		GameTooltip:AddLine(NecrosisTooltipData[type].Text)
		if string.find(itemName, NECROSIS_TRANSLATION.Cooldown) then
			GameTooltip:AddLine(NECROSIS_TRANSLATION.Hearth .. " - " .. itemName)
		else
			GameTooltip:AddLine(NecrosisTooltipData[type].Right .. GetBindLocation())
		end

	-- ..... pour le bouton de la Transe de l'ombre
	elseif type == "BuffAlert.ShadowTrance" then
		local rank = Necrosis_FindSpellAttribute("Name", NECROSIS_NIGHTFALL.BoltName, "Rank")
		GameTooltip:SetText(NecrosisTooltipData[type].Label .. "          |CFF808080Rank " .. rank .. "|r")
	-- ..... pour les autres buffs et démons, le coût en mana...
	elseif type == "Enslave" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[35].Mana .. " Mana")
		if ShardState.Count == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.Soulshard .. ShardState.Count .. "|r")
		end
	elseif type == "Mount" then
		if NECROSIS_SPELL_TABLE[2].ID then
			GameTooltip:AddLine(NECROSIS_SPELL_TABLE[2].Mana .. " Mana")
		elseif NECROSIS_SPELL_TABLE[1].ID then
			GameTooltip:AddLine(NECROSIS_SPELL_TABLE[1].Mana .. " Mana")
		end
	elseif type == "Armor" then
		if NECROSIS_SPELL_TABLE[31].ID then
			GameTooltip:AddLine(NECROSIS_SPELL_TABLE[31].Mana .. " Mana")
		else
			GameTooltip:AddLine(NECROSIS_SPELL_TABLE[36].Mana .. " Mana")
		end
	elseif type == "Invisible" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[33].Mana .. " Mana")
	elseif type == "Aqua" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[32].Mana .. " Mana")
	elseif type == "Kilrogg" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[34].Mana .. " Mana")
	elseif type == "Banish" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[9].Mana .. " Mana")
	elseif type == "Weakness" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[23].Mana .. " Mana")
		if not (start3 > 0 and duration3 > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.AmplifyCooldown)
		end
	elseif type == "Agony" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[22].Mana .. " Mana")
		if not (start3 > 0 and duration3 > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.AmplifyCooldown)
		end
	elseif type == "Reckless" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[24].Mana .. " Mana")
	elseif type == "Tongues" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[25].Mana .. " Mana")
	elseif type == "Exhaust" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[40].Mana .. " Mana")
		if not (start3 > 0 and duration3 > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.AmplifyCooldown)
		end
	elseif type == "Elements" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[26].Mana .. " Mana")
	elseif type == "Shadow" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[27].Mana .. " Mana")
	elseif type == "Doom" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[16].Mana .. " Mana")
	elseif type == "Amplify" then
		if start3 > 0 and duration3 > 0 then
			local seconde = duration3 - (GetTime() - start3)
			local affiche, minute, time
			if seconde <= 59 then
				affiche = tostring(floor(seconde)) .. " sec"
			else
				minute = tostring(floor(seconde / 60))
				seconde = mod(seconde, 60)
				if seconde <= 9 then
					time = "0" .. tostring(floor(seconde))
				else
					time = tostring(floor(seconde))
				end
				affiche = minute .. ":" .. time
			end
			GameTooltip:AddLine("Cooldown : " .. affiche)
		end
	elseif type == "TP" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[37].Mana .. " Mana")
		if ShardState.Count == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.Soulshard .. ShardState.Count .. "|r")
		end
	elseif type == "SoulLink" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[38].Mana .. " Mana")
	elseif type == "ShadowProtection" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[43].Mana .. " Mana")
		if start2 > 0 and duration2 > 0 then
			local seconde = duration2 - (GetTime() - start2)
			local affiche
			affiche = tostring(floor(seconde)) .. " sec"
			GameTooltip:AddLine("Cooldown : " .. affiche)
		end
	elseif type == "Domination" then
		if start > 0 and duration > 0 then
			local seconde = duration - (GetTime() - start)
			local affiche, minute, time
			if seconde <= 59 then
				affiche = tostring(floor(seconde)) .. " sec"
			else
				minute = tostring(floor(seconde / 60))
				seconde = mod(seconde, 60)
				if seconde <= 9 then
					time = "0" .. tostring(floor(seconde))
				else
					time = tostring(floor(seconde))
				end
				affiche = minute .. ":" .. time
			end
			GameTooltip:AddLine("Cooldown : " .. affiche)
		end
	elseif type == "Imp" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[3].Mana .. " Mana")
		if not (start > 0 and duration > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.DominationCooldown)
		end
	elseif type == "Void" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[4].Mana .. " Mana")
		if ShardState.Count == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.Soulshard .. ShardState.Count .. "|r")
		elseif not (start > 0 and duration > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.DominationCooldown)
		end
	elseif type == "Succubus" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[5].Mana .. " Mana")
		if ShardState.Count == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.Soulshard .. ShardState.Count .. "|r")
		elseif not (start > 0 and duration > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.DominationCooldown)
		end
	elseif type == "Fel" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[6].Mana .. " Mana")
		if ShardState.Count == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.Soulshard .. ShardState.Count .. "|r")
		elseif not (start > 0 and duration > 0) then
			GameTooltip:AddLine(NecrosisTooltipData.DominationCooldown)
		end
	elseif type == "Infernal" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[8].Mana .. " Mana")
		if InfernalStone == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.InfernalStone .. InfernalStone .. "|r")
		else
			GameTooltip:AddLine(NecrosisTooltipData.Main.InfernalStone .. InfernalStone)
		end
	elseif type == "Doomguard" then
		GameTooltip:AddLine(NECROSIS_SPELL_TABLE[30].Mana .. " Mana")
		if DemoniacStone == 0 then
			GameTooltip:AddLine("|c00FF4444" .. NecrosisTooltipData.Main.DemoniacStone .. DemoniacStone .. "|r")
		else
			GameTooltip:AddLine(NecrosisTooltipData.Main.DemoniacStone .. DemoniacStone)
		end
	elseif (type == "Buff") and MenuState.LastBuff ~= 0 then
		GameTooltip:AddLine(NecrosisTooltipData.LastSpell .. NECROSIS_SPELL_TABLE[MenuState.LastBuff].Name)
	elseif (type == "Curse") and MenuState.LastCurse ~= 0 then
		GameTooltip:AddLine(NecrosisTooltipData.LastSpell .. NECROSIS_SPELL_TABLE[MenuState.LastCurse].Name)
	elseif (type == "Pet") and MenuState.LastDemon ~= 0 then
		GameTooltip:AddLine(NecrosisTooltipData.LastSpell .. NECROSIS_PET_LOCAL_NAME[(MenuState.LastDemon - 2)])
	end
	-- Et hop, affichage !
	GameTooltip:Show()
end

-- Fonction mettant à jour les boutons Necrosis et donnant l'état du bouton de la pierre d'âme
function Necrosis_UpdateIcons()
	-- Pierre d'âme
	-----------------------------------------------

	-- On se renseigne pour savoir si une pierre d'âme a été utilisée --> vérification dans les timers
	local SoulstoneInUse = false
	if SpellTimer then
		for index = 1, table.getn(SpellTimer), 1 do
			if (SpellTimer[index].Name == NECROSIS_SPELL_TABLE[11].Name) and SpellTimer[index].TimeMax > 0 then
				SoulstoneInUse = true
				break
			end
		end
	end

	-- Si la Pierre n'a pas été utilisée, et qu'il n'y a pas de pierre en inventaire -> Mode 1
	if not (Stones.Soulstone.OnHand or SoulstoneInUse) then
		Stones.Soulstone.Mode = 1
		Stones.Soulstone.Waiting = false
		Stones.Soulstone.Cooldown = false
	end

	-- Si la Pierre n'a pas été utilisée, mais qu'il y a une pierre en inventaire
	if Stones.Soulstone.OnHand and not SoulstoneInUse then
		-- Si la pierre en inventaire contient un timer, et qu'on sort d'un RL --> Mode 4
		local start, duration = GetContainerItemCooldown(Stones.Soulstone.Location[1], Stones.Soulstone.Location[2])
		if NecrosisRL and start > 0 and duration > 0 then
			SpellGroup, SpellTimer, TimerTable =
				Necrosis_InsertTimerStone("Soulstone", start, duration, SpellGroup, SpellTimer, TimerTable)
			Stones.Soulstone.Mode = 4
			NecrosisRL = false
			Stones.Soulstone.Waiting = false
			Stones.Soulstone.Cooldown = true
		-- Si la pierre ne contient pas de timer, ou qu'on ne sort pas d'un RL --> Mode 2
		else
			Stones.Soulstone.Mode = 2
			NecrosisRL = false
			Stones.Soulstone.Waiting = false
			Stones.Soulstone.Cooldown = false
		end
	end

	-- Si la Pierre a été utilisée mais qu'il n'y a pas de pierre en inventaire --> Mode 3
	if (not Stones.Soulstone.OnHand) and SoulstoneInUse then
		Stones.Soulstone.Mode = 3
		Stones.Soulstone.Waiting = true
		-- Si on vient de poser la pierre, on l'annonce au raid
		if Stones.Soulstone.Advice and NECROSIS_SOULSTONE_ALERT_MESSAGE then
			local tempnum = random(1, table.getn(NECROSIS_SOULSTONE_ALERT_MESSAGE))
			while tempnum == RezMess and table.getn(NECROSIS_SOULSTONE_ALERT_MESSAGE) >= 2 do
				tempnum = random(1, table.getn(NECROSIS_SOULSTONE_ALERT_MESSAGE))
			end
			RezMess = tempnum
			for i = 1, table.getn(NECROSIS_SOULSTONE_ALERT_MESSAGE[tempnum]) do
				Necrosis_Msg(
					Necrosis_MsgReplace(NECROSIS_SOULSTONE_ALERT_MESSAGE[tempnum][i], Stones.Soulstone.Target),
					"WORLD"
				)
			end
			Stones.Soulstone.Advice = false
		end
	end

	-- Si la Pierre a été utilisée et qu'il y a une pierre en inventaire
	if Stones.Soulstone.OnHand and SoulstoneInUse then
		Stones.Soulstone.Advice = false
		if not (Stones.Soulstone.Waiting or Stones.Soulstone.Cooldown) then
			SpellTimer, TimerTable = Necrosis_RetraitTimerParNom(NECROSIS_SPELL_TABLE[11].Name, SpellTimer, TimerTable)
			Stones.Soulstone.Mode = 2
		else
			Stones.Soulstone.Waiting = false
			Stones.Soulstone.Cooldown = true
			Stones.Soulstone.Mode = 4
		end
	end

	-- Affichage de l'icone liée au mode
	NecrosisSoulstoneButton:SetNormalTexture(
		"Interface\\AddOns\\Necrosis\\UI\\SoulstoneButton-0" .. Stones.Soulstone.Mode
	)

	-- Pierre de vie
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Healthstone.OnHand then
		Stones.Healthstone.Mode = 2
	else
		Stones.Healthstone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisHealthstoneButton:SetNormalTexture(
		"Interface\\AddOns\\Necrosis\\UI\\HealthstoneButton-0" .. Stones.Healthstone.Mode
	)

	-- Pierre de sort
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Spellstone.OnHand then
		Stones.Spellstone.Mode = 2
	else
		Stones.Spellstone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisSpellstoneButton:SetNormalTexture(
		"Interface\\AddOns\\Necrosis\\UI\\SpellstoneButton-0" .. Stones.Spellstone.Mode
	)

	-- Pierre de feu
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Firestone.OnHand then
		Stones.Firestone.Mode = 2
	else
		Stones.Firestone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisStoneMenu1:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\FirestoneButton-0" .. Stones.Firestone.Mode)

	-- Felstone
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Felstone.OnHand then
		Stones.Felstone.Mode = 2
	else
		Stones.Felstone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisStoneMenu2:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\FelstoneButton-0" .. Stones.Felstone.Mode)

	-- Wrathstone
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Wrathstone.OnHand then
		Stones.Wrathstone.Mode = 2
	else
		Stones.Wrathstone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisStoneMenu3:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\WrathstoneButton-0" .. Stones.Wrathstone.Mode)

	-- Voidstone
	-----------------------------------------------

	-- Mode "j'en ai une" (2) / "j'en ai pas" (1)
	if Stones.Voidstone.OnHand then
		Stones.Voidstone.Mode = 2
	else
		Stones.Voidstone.Mode = 1
	end

	-- Affichage de l'icone liée au mode
	NecrosisStoneMenu4:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\VoidstoneButton-0" .. Stones.Voidstone.Mode)

	-- Stone menu button
	------------------------------------------------

	SetStoneMenuTextures()

	-- Bouton des démons
	-----------------------------------------------
	local mana = UnitMana("player")

	local ManaPet = { "1", "1", "1", "1", "1", "1" }

	-- Si cooldown de domination corrompue on grise
	if NECROSIS_SPELL_TABLE[15].ID and not DominationUp then
		local start, duration = GetSpellCooldown(NECROSIS_SPELL_TABLE[15].ID, "spell")
		if start > 0 and duration > 0 then
			NecrosisPetMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Domination-03")
		else
			NecrosisPetMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Domination-01")
		end
	end

	-- Si cooldown de gardien de l'ombre on grise
	if NECROSIS_SPELL_TABLE[43].ID then
		local start2, duration2 = GetSpellCooldown(NECROSIS_SPELL_TABLE[43].ID, "spell")
		if start2 > 0 and duration2 > 0 then
			NecrosisBuffMenu8:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\ShadowWard-03")
		else
			NecrosisBuffMenu8:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\ShadowWard-01")
		end
	end

	-- Si cooldown de la malédiction amplifiée on grise
	if NECROSIS_SPELL_TABLE[42].ID and not AmplifyUp then
		local start3, duration3 = GetSpellCooldown(NECROSIS_SPELL_TABLE[42].ID, "spell")
		if start3 > 0 and duration3 > 0 then
			NecrosisCurseMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Amplify-03")
		else
			NecrosisCurseMenu1:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Amplify-01")
		end
	end

	if mana ~= nil then
		-- Coloration du bouton en grisé si pas assez de mana
		if NECROSIS_SPELL_TABLE[3].ID then
			if NECROSIS_SPELL_TABLE[3].Mana > mana then
				for i = 1, 6, 1 do
					ManaPet[i] = "3"
				end
			elseif NECROSIS_SPELL_TABLE[4].ID then
				if NECROSIS_SPELL_TABLE[4].Mana > mana then
					for i = 2, 6, 1 do
						ManaPet[i] = "3"
					end
				elseif NECROSIS_SPELL_TABLE[8].ID then
					if NECROSIS_SPELL_TABLE[8].Mana > mana then
						for i = 5, 6, 1 do
							ManaPet[i] = "3"
						end
					elseif NECROSIS_SPELL_TABLE[30].ID then
						if NECROSIS_SPELL_TABLE[30].Mana > mana then
							ManaPet[6] = "3"
						end
					end
				end
			end
		end
	end

	-- Coloration du bouton en grisé si pas de pierre pour l'invocation
	if ShardState.Count == 0 then
		for i = 2, 4, 1 do
			ManaPet[i] = "3"
		end
	end
	if InfernalStone == 0 then
		ManaPet[5] = "3"
	end
	if DemoniacStone == 0 then
		ManaPet[6] = "3"
	end

	-- Texturage des boutons de pet
	if DemonType == NECROSIS_PET_LOCAL_NAME[1] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-02")
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	elseif DemonType == NECROSIS_PET_LOCAL_NAME[2] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-02")
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	elseif DemonType == NECROSIS_PET_LOCAL_NAME[3] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-02")
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	elseif DemonType == NECROSIS_PET_LOCAL_NAME[4] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-02")
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	elseif DemonType == NECROSIS_PET_LOCAL_NAME[5] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-02")
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	elseif DemonType == NECROSIS_PET_LOCAL_NAME[6] then
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-02")
	else
		NecrosisPetMenu2:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Imp-0" .. ManaPet[1])
		NecrosisPetMenu3:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Voidwalker-0" .. ManaPet[2])
		NecrosisPetMenu4:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Succubus-0" .. ManaPet[3])
		NecrosisPetMenu5:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Felhunter-0" .. ManaPet[4])
		NecrosisPetMenu6:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Infernal-0" .. ManaPet[5])
		NecrosisPetMenu7:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\Doomguard-0" .. ManaPet[6])
	end

	-- Bouton des buffs
	-----------------------------------------------

	if mana ~= nil then
		-- Coloration du bouton en grisé si pas assez de mana
		if MountState.Available and not MountState.Mounted then
			if NECROSIS_SPELL_TABLE[2].ID then
				if NECROSIS_SPELL_TABLE[2].Mana > mana or PlayerCombat then
					NecrosisMountButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\MountButton-03")
				else
					NecrosisMountButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\MountButton-01")
				end
			else
				if NECROSIS_SPELL_TABLE[1].Mana > mana or PlayerCombat then
					NecrosisMountButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\MountButton-03")
				else
					NecrosisMountButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\MountButton-01")
				end
			end
		end
		if NECROSIS_SPELL_TABLE[35].ID then
			if NECROSIS_SPELL_TABLE[35].Mana > mana or ShardState.Count == 0 then
				NecrosisPetMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Enslave-03")
			else
				NecrosisPetMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Enslave-01")
			end
		end
		if NECROSIS_SPELL_TABLE[31].ID then
			if NECROSIS_SPELL_TABLE[31].Mana > mana then
				NecrosisBuffMenu1:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ArmureDemo-03")
			else
				NecrosisBuffMenu1:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ArmureDemo-01")
			end
		elseif NECROSIS_SPELL_TABLE[36].ID then
			if NECROSIS_SPELL_TABLE[36].Mana > mana then
				NecrosisBuffMenu1:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ArmureDemo-03")
			else
				NecrosisBuffMenu1:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ArmureDemo-01")
			end
		end
		if NECROSIS_SPELL_TABLE[32].ID then
			if NECROSIS_SPELL_TABLE[32].Mana > mana then
				NecrosisBuffMenu2:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Aqua-03")
			else
				NecrosisBuffMenu2:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Aqua-01")
			end
		end
		if NECROSIS_SPELL_TABLE[33].ID then
			if NECROSIS_SPELL_TABLE[33].Mana > mana then
				NecrosisBuffMenu3:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Invisible-03")
			else
				NecrosisBuffMenu3:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Invisible-01")
			end
		end
		if NECROSIS_SPELL_TABLE[34].ID then
			if NECROSIS_SPELL_TABLE[34].Mana > mana then
				NecrosisBuffMenu4:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Kilrogg-03")
			else
				NecrosisBuffMenu4:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Kilrogg-01")
			end
		end
		if NECROSIS_SPELL_TABLE[37].ID then
			if NECROSIS_SPELL_TABLE[37].Mana > mana or ShardState.Count == 0 then
				NecrosisBuffMenu5:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\TPButton-05")
			else
				NecrosisBuffMenu5:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\TPButton-01")
			end
		end
		if NECROSIS_SPELL_TABLE[38].ID then
			if NECROSIS_SPELL_TABLE[38].Mana > mana then
				NecrosisBuffMenu7:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Lien-03")
			else
				NecrosisBuffMenu7:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Lien-01")
			end
		end
		if NECROSIS_SPELL_TABLE[43].ID then
			if NECROSIS_SPELL_TABLE[43].Mana > mana then
				NecrosisBuffMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ShadowWard-03")
			else
				NecrosisBuffMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\ShadowWard-01")
			end
		end
		if NECROSIS_SPELL_TABLE[9].ID then
			if NECROSIS_SPELL_TABLE[9].Mana > mana then
				NecrosisBuffMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Banish-03")
			else
				NecrosisBuffMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Banish-01")
			end
		end
		if NECROSIS_SPELL_TABLE[44].ID then
			if not UnitExists("Pet") then
				NecrosisPetMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Sacrifice-03")
			else
				NecrosisPetMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Sacrifice-01")
			end
		end
	end

	-- Bouton des curses
	-----------------------------------------------

	if mana ~= nil then
		-- Coloration du bouton en grisé si pas assez de mana
		if NECROSIS_SPELL_TABLE[23].ID then
			if NECROSIS_SPELL_TABLE[23].Mana > mana then
				NecrosisCurseMenu2:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Weakness-03")
			else
				NecrosisCurseMenu2:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Weakness-01")
			end
		end
		if NECROSIS_SPELL_TABLE[22].ID then
			if NECROSIS_SPELL_TABLE[22].Mana > mana then
				NecrosisCurseMenu3:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Agony-03")
			else
				NecrosisCurseMenu3:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Agony-01")
			end
		end
		if NECROSIS_SPELL_TABLE[24].ID then
			if NECROSIS_SPELL_TABLE[24].Mana > mana then
				NecrosisCurseMenu4:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Reckless-03")
			else
				NecrosisCurseMenu4:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Reckless-01")
			end
		end
		if NECROSIS_SPELL_TABLE[25].ID then
			if NECROSIS_SPELL_TABLE[25].Mana > mana then
				NecrosisCurseMenu5:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Tongues-03")
			else
				NecrosisCurseMenu5:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Tongues-01")
			end
		end
		if NECROSIS_SPELL_TABLE[40].ID then
			if NECROSIS_SPELL_TABLE[40].Mana > mana then
				NecrosisCurseMenu6:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Exhaust-03")
			else
				NecrosisCurseMenu6:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Exhaust-01")
			end
		end
		if NECROSIS_SPELL_TABLE[26].ID then
			if NECROSIS_SPELL_TABLE[26].Mana > mana then
				NecrosisCurseMenu7:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Elements-03")
			else
				NecrosisCurseMenu7:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Elements-01")
			end
		end
		if NECROSIS_SPELL_TABLE[27].ID then
			if NECROSIS_SPELL_TABLE[27].Mana > mana then
				NecrosisCurseMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Shadow-03")
			else
				NecrosisCurseMenu8:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Shadow-01")
			end
		end
		if NECROSIS_SPELL_TABLE[16].ID then
			if NECROSIS_SPELL_TABLE[16].Mana > mana then
				NecrosisCurseMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Doom-03")
			else
				NecrosisCurseMenu9:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Doom-01")
			end
		end
	end

	-- Bouton des Timers
	-----------------------------------------------
	if Stones.Hearthstone.Location[1] then
		local start, duration, enable =
			GetContainerItemCooldown(Stones.Hearthstone.Location[1], Stones.Hearthstone.Location[2])
		if duration > 20 and start > 0 then
			NecrosisSpellTimerButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\SpellTimerButton-Cooldown")
		else
			NecrosisSpellTimerButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\SpellTimerButton-Normal")
		end
	end
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS DES PIERRES ET DES FRAGMENTS
------------------------------------------------------------------------------------------------------

-- T'AS QU'A SAVOIR OU T'AS MIS TES AFFAIRES !
function Necrosis_SoulshardSetup()
	ShardState.SlotID = 1
	for slot = 1, table.getn(ShardState.Slot), 1 do
		table.remove(ShardState.Slot, slot)
	end
	for slot = 1, GetContainerNumSlots(NecrosisConfig.SoulshardContainer), 1 do
		table.insert(ShardState.Slot, nil)
	end
end

-- Fonction qui fait l'inventaire des éléments utilisés en démonologie : Pierres, Fragments, Composants d'invocation
function Necrosis_BagExplore()
	local soulshards = ShardState.Count
	ShardState.Count = 0
	InfernalStone = 0
	DemoniacStone = 0
	Stones.Soulstone.OnHand = false
	Stones.Healthstone.OnHand = false
	Stones.Firestone.OnHand = false
	Stones.Felstone.OnHand = false
	Stones.Wrathstone.OnHand = false
	Stones.Voidstone.OnHand = false
	Stones.Spellstone.OnHand = false
	Stones.Hearthstone.OnHand = false
	ItemOnHand = false
	-- Parcours des sacs
	for container = 0, 4, 1 do
		-- Parcours des emplacements des sacs
		for slot = 1, GetContainerNumSlots(container), 1 do
			Necrosis_MoneyToggle()
			NecrosisTooltip:SetBagItem(container, slot)
			local itemName = tostring(NecrosisTooltipTextLeft1:GetText())
			local itemSwitch = tostring(NecrosisTooltipTextLeft3:GetText())
			local itemSwitch2 = tostring(NecrosisTooltipTextLeft4:GetText())
			-- Si le sac est le sac défini pour les fragments
			-- hop la valeur du Tableau qui représente le slot du Sac = nil (pas de Shard)
			if container == NecrosisConfig.SoulshardContainer then
				if itemName ~= NECROSIS_ITEM.Soulshard then
					ShardState.Slot[slot] = nil
				end
			end
			-- Dans le cas d'un emplacement non vide
			if itemName then
				-- On prend le nombre d'item en stack sur le slot
				local _, ItemCount = GetContainerItemInfo(container, slot)
				-- Si c'est un fragment ou une pierre infernale, alors on rajoute la qté au nombre de pierres
				if itemName == NECROSIS_ITEM.Soulshard then
					ShardState.Count = ShardState.Count + ItemCount
				end
				if itemName == NECROSIS_ITEM.InfernalStone then
					InfernalStone = InfernalStone + ItemCount
				end
				if itemName == NECROSIS_ITEM.DemoniacStone then
					DemoniacStone = DemoniacStone + ItemCount
				end
				-- Si c'est une pierre d'âme, on note son existence et son emplacement
				if string.find(itemName, NECROSIS_ITEM.Soulstone) then
					Stones.Soulstone.OnHand = true
					Stones.Soulstone.Location = { container, slot }
				end
				-- Même chose pour une pierre de soin
				if string.find(itemName, NECROSIS_ITEM.Healthstone) then
					Stones.Healthstone.OnHand = true
					Stones.Healthstone.Location = { container, slot }
				end
				-- Et encore pour la pierre de sort
				if string.find(itemName, NECROSIS_ITEM.Spellstone) then
					Stones.Spellstone.OnHand = true
					Stones.Spellstone.Location = { container, slot }
				end
				-- La pierre de feu maintenant
				if string.find(itemName, NECROSIS_ITEM.Firestone) then
					Stones.Firestone.OnHand = true
					Stones.Firestone.Location = { container, slot }
				end
				-- La Felstone
				if string.find(itemName, NECROSIS_ITEM.Felstone) then
					Stones.Felstone.OnHand = true
					Stones.Felstone.Location = { container, slot }
				end
				-- La Wrathstone
				if string.find(itemName, NECROSIS_ITEM.Wrathstone) then
					Stones.Wrathstone.OnHand = true
					Stones.Wrathstone.Location = { container, slot }
				end
				-- La Voidstone
				if string.find(itemName, NECROSIS_ITEM.Voidstone) then
					Stones.Voidstone.OnHand = true
					Stones.Voidstone.Location = { container, slot }
				end
				-- et enfin la pierre de foyer
				if string.find(itemName, NECROSIS_ITEM.Hearthstone) then
					Stones.Hearthstone.OnHand = true
					Stones.Hearthstone.Location = { container, slot }
				end

				-- On note aussi la présence ou non des objets "main gauche"
				-- Plus tard ce sera utilisé pour remplacer automatiquement une pierre absente
				if itemSwitch == NECROSIS_ITEM.Offhand or itemSwitch2 == NECROSIS_ITEM.Offhand then
					ItemOnHand = true
					ItemswitchLocation = { container, slot }
				end
			end
		end
	end

	-- Affichage du bouton principal de Necrosis
	if NecrosisConfig.Circle == 1 then
		if ShardState.Count <= 32 then
			NecrosisButton:SetNormalTexture(
				"Interface\\AddOns\\Necrosis\\UI\\" .. NecrosisConfig.NecrosisColor .. "\\Shard" .. ShardState.Count
			)
		else
			NecrosisButton:SetNormalTexture(
				"Interface\\AddOns\\Necrosis\\UI\\" .. NecrosisConfig.NecrosisColor .. "\\Shard32"
			)
		end
	elseif Stones.Soulstone.Mode == 1 or Stones.Soulstone.Mode == 2 then
		if ShardState.Count <= 32 then
			NecrosisButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Bleu\\Shard" .. ShardState.Count)
		else
			NecrosisButton:SetNormalTexture("Interface\\AddOns\\Necrosis\\UI\\Bleu\\Shard32")
		end
	end
	if NecrosisConfig.ShowCount then
		if NecrosisConfig.CountType == 2 then
			NecrosisShardCount:SetText(InfernalStone .. " / " .. DemoniacStone)
		elseif NecrosisConfig.CountType == 1 then
			if ShardState.Count < 10 then
				NecrosisShardCount:SetText("0" .. ShardState.Count)
			else
				NecrosisShardCount:SetText(ShardState.Count)
			end
		end
	else
		NecrosisShardCount:SetText("")
	end
	-- Et on met le tout à jour !
	Necrosis_UpdateIcons()

	-- S'il y a plus de fragment que d'emplacements dans le sac défini, on affiche un message d'avertissement
	if
		ShardState.Count > soulshards
		and ShardState.Count == GetContainerNumSlots(NecrosisConfig.SoulshardContainer)
	then
		if SoulshardDestroy then
			Necrosis_Msg(
				NECROSIS_MESSAGE.Bag.FullPrefix
					.. GetBagName(NecrosisConfig.SoulshardContainer)
					.. NECROSIS_MESSAGE.Bag.FullDestroySuffix
			)
		else
			Necrosis_Msg(
				NECROSIS_MESSAGE.Bag.FullPrefix
					.. GetBagName(NecrosisConfig.SoulshardContainer)
					.. NECROSIS_MESSAGE.Bag.FullSuffix
			)
		end
	end
end

-- Fonction qui permet de trouver / ranger les fragments dans les sacs
function Necrosis_SoulshardSwitch(type)
	if type == "CHECK" then
		ShardState.MP = 0
		for container = 0, 4, 1 do
			for i = 1, 3, 1 do
				if GetBagName(container) == NECROSIS_ITEM.SoulPouch[i] then
					BagIsSoulPouch[container + 1] = true
					break
				else
					BagIsSoulPouch[container + 1] = false
				end
			end
		end
	end
	for container = 0, 4, 1 do
		if BagIsSoulPouch[container + 1] then
			break
		end
		if container ~= NecrosisConfig.SoulshardContainer then
			for slot = 1, GetContainerNumSlots(container), 1 do
				Necrosis_MoneyToggle()
				NecrosisTooltip:SetBagItem(container, slot)
				local itemInfo = tostring(NecrosisTooltipTextLeft1:GetText())
				if itemInfo == NECROSIS_ITEM.Soulshard then
					if type == "CHECK" then
						ShardState.MP = ShardState.MP + 1
					elseif type == "MOVE" then
						Necrosis_FindSlot(container, slot)
						ShardState.MP = ShardState.MP - 1
					end
				end
			end
		end
	end
	-- Après avoir tout déplacer, il faut retrouver les emplacements des pierres, etc, etc...
	Necrosis_BagExplore()
end

-- Pendant le déplacement des fragments, il faut trouver un nouvel emplacement aux objets déplacés :)
function Necrosis_FindSlot(shardIndex, shardSlot)
	local full = true
	for slot = 1, GetContainerNumSlots(NecrosisConfig.SoulshardContainer), 1 do
		Necrosis_MoneyToggle()
		NecrosisTooltip:SetBagItem(NecrosisConfig.SoulshardContainer, slot)
		local itemInfo = tostring(NecrosisTooltipTextLeft1:GetText())
		if string.find(itemInfo, NECROSIS_ITEM.Soulshard) == nil then
			PickupContainerItem(shardIndex, shardSlot)
			PickupContainerItem(NecrosisConfig.SoulshardContainer, slot)
			ShardState.Slot[ShardState.SlotID] = slot
			ShardState.SlotID = ShardState.SlotID + 1
			if CursorHasItem() then
				if shardIndex == 0 then
					PutItemInBackpack()
				else
					PutItemInBag(19 + shardIndex)
				end
			end
			full = false
			break
		end
	end
	-- Destruction des fragments en sur-nombre si l'option est activée
	if full and NecrosisConfig.SoulshardDestroy then
		PickupContainerItem(shardIndex, shardSlot)
		if CursorHasItem() then
			DeleteCursorItem()
		end
	end
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS DES SORTS
------------------------------------------------------------------------------------------------------

-- Affiche ou masque les boutons de sort à chaque nouveau sort appris
function Necrosis_ButtonSetup()
	if NecrosisConfig.NecrosisLockServ then
		Necrosis_NoDrag()
		Necrosis_UpdateButtonsScale()
	else
		HideUIPanel(NecrosisPetMenuButton)
		HideUIPanel(NecrosisBuffMenuButton)
		HideUIPanel(NecrosisCurseMenuButton)
		HideUIPanel(NecrosisMountButton)
		HideUIPanel(NecrosisStoneMenuButton)
		HideUIPanel(NecrosisSpellstoneButton)
		HideUIPanel(NecrosisHealthstoneButton)
		HideUIPanel(NecrosisSoulstoneButton)
		if NecrosisConfig.StonePosition[1] and StoneMenuCreate ~= {} then
			ShowUIPanel(NecrosisStoneMenuButton)
		end
		if NecrosisConfig.StonePosition[2] and StoneIDInSpellTable[3] ~= 0 then
			ShowUIPanel(NecrosisSpellstoneButton)
		end
		if NecrosisConfig.StonePosition[3] and StoneIDInSpellTable[2] ~= 0 then
			ShowUIPanel(NecrosisHealthstoneButton)
		end
		if NecrosisConfig.StonePosition[4] and StoneIDInSpellTable[1] ~= 0 then
			ShowUIPanel(NecrosisSoulstoneButton)
		end
		if NecrosisConfig.StonePosition[5] and BuffMenuCreate ~= {} then
			ShowUIPanel(NecrosisBuffMenuButton)
		end
		if NecrosisConfig.StonePosition[6] and MountState.Available then
			ShowUIPanel(NecrosisMountButton)
		end
		if NecrosisConfig.StonePosition[7] and PetMenuCreate ~= {} then
			ShowUIPanel(NecrosisPetMenuButton)
		end
		if NecrosisConfig.StonePosition[8] and CurseMenuCreate ~= {} then
			ShowUIPanel(NecrosisCurseMenuButton)
		end
	end
end

-- Ma fonction préférée ! Elle fait la liste des sorts connus par le démo, et les classe par rang.
-- Pour les pierres, elle sélectionne le plus haut rang connu
function Necrosis_SpellSetup()
	local StoneType = {
		NECROSIS_ITEM.Soulstone,
		NECROSIS_ITEM.Healthstone,
		NECROSIS_ITEM.Spellstone,
		NECROSIS_ITEM.Firestone,
		NECROSIS_ITEM.Felstone,
		NECROSIS_ITEM.Wrathstone,
		NECROSIS_ITEM.Voidstone,
	}
	local StoneMaxRank = { 0, 0, 0, 0, 0, 0, 0 }

	local CurrentStone = {
		ID = {},
		Name = {},
		subName = {},
	}

	local CurrentSpells = {
		ID = {},
		Name = {},
		subName = {},
	}

	local spellID = 1
	local Invisible = 0
	local InvisibleID = 0

	-- On va parcourir tous les sorts possedés par le Démoniste
	while true do
		local spellName, subSpellName = GetSpellName(spellID, BOOKTYPE_SPELL)

		if not spellName then
			do
				break
			end
		end

		-- Pour les sorts avec des rangs numérotés, on compare pour chaque sort les rangs 1 à 1
		-- Le rang supérieur est conservé
		if string.find(subSpellName, NECROSIS_TRANSLATION.Rank) then
			local found = false
			local rank = tonumber(strsub(subSpellName, 6, strlen(subSpellName)))
			for index = 1, table.getn(CurrentSpells.Name), 1 do
				if CurrentSpells.Name[index] == spellName then
					found = true
					if CurrentSpells.subName[index] < rank then
						CurrentSpells.ID[index] = spellID
						CurrentSpells.subName[index] = rank
					end
					break
				end
			end
			-- Les plus grands rangs de chacun des sorts à rang numérotés sont insérés dans la table
			if not found then
				table.insert(CurrentSpells.ID, spellID)
				table.insert(CurrentSpells.Name, spellName)
				table.insert(CurrentSpells.subName, rank)
			end
		end

		-- Test du Rang de la détection d'invisibilité
		if spellName == NECROSIS_TRANSLATION.GreaterInvisible then
			Invisible = 3
			InvisibleID = spellID
		elseif spellName == NECROSIS_TRANSLATION.Invisible and Invisible ~= 3 then
			Invisible = 2
			InvisibleID = spellID
		elseif spellName == NECROSIS_TRANSLATION.LesserInvisible and Invisible ~= 3 and Invisible ~= 2 then
			Invisible = 1
			InvisibleID = spellID
		end

		-- Les pierres n'ont pas de rang numéroté, l'attribut de rang fait partie du nom du sort
		-- Pour chaque type de pierre, on va donc faire....
		for stoneID = 1, table.getn(StoneType), 1 do
			-- Si le sort étudié est bien une invocation de ce type de pierre et qu'on n'a pas
			-- déjà assigné un rang maximum à cette dernière
			if
				(string.find(spellName, StoneType[stoneID]))
				and StoneMaxRank[stoneID] ~= table.getn(NECROSIS_STONE_RANK)
			then
				-- Récupération de la fin du nom de la pierre, contenant son rang
				local stoneSuffix = string.sub(spellName, string.len(NECROSIS_CREATE[stoneID]) + 1)
				-- Reste à trouver la correspondance de son rang
				for rankID = 1, table.getn(NECROSIS_STONE_RANK), 1 do
					-- Si la fin du nom de la pierre correspond à une taille de pierre, on note le rang !
					if string.lower(stoneSuffix) == string.lower(NECROSIS_STONE_RANK[rankID]) then
						-- On a une pierre, on a son rang, reste à vérifier si c'est la plus puissante,
						-- et si oui, l'enregistrer
						if rankID > StoneMaxRank[stoneID] then
							StoneMaxRank[stoneID] = rankID
							CurrentStone.Name[stoneID] = spellName
							CurrentStone.subName[stoneID] = NECROSIS_STONE_RANK[rankID]
							CurrentStone.ID[stoneID] = spellID
						end
						break
					end
				end
			end
		end

		spellID = spellID + 1
	end

	-- On insère dans la table les pierres avec le plus grand rang
	for stoneID = 1, table.getn(StoneType), 1 do
		if StoneMaxRank[stoneID] ~= 0 then
			table.insert(NECROSIS_SPELL_TABLE, {
				ID = CurrentStone.ID[stoneID],
				Name = CurrentStone.Name[stoneID],
				Rank = 0,
				CastTime = 0,
				Length = 0,
				Type = 0,
			})
			StoneIDInSpellTable[stoneID] = table.getn(NECROSIS_SPELL_TABLE)
		end
	end
	-- On met à jour la liste des sorts avec les nouveaux rangs
	for spell = 1, table.getn(NECROSIS_SPELL_TABLE), 1 do
		for index = 1, table.getn(CurrentSpells.Name), 1 do
			if
				(NECROSIS_SPELL_TABLE[spell].Name == CurrentSpells.Name[index])
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[1]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[2]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[3]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[4]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[5]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[6]
				and NECROSIS_SPELL_TABLE[spell].ID ~= StoneIDInSpellTable[7]
			then
				NECROSIS_SPELL_TABLE[spell].ID = CurrentSpells.ID[index]
				NECROSIS_SPELL_TABLE[spell].Rank = CurrentSpells.subName[index]
			end
		end
	end

	-- On met à jour la durée de chaque sort en fonction de son rang
	for index = 1, table.getn(NECROSIS_SPELL_TABLE), 1 do
		if index == 9 then -- si Bannish
			if NECROSIS_SPELL_TABLE[index].ID ~= nil then
				NECROSIS_SPELL_TABLE[index].Length = NECROSIS_SPELL_TABLE[index].Rank * 10 + 10
			end
		end
		if index == 13 then -- si Fear
			if NECROSIS_SPELL_TABLE[index].ID ~= nil then
				NECROSIS_SPELL_TABLE[index].Length = NECROSIS_SPELL_TABLE[index].Rank * 5 + 5
			end
		end
		if index == 14 then -- si Corruption
			if NECROSIS_SPELL_TABLE[index].ID ~= nil and NECROSIS_SPELL_TABLE[index].Rank <= 2 then
				NECROSIS_SPELL_TABLE[index].Length = NECROSIS_SPELL_TABLE[index].Rank * 3 + 9
			end
		end
	end

	for spellID = 1, MAX_SPELLS, 1 do
		local spellName, subSpellName = GetSpellName(spellID, "spell")
		if spellName then
			for index = 1, table.getn(NECROSIS_SPELL_TABLE), 1 do
				if NECROSIS_SPELL_TABLE[index].Name == spellName then
					Necrosis_MoneyToggle()
					NecrosisTooltip:SetSpell(spellID, 1)
					local _, _, ManaCost = string.find(NecrosisTooltipTextLeft2:GetText(), "(%d+)")
					if not NECROSIS_SPELL_TABLE[index].ID then
						NECROSIS_SPELL_TABLE[index].ID = spellID
					end
					NECROSIS_SPELL_TABLE[index].Mana = tonumber(ManaCost)
				end
			end
		end
	end
	if NECROSIS_SPELL_TABLE[1].ID or NECROSIS_SPELL_TABLE[2].ID then
		MountState.Available = true
	else
		MountState.Available = false
	end

	-- Insertion du plus haut rang de détection d'invisibilité connu
	if Invisible >= 1 then
		NECROSIS_SPELL_TABLE[33].ID = InvisibleID
		NECROSIS_SPELL_TABLE[33].Rank = 0
		NECROSIS_SPELL_TABLE[33].CastTime = 0
		NECROSIS_SPELL_TABLE[33].Length = 0
		Necrosis_MoneyToggle()
		NecrosisTooltip:SetSpell(InvisibleID, 1)
		local _, _, ManaCost = string.find(NecrosisTooltipTextLeft2:GetText(), "(%d+)")
		NECROSIS_SPELL_TABLE[33].Mana = tonumber(ManaCost)
	end
end

-- Fonction d'extraction d'attribut de sort
-- F(type=string, string, int) -> Spell=table
function Necrosis_FindSpellAttribute(type, attribute, array)
	for index = 1, table.getn(NECROSIS_SPELL_TABLE), 1 do
		if string.find(NECROSIS_SPELL_TABLE[index][type], attribute) then
			return NECROSIS_SPELL_TABLE[index][array]
		end
	end
	return nil
end

-- Fonction pour caster un Eclat d'ombre depuis le bouton de la Transe de l'Ombre
-- L'éclat doit avoir le rang le plus haut
function Necrosis_CastShadowBolt()
	local spellID = Necrosis_FindSpellAttribute("Name", NECROSIS_NIGHTFALL.BoltName, "ID")
	if spellID then
		CastSpell(spellID, "spell")
	else
		Necrosis_Msg(NECROSIS_NIGHTFALL_TEXT.NoBoltSpell, "USER")
	end
end

------------------------------------------------------------------------------------------------------
-- FONCTIONS DIVERSES
------------------------------------------------------------------------------------------------------

-- Fonction pour savoir si une unité subit un effet
-- F(string, string)->bool
function Necrosis_UnitHasEffect(unit, effect)
	local index = 1
	while UnitDebuff(unit, index) do
		Necrosis_MoneyToggle()
		NecrosisTooltip:SetUnitDebuff(unit, index)
		local DebuffName = tostring(NecrosisTooltipTextLeft1:GetText())
		if string.find(DebuffName, effect) then
			return true
		end
		index = index + 1
	end
	return false
end

-- Function to check the presence of a buff on the unit.
-- Strictly identical to UnitHasEffect, but as WoW distinguishes Buff and DeBuff, so we have to.
function Necrosis_UnitHasBuff(unit, effect)
	local index = 1
	while UnitBuff(unit, index) do
		-- Here we'll cheat a little. checking a buff or debuff return the internal spell name, and not the name we give at start
		-- So we use an API widget that will use the internal name to return the known name.
		-- For example, the "Curse of Agony" spell is internaly known as "Spell_Shadow_CurseOfSargeras". Much easier to use the first one than the internal one.
		Necrosis_MoneyToggle()
		NecrosisTooltip:SetUnitBuff(unit, index)
		local BuffName = tostring(NecrosisTooltipTextLeft1:GetText())
		if string.find(BuffName, effect) then
			return true
		end
		index = index + 1
	end
	return false
end

-- Permet de reconnaitre quand le joueur gagne Crépuscule / Transe de l'ombre
function Necrosis_UnitHasTrance()
	local ID = -1
	for buffID = 0, 24, 1 do
		local buffTexture = GetPlayerBuffTexture(buffID)
		if buffTexture == nil then
			break
		end
		if strfind(buffTexture, "Spell_Shadow_Twilight") then
			ID = buffID
			break
		end
	end
	BuffAlert.ShadowTranceID = ID
end

-- Fonction pour gérer les actions effectuées par Necrosis au clic sur un bouton
function Necrosis_UseItem(type, button)
	Necrosis_MoneyToggle()
	NecrosisTooltip:SetBagItem("player", 17)
	local rightHand = tostring(NecrosisTooltipTextLeft1:GetText())

	-- Fonction pour utiliser une pierre de foyer dans l'inventaire
	-- s'il y en a une dans l'inventaire, et si c'était un click droit
	if type == "Hearthstone" and button == "RightButton" then
		if Stones.Hearthstone.OnHand then
			-- on l'utilise
			UseContainerItem(Stones.Hearthstone.Location[1], Stones.Hearthstone.Location[2])
		-- soit il n'y en a pas dans l'inventaire, on affiche un message d'erreur
		else
			Necrosis_Msg(NECROSIS_MESSAGE.Error.NoHearthStone, "USER")
		end
	end

	-- Si on clique sur le bouton de la pierre d'âme
	-- On met à jour le bouton pour savoir quel est le mode
	if type == "Soulstone" then
		Necrosis_UpdateIcons()
		-- Si le mode = 2 (une pierre dans l'inventaire, pas de pierre utilisée)
		-- alors on l'utilise
		if Stones.Soulstone.Mode == 2 then
			-- Si un joueur est ciblé, sur le joueur (avec message d'alerte)
			-- Si un joueur n'est pas ciblé, sur le Démoniste (sans message)
			if UnitIsPlayer("target") then
				Stones.Soulstone.UsedOnTarget = true
			else
				Stones.Soulstone.UsedOnTarget = false
				TargetUnit("player")
			end
			UseContainerItem(Stones.Soulstone.Location[1], Stones.Soulstone.Location[2])
			-- Maintenant que l'on crée un timer sur la session, nous ne sortons plus d'un RL
			NecrosisRL = false
			-- Et hop, on remet à jour l'affichage des boutons :)
			Necrosis_UpdateIcons()
		-- si il n'y a pas de pierre d'âme dans l'inventaire, alors on crée la pierre d'âme de rang le plus grand :)
		elseif (Stones.Soulstone.Mode == 1) or (Stones.Soulstone.Mode == 3) then
			if StoneIDInSpellTable[1] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[1]].ID, "spell")
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoSoulStoneSpell, "USER")
			end
		end
	-- Si on clique sur le bouton de la pierre de vie :
	elseif type == "Healthstone" then
		-- soit il y en a une dans l'inventaire
		if Stones.Healthstone.OnHand then
			-- Dans ce cas si un pj allié est sélectionné, on lui donne la pierre
			-- Sinon, on l'utilise
			if TradeState.Request then
				PickupContainerItem(Stones.Healthstone.Location[1], Stones.Healthstone.Location[2])
				ClickTradeButton(1)
				TradeState.Request = false
				TradeState.Trading = true
				TradeState.TradingNow = 3
				return
			elseif
				UnitExists("target")
				and UnitIsPlayer("target")
				and (not UnitCanAttack("player", "target"))
				and UnitName("target") ~= UnitName("player")
			then
				PickupContainerItem(Stones.Healthstone.Location[1], Stones.Healthstone.Location[2])
				if CursorHasItem() then
					DropItemOnUnit("target")
					TradeState.Trading = true
					TradeState.TradingNow = 3
				end
				return
			end
			if UnitHealth("player") == UnitHealthMax("player") then
				Necrosis_Msg(NECROSIS_MESSAGE.Error.FullHealth, "USER")
			else
				SpellStopCasting()
				UseContainerItem(Stones.Healthstone.Location[1], Stones.Healthstone.Location[2])

				-- Inserts a timer for the Healthstone if not already present
				local HealthstoneInUse = false
				if Necrosis_TimerExisteDeja(NECROSIS_COOLDOWN.Healthstone, SpellTimer) then
					HealthstoneInUse = true
				end
				if not HealthstoneInUse then
					SpellGroup, SpellTimer, TimerTable =
						Necrosis_InsertTimerStone(type, nil, nil, SpellGroup, SpellTimer, TimerTable)
				end

				-- Healthstone shares its cooldown with Spellstone, so we add both timers at the same time, but only if Spellstone is known
				local SpellstoneInUse = false
				if Necrosis_TimerExisteDeja(NECROSIS_COOLDOWN.Spellstone, SpellTimer) then
					SpellstoneInUse = true
				end
				if not SpellstoneInUse and StoneIDInSpellTable[3] ~= 0 then
					SpellGroup, SpellTimer, TimerTable =
						Necrosis_InsertTimerStone("Spellstone", nil, nil, SpellGroup, SpellTimer, TimerTable)
				end
			end
		-- soit il n'y en a pas dans l'inventaire, et la pierre de plus haut rang est créée
		else
			if StoneIDInSpellTable[2] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[2]].ID, "spell")
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoHealthStoneSpell, "USER")
			end
		end
	-- Au tour de la pierre de sort
	elseif type == "Spellstone" then
		-- soit il y en a une dans l'inventaire
		if Stones.Spellstone.OnHand then
			local start, duration, enabled =
				GetContainerItemCooldown(Stones.Spellstone.Location[1], Stones.Spellstone.Location[2])
			if start > 0 then
				Necrosis_Msg(NECROSIS_MESSAGE.Error.SpellStoneIsOnCooldown, "USER")
			else
				SpellStopCasting()
				UseContainerItem(Stones.Spellstone.Location[1], Stones.Spellstone.Location[2])

				-- Inserts a timer for the Spellstone if not already present
				local SpellstoneInUse = false
				if Necrosis_TimerExisteDeja(NECROSIS_COOLDOWN.Spellstone, SpellTimer) then
					SpellstoneInUse = true
				end
				if not SpellstoneInUse then
					SpellGroup, SpellTimer, TimerTable =
						Necrosis_InsertTimerStone(type, nil, nil, SpellGroup, SpellTimer, TimerTable)
				end

				-- Spellstone shares its cooldown with Healthstone, so we add both timers at the same time
				local HealthstoneInUse = false
				if Necrosis_TimerExisteDeja(NECROSIS_COOLDOWN.Healthstone, SpellTimer) then
					HealthstoneInUse = true
				end
				if not HealthstoneInUse and StoneIDInSpellTable[2] ~= 0 then
					SpellGroup, SpellTimer, TimerTable =
						Necrosis_InsertTimerStone("Healthstone", nil, nil, SpellGroup, SpellTimer, TimerTable)
				end
			end
		else
			if StoneIDInSpellTable[3] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[3]].ID, "spell")
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoSpellStoneSpell, "USER")
			end
		end
	-- Meme chose pour la pierre de feu
	elseif type == "Firestone" then
		-- soit il y en a une dans l'inventaire
		if Stones.Firestone.OnHand then
			SpellStopCasting()
			UseContainerItem(Stones.Firestone.Location[1], Stones.Firestone.Location[2])
		else
			if StoneIDInSpellTable[4] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[4]].ID, "spell")
				Necrosis_UpdateIcons()
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoFireStoneSpell, "USER")
			end
		end
	-- Felstone
	elseif type == "Felstone" then
		if Stones.Felstone.OnHand then
			SpellStopCasting()
			UseContainerItem(Stones.Felstone.Location[1], Stones.Felstone.Location[2])
		else
			if StoneIDInSpellTable[5] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[5]].ID, "spell")
				Necrosis_UpdateIcons()
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoFelStoneSpell, "USER")
			end
		end
	-- Wrathstone
	elseif type == "Wrathstone" then
		if Stones.Wrathstone.OnHand then
			SpellStopCasting()
			UseContainerItem(Stones.Wrathstone.Location[1], Stones.Wrathstone.Location[2])
		else
			if StoneIDInSpellTable[6] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[6]].ID, "spell")
				Necrosis_UpdateIcons()
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoWrathStoneSpell, "USER")
			end
		end
	-- Voidstone
	elseif type == "Voidstone" then
		if Stones.Voidstone.OnHand then
			SpellStopCasting()
			UseContainerItem(Stones.Voidstone.Location[1], Stones.Voidstone.Location[2])
		else
			if StoneIDInSpellTable[7] ~= 0 then
				CastSpell(NECROSIS_SPELL_TABLE[StoneIDInSpellTable[7]].ID, "spell")
				Necrosis_UpdateIcons()
			else
				Necrosis_Msg(NECROSIS_MESSAGE.Error.NoVoidStoneSpell, "USER")
			end
		end
	-- Si on clic sur le bouton de monture
	elseif type == "Mount" then
		-- Soit c'est la monture épique
		if NECROSIS_SPELL_TABLE[2].ID ~= nil then
			CastSpell(NECROSIS_SPELL_TABLE[2].ID, "spell")
			Necrosis_OnUpdate()
		-- Soit c'est la monture classique
		elseif NECROSIS_SPELL_TABLE[1].ID ~= nil then
			CastSpell(NECROSIS_SPELL_TABLE[1].ID, "spell")
			Necrosis_OnUpdate()
		-- (Soit c'est rien :) )
		else
			Necrosis_Msg(NECROSIS_MESSAGE.Error.NoRiding, "USER")
		end
	end
end

-- Fonction permettant de permutter un objet main-gauche équipé avec un objet main-gauche de l'inventaire
function Necrosis_SwitchOffHand(type)
	if type == "Spellstone" then
		if Stones.Spellstone.Mode == 3 then
			if ItemOnHand then
				Necrosis_Msg(
					"Equipe "
						.. GetContainerItemLink(ItemswitchLocation[1], ItemswitchLocation[2])
						.. NECROSIS_MESSAGE.SwitchMessage
						.. GetInventoryItemLink("player", 17),
					"USER"
				)
				PickupInventoryItem(17)
				PickupContainerItem(ItemswitchLocation[1], ItemswitchLocation[2])
			end
			return
		else
			PickupContainerItem(Stones.Spellstone.Location[1], Stones.Spellstone.Location[2])
			PickupInventoryItem(17)
			-- Le switch avec une pierre de sort implique un cooldown porté au timer
			if Necrosis_TimerExisteDeja(NECROSIS_COOLDOWN.Spellstone, SpellTimer) then
				SpellTimer, TimerTable =
					Necrosis_RetraitTimerParNom(NECROSIS_COOLDOWN.Spellstone, SpellTimer, TimerTable)
			end
			SpellGroup, SpellTimer, TimerTable =
				Necrosis_InsertTimerStone(type, nil, nil, SpellGroup, SpellTimer, TimerTable)
			return
		end
	end
	if (type == "OffHand") and UnitClass("player") == NECROSIS_UNIT_WARLOCK then
		if ItemswitchLocation[1] ~= nil and ItemswitchLocation[2] ~= nil then
			PickupContainerItem(ItemswitchLocation[1], ItemswitchLocation[2])
			PickupInventoryItem(17)
		end
	end
end

function Necrosis_MoneyToggle()
	for index = 1, 10 do
		local text = getglobal("NecrosisTooltipTextLeft" .. index)
		text:SetText(nil)
		text = getglobal("NecrosisTooltipTextRight" .. index)
		text:SetText(nil)
	end
	NecrosisTooltip:Hide()
	NecrosisTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
end

function Necrosis_GameTooltip_ClearMoney()
	-- Intentionally empty; don't clear money while we use hidden tooltips
end

-- Fonction pour placer les boutons autour de Necrosis (et pour grossir / retracir l'interface...)
function Necrosis_UpdateButtonsScale()
	local NBRScale = (100 + (NecrosisConfig.NecrosisButtonScale - 85)) / 100
	if NecrosisConfig.NecrosisButtonScale <= 95 then
		NBRScale = 1.1
	end
	if NecrosisConfig.NecrosisLockServ then
		Necrosis_ClearAllPoints()
		HideUIPanel(NecrosisPetMenuButton)
		HideUIPanel(NecrosisBuffMenuButton)
		HideUIPanel(NecrosisCurseMenuButton)
		HideUIPanel(NecrosisMountButton)
		HideUIPanel(NecrosisStoneMenuButton)
		HideUIPanel(NecrosisSpellstoneButton)
		HideUIPanel(NecrosisHealthstoneButton)
		HideUIPanel(NecrosisSoulstoneButton)
		local indexScale = -36
		for index = 1, 8, 1 do
			if NecrosisConfig.StonePosition[index] then
				if index == 1 and StoneMenuCreate ~= {} then
					NecrosisStoneMenuButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisStoneMenuButton)
					indexScale = indexScale + 36
				end
				if index == 2 and StoneIDInSpellTable[3] ~= 0 then
					NecrosisSpellstoneButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisSpellstoneButton)
					indexScale = indexScale + 36
				end
				if index == 3 and StoneIDInSpellTable[2] ~= 0 then
					NecrosisHealthstoneButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisHealthstoneButton)
					indexScale = indexScale + 36
				end
				if index == 4 and StoneIDInSpellTable[1] ~= 0 then
					NecrosisSoulstoneButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisSoulstoneButton)
					indexScale = indexScale + 36
				end
				if index == 5 and BuffMenuCreate ~= {} then
					NecrosisBuffMenuButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisBuffMenuButton)
					indexScale = indexScale + 36
				end
				if index == 6 and MountState.Available then
					NecrosisMountButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisMountButton)
					indexScale = indexScale + 36
				end
				if index == 7 and PetMenuCreate ~= {} then
					NecrosisPetMenuButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisPetMenuButton)
					indexScale = indexScale + 36
				end
				if index == 8 and CurseMenuCreate ~= {} then
					NecrosisCurseMenuButton:SetPoint(
						"CENTER",
						"NecrosisButton",
						"CENTER",
						((40 * NBRScale) * cos(NecrosisConfig.NecrosisAngle - indexScale)),
						((40 * NBRScale) * sin(NecrosisConfig.NecrosisAngle - indexScale))
					)
					ShowUIPanel(NecrosisCurseMenuButton)
					indexScale = indexScale + 36
				end
			end
		end
	end
end

-- Fonction (XML) pour rétablir les points d'attache par défaut des boutons
function Necrosis_ClearAllPoints()
	NecrosisStoneMenuButton:ClearAllPoints()
	NecrosisSpellstoneButton:ClearAllPoints()
	NecrosisHealthstoneButton:ClearAllPoints()
	NecrosisSoulstoneButton:ClearAllPoints()
	NecrosisMountButton:ClearAllPoints()
	NecrosisPetMenuButton:ClearAllPoints()
	NecrosisBuffMenuButton:ClearAllPoints()
	NecrosisCurseMenuButton:ClearAllPoints()
end

-- Fonction (XML) pour étendre la propriété NoDrag() du bouton principal de Necrosis sur tout ses boutons
function Necrosis_NoDrag()
	NecrosisStoneMenuButton:RegisterForDrag("")
	NecrosisSpellstoneButton:RegisterForDrag("")
	NecrosisHealthstoneButton:RegisterForDrag("")
	NecrosisSoulstoneButton:RegisterForDrag("")
	NecrosisMountButton:RegisterForDrag("")
	NecrosisPetMenuButton:RegisterForDrag("")
	NecrosisBuffMenuButton:RegisterForDrag("")
	NecrosisCurseMenuButton:RegisterForDrag("")
end

-- Fonction (XML) inverse de celle du dessus
function Necrosis_Drag()
	NecrosisStoneMenuButton:RegisterForDrag("LeftButton")
	NecrosisSpellstoneButton:RegisterForDrag("LeftButton")
	NecrosisHealthstoneButton:RegisterForDrag("LeftButton")
	NecrosisSoulstoneButton:RegisterForDrag("LeftButton")
	NecrosisMountButton:RegisterForDrag("LeftButton")
	NecrosisPetMenuButton:RegisterForDrag("LeftButton")
	NecrosisBuffMenuButton:RegisterForDrag("LeftButton")
	NecrosisCurseMenuButton:RegisterForDrag("LeftButton")
end

-- Ouverture du menu des buffs
function Necrosis_BuffMenu(button)
	if button == "MiddleButton" and MenuState.LastBuff ~= 0 then
		Necrosis_BuffCast(MenuState.LastBuff)
		return
	end
	MenuState.BuffMenuShow = not MenuState.BuffMenuShow
	if not MenuState.BuffMenuShow then
		MenuState.BuffShow = false
		MenuState.BuffVisible = false
		NecrosisBuffMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\BuffMenuButton-01")
		BuffMenuCreate[1]:ClearAllPoints()
		BuffMenuCreate[1]:SetPoint("CENTER", "NecrosisBuffMenuButton", "CENTER", 3000, 3000)
		MenuState.AlphaBuffMenu = 1
	else
		MenuState.BuffShow = true
		NecrosisBuffMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\BuffMenuButton-02")
		-- Si clic droit, le menu de buff reste ouvert
		if button == "RightButton" then
			MenuState.BuffVisible = true
		end
		-- S'il n'existe aucun buff on ne fait rien
		if BuffMenuCreate == nil then
			return
		end
		-- Sinon on affiche les icones
		NecrosisBuffMenu1:SetAlpha(1)
		NecrosisBuffMenu2:SetAlpha(1)
		NecrosisBuffMenu3:SetAlpha(1)
		NecrosisBuffMenu4:SetAlpha(1)
		NecrosisBuffMenu5:SetAlpha(1)
		NecrosisBuffMenu6:SetAlpha(1)
		NecrosisBuffMenu7:SetAlpha(1)
		NecrosisBuffMenu8:SetAlpha(1)
		NecrosisBuffMenu9:SetAlpha(1)
		BuffMenuCreate[1]:ClearAllPoints()
		BuffMenuCreate[1]:SetPoint(
			"CENTER",
			"NecrosisBuffMenuButton",
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			26
		)
		MenuState.AlphaPetVar = GetTime() + 3
		MenuState.AlphaBuffVar = GetTime() + 6
		MenuState.AlphaCurseVar = GetTime() + 6
	end
end

-- Ouverture du menu des curses
function Necrosis_CurseMenu(button)
	if button == "MiddleButton" and MenuState.LastCurse ~= 0 then
		Necrosis_CurseCast(MenuState.LastCurse, MenuState.LastCurseClick)
		return
	end
	-- S'il n'existe aucune curse on ne fait rien
	if CurseMenuCreate[1] == nil then
		return
	end
	MenuState.CurseMenuShow = not MenuState.CurseMenuShow
	if not MenuState.CurseMenuShow then
		MenuState.CurseShow = false
		MenuState.CurseVisible = false
		NecrosisCurseMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\CurseMenuButton-01")
		CurseMenuCreate[1]:ClearAllPoints()
		CurseMenuCreate[1]:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		MenuState.AlphaCurseMenu = 1
	else
		MenuState.CurseShow = true
		NecrosisCurseMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\CurseMenuButton-02")
		-- Si clic droit, le menu de curse reste ouvert
		if button == "RightButton" then
			MenuState.CurseVisible = true
		end
		-- Sinon on affiche les icones
		NecrosisCurseMenu1:SetAlpha(1)
		NecrosisCurseMenu2:SetAlpha(1)
		NecrosisCurseMenu3:SetAlpha(1)
		NecrosisCurseMenu4:SetAlpha(1)
		NecrosisCurseMenu5:SetAlpha(1)
		NecrosisCurseMenu6:SetAlpha(1)
		NecrosisCurseMenu7:SetAlpha(1)
		NecrosisCurseMenu8:SetAlpha(1)
		NecrosisCurseMenu9:SetAlpha(1)
		CurseMenuCreate[1]:ClearAllPoints()
		CurseMenuCreate[1]:SetPoint(
			"CENTER",
			"NecrosisCurseMenuButton",
			"CENTER",
			((36 / NecrosisConfig.CurseMenuPos) * 31),
			-26
		)
		MenuState.AlphaPetVar = GetTime() + 3
		MenuState.AlphaBuffVar = GetTime() + 6
		MenuState.AlphaCurseVar = GetTime() + 6
	end
end

-- Ouverture du menu des démons
function Necrosis_PetMenu(button)
	if button == "MiddleButton" and MenuState.LastDemon ~= 0 then
		Necrosis_PetCast(MenuState.LastDemon)
		return
	end
	-- S'il n'existe aucun sort d'invocation on ne fait rien
	if PetMenuCreate[1] == nil then
		return
	end
	MenuState.PetMenuShow = not MenuState.PetMenuShow
	if not MenuState.PetMenuShow then
		MenuState.PetShow = false
		MenuState.PetVisible = false
		NecrosisPetMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\PetMenuButton-01")
		PetMenuCreate[1]:ClearAllPoints()
		PetMenuCreate[1]:SetPoint("CENTER", "NecrosisPetMenuButton", "CENTER", 3000, 3000)
		MenuState.AlphaPetMenu = 1
	else
		MenuState.PetShow = true
		NecrosisPetMenuButton:SetNormalTexture("Interface\\Addons\\Necrosis\\UI\\PetMenuButton-02")
		-- Si clic droit, le menu de pet reste ouvert
		if button == "RightButton" then
			MenuState.PetVisible = true
		end
		-- Sinon on affiche les icones (on les déplace sur l'écran)
		NecrosisPetMenu1:SetAlpha(1)
		NecrosisPetMenu2:SetAlpha(1)
		NecrosisPetMenu3:SetAlpha(1)
		NecrosisPetMenu4:SetAlpha(1)
		NecrosisPetMenu5:SetAlpha(1)
		NecrosisPetMenu6:SetAlpha(1)
		NecrosisPetMenu7:SetAlpha(1)
		NecrosisPetMenu8:SetAlpha(1)
		NecrosisPetMenu9:SetAlpha(1)
		PetMenuCreate[1]:ClearAllPoints()
		PetMenuCreate[1]:SetPoint(
			"CENTER",
			"NecrosisPetMenuButton",
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			26
		)
		MenuState.AlphaPetVar = GetTime() + 3
	end
end

-- Ouverture du menu des stones
function Necrosis_StoneMenu(button)
	if button == "MiddleButton" and NecrosisConfig.LastStone ~= "" then
		Necrosis_UseStone(NecrosisConfig.LastStone, "LeftButton")
		return
	end
	MenuState.StoneMenuShow = not MenuState.StoneMenuShow
	if not MenuState.StoneMenuShow then
		MenuState.StoneShow = false
		MenuState.StoneVisible = false
		SetStoneMenuTextures()
		if StoneMenuCreate[1] then
			StoneMenuCreate[1]:ClearAllPoints()
			StoneMenuCreate[1]:SetPoint("CENTER", "NecrosisStoneMenuButton", "CENTER", 3000, 3000)
		end
		MenuState.AlphaStoneMenu = 1
	else
		MenuState.StoneShow = true
		SetStoneMenuTexturesForMenuOpen()
		-- Si clic droit, le menu de stone reste ouvert
		if button == "RightButton" then
			MenuState.StoneVisible = true
		end
		-- Sinon on affiche les icones
		if StoneMenuCreate[1] then
			NecrosisStoneMenu1:SetAlpha(1)
			NecrosisStoneMenu2:SetAlpha(1)
			NecrosisStoneMenu3:SetAlpha(1)
			NecrosisStoneMenu4:SetAlpha(1)
			StoneMenuCreate[1]:ClearAllPoints()
			StoneMenuCreate[1]:SetPoint(
				"CENTER",
				"NecrosisStoneMenuButton",
				"CENTER",
				((36 / NecrosisConfig.StoneMenuPos) * 31),
				-26
			)
			MenuState.AlphaStoneVar = GetTime() + 6
		end
	end
end

-- Fonction pour utiliser une stone depuis le menu
function Necrosis_UseStone(stoneType, button)
	NecrosisConfig.LastStone = stoneType
	Necrosis_UseItem(stoneType, button)
end

-- A chaque changement du livre des sorts, au démarrage du mod, ainsi qu'au changement de sens du menu on reconstruit les menus des sorts
function Necrosis_CreateMenu()
	PetMenuCreate = {}
	CurseMenuCreate = {}
	BuffMenuCreate = {}
	StoneMenuCreate = {}
	local menuVariable = nil
	local PetButtonPosition = 0
	local BuffButtonPosition = 0
	local CurseButtonPosition = 0
	local StoneButtonPosition = 0

	-- On cache toutes les icones des démons
	for i = 1, 9, 1 do
		menuVariable = getglobal("NecrosisPetMenu" .. i)
		menuVariable:Hide()
	end
	-- On cache toutes les icones des sorts
	for i = 1, 9, 1 do
		menuVariable = getglobal("NecrosisBuffMenu" .. i)
		menuVariable:Hide()
	end
	-- On cache toutes les icones des curses
	for i = 1, 9, 1 do
		menuVariable = getglobal("NecrosisCurseMenu" .. i)
		menuVariable:Hide()
	end
	-- On cache toutes les icones des stones
	for i = 1, 4, 1 do
		menuVariable = getglobal("NecrosisStoneMenu" .. i)
		menuVariable:Hide()
	end

	-- Si le sort de Domination corrompue existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[15].ID then
		menuVariable = getglobal("NecrosisPetMenu1")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint("CENTER", "NecrosisPetMenuButton", "CENTER", 3000, 3000)
		PetButtonPosition = 1
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation du Diablotin existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[3].ID then
		menuVariable = getglobal("NecrosisPetMenu2")
		menuVariable:ClearAllPoints()
		if PetButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisPetMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisPetMenu" .. PetButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.PetMenuPos) * 31),
				0
			)
		end
		PetButtonPosition = 2
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation du Marcheur existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[4].ID then
		menuVariable = getglobal("NecrosisPetMenu3")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 3
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation du Succube existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[5].ID then
		menuVariable = getglobal("NecrosisPetMenu4")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 4
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation du Felhunter existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[6].ID then
		menuVariable = getglobal("NecrosisPetMenu5")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 5
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation de l'Infernal existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[8].ID then
		menuVariable = getglobal("NecrosisPetMenu6")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 6
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'invocation du Doomguard existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[30].ID then
		menuVariable = getglobal("NecrosisPetMenu7")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 7
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si l'asservissement existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[35].ID then
		menuVariable = getglobal("NecrosisPetMenu8")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 8
		table.insert(PetMenuCreate, menuVariable)
	end
	-- Si le sacrifice démoniaque existe, on affiche le bouton dans le menu des pets
	if NECROSIS_SPELL_TABLE[44].ID then
		menuVariable = getglobal("NecrosisPetMenu9")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisPetMenu" .. PetButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.PetMenuPos) * 31),
			0
		)
		PetButtonPosition = 9
		table.insert(PetMenuCreate, menuVariable)
	end

	-- Maintenant que tous les boutons de pet sont placés les uns à côté des autres (hors de l'écran), on affiche les disponibles
	for i = 1, table.getn(PetMenuCreate), 1 do
		ShowUIPanel(PetMenuCreate[i])
	end

	-- Si l'Armure Démoniaque existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[31].ID or NECROSIS_SPELL_TABLE[36].ID then
		menuVariable = getglobal("NecrosisBuffMenu1")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint("CENTER", "NecrosisBuffMenuButton", "CENTER", 3000, 3000)
		BuffButtonPosition = 1
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si la respiration interminable existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[32].ID then
		menuVariable = getglobal("NecrosisBuffMenu2")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 2
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si la détection de l'invisibilité existe, on affiche le bouton dans le menu des buffs (au plus haut rang)
	if NECROSIS_SPELL_TABLE[33].ID then
		menuVariable = getglobal("NecrosisBuffMenu3")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 3
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si la respiration interminable existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[34].ID then
		menuVariable = getglobal("NecrosisBuffMenu4")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 4
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si l'invocation de joueur existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[37].ID then
		menuVariable = getglobal("NecrosisBuffMenu5")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 5
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si le Radar à démon existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[39].ID then
		menuVariable = getglobal("NecrosisBuffMenu6")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 6
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si le Lien Spirituel existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[38].ID then
		menuVariable = getglobal("NecrosisBuffMenu7")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 7
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si la protection contre les ombres existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[43].ID then
		menuVariable = getglobal("NecrosisBuffMenu8")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 8
		table.insert(BuffMenuCreate, menuVariable)
	end
	-- Si le banissement existe, on affiche le bouton dans le menu des buffs
	if NECROSIS_SPELL_TABLE[9].ID then
		menuVariable = getglobal("NecrosisBuffMenu9")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint(
			"CENTER",
			"NecrosisBuffMenu" .. BuffButtonPosition,
			"CENTER",
			((36 / NecrosisConfig.BuffMenuPos) * 31),
			0
		)
		BuffButtonPosition = 9
		table.insert(BuffMenuCreate, menuVariable)
	end

	-- Maintenant que tous les boutons de buff sont placés les uns à côté des autres (hors de l'écran), on affiche les disponibles
	for i = 1, table.getn(BuffMenuCreate), 1 do
		ShowUIPanel(BuffMenuCreate[i])
	end

	-- Si la Malédiction amplifiée existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[42].ID then
		menuVariable = getglobal("NecrosisCurseMenu1")
		menuVariable:ClearAllPoints()
		menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		CurseButtonPosition = 1
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction de faiblesse existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[23].ID then
		menuVariable = getglobal("NecrosisCurseMenu2")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 2
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction d'agonie existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[22].ID then
		menuVariable = getglobal("NecrosisCurseMenu3")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 3
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction de témérité existe, on affiche le bouton dans le menu des curses (au plus haut rang)
	if NECROSIS_SPELL_TABLE[24].ID then
		menuVariable = getglobal("NecrosisCurseMenu4")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 4
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction des languages existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[25].ID then
		menuVariable = getglobal("NecrosisCurseMenu5")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 5
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction de fatigue existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[40].ID then
		menuVariable = getglobal("NecrosisCurseMenu6")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 6
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction des éléments existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[26].ID then
		menuVariable = getglobal("NecrosisCurseMenu7")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 7
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction de l'ombre, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[27].ID then
		menuVariable = getglobal("NecrosisCurseMenu8")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 8
		table.insert(CurseMenuCreate, menuVariable)
	end
	-- Si la Malédiction funeste existe, on affiche le bouton dans le menu des curses
	if NECROSIS_SPELL_TABLE[16].ID then
		menuVariable = getglobal("NecrosisCurseMenu9")
		menuVariable:ClearAllPoints()
		if CurseButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisCurseMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisCurseMenu" .. CurseButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.CurseMenuPos) * 31),
				0
			)
		end
		CurseButtonPosition = 9
		table.insert(CurseMenuCreate, menuVariable)
	end

	-- Maintenant que tous les boutons de curse sont placés les uns à côté des autres (hors de l'écran), on affiche les disponibles
	for i = 1, table.getn(CurseMenuCreate), 1 do
		ShowUIPanel(CurseMenuCreate[i])
	end

	-- Stone Menu: Only show stone buttons if player has the corresponding spell
	-- NecrosisStoneMenu1 = Firestone (StoneIDInSpellTable[4])
	if StoneIDInSpellTable[4] ~= 0 then
		menuVariable = getglobal("NecrosisStoneMenu1")
		menuVariable:ClearAllPoints()
		if StoneButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisStoneMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisStoneMenu" .. StoneButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.StoneMenuPos) * 31),
				0
			)
		end
		StoneButtonPosition = 1
		table.insert(StoneMenuCreate, menuVariable)

		if NecrosisConfig.LastStone == "" then
			NecrosisConfig.LastStone = "Firestone"
		end
	end

	-- NecrosisStoneMenu2 = Felstone (StoneIDInSpellTable[5])
	if StoneIDInSpellTable[5] ~= 0 then
		menuVariable = getglobal("NecrosisStoneMenu2")
		menuVariable:ClearAllPoints()
		if StoneButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisStoneMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisStoneMenu" .. StoneButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.StoneMenuPos) * 31),
				0
			)
		end
		StoneButtonPosition = 2
		table.insert(StoneMenuCreate, menuVariable)

		if NecrosisConfig.LastStone == "" then
			NecrosisConfig.LastStone = "Felstone"
		end
	end

	-- NecrosisStoneMenu3 = Wrathstone (StoneIDInSpellTable[6])
	if StoneIDInSpellTable[6] ~= 0 then
		menuVariable = getglobal("NecrosisStoneMenu3")
		menuVariable:ClearAllPoints()
		if StoneButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisStoneMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisStoneMenu" .. StoneButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.StoneMenuPos) * 31),
				0
			)
		end
		StoneButtonPosition = 3
		table.insert(StoneMenuCreate, menuVariable)

		if NecrosisConfig.LastStone == "" then
			NecrosisConfig.LastStone = "Wrathstone"
		end
	end

	-- NecrosisStoneMenu4 = Voidstone (StoneIDInSpellTable[7])
	if StoneIDInSpellTable[7] ~= 0 then
		menuVariable = getglobal("NecrosisStoneMenu4")
		menuVariable:ClearAllPoints()
		if StoneButtonPosition == 0 then
			menuVariable:SetPoint("CENTER", "NecrosisStoneMenuButton", "CENTER", 3000, 3000)
		else
			menuVariable:SetPoint(
				"CENTER",
				"NecrosisStoneMenu" .. StoneButtonPosition,
				"CENTER",
				((36 / NecrosisConfig.StoneMenuPos) * 31),
				0
			)
		end
		StoneButtonPosition = 4
		table.insert(StoneMenuCreate, menuVariable)

		if NecrosisConfig.LastStone == "" then
			NecrosisConfig.LastStone = "Voidstone"
		end
	end

	-- Maintenant que tous les boutons de stone sont placés les uns à côté des autres (hors de l'écran), on affiche les disponibles
	for i = 1, table.getn(StoneMenuCreate), 1 do
		ShowUIPanel(StoneMenuCreate[i])
	end
end

-- Gestion des casts du menu des buffs
function Necrosis_BuffCast(type)
	local TargetEnemy = false
	if UnitCanAttack("player", "target") and type ~= 9 then
		TargetUnit("player")
		TargetEnemy = true
	end
	-- Si le Démoniste possède la peau de démon mais pas l'armure démoniaque
	if not NECROSIS_SPELL_TABLE[type].ID then
		CastSpell(NECROSIS_SPELL_TABLE[36].ID, "spell")
	else
		if (type ~= 44) or (type == 44 and UnitExists("Pet")) then
			CastSpell(NECROSIS_SPELL_TABLE[type].ID, "spell")
		end
	end
	MenuState.LastBuff = type
	if TargetEnemy then
		TargetLastTarget()
	end
	MenuState.AlphaBuffMenu = 1
	MenuState.AlphaBuffVar = GetTime() + 3
end

-- Gestion des casts du menu des curses
function Necrosis_CurseCast(type, click)
	if (UnitIsFriend("player", "target")) and (not UnitCanAttack("player", "target")) then
		AssistUnit("target")
	end
	if (UnitCanAttack("player", "target")) and (UnitName("target") ~= nil) then
		if type == 23 or type == 22 or type == 40 then
			if (click == "RightButton") and (NECROSIS_SPELL_TABLE[42].ID ~= nil) then
				local start3, duration3 = GetSpellCooldown(NECROSIS_SPELL_TABLE[42].ID, "spell")
				if not (start3 > 0 and duration3 > 0) then
					CastSpell(NECROSIS_SPELL_TABLE[42].ID, "spell")
					SpellStopCasting(NECROSIS_SPELL_TABLE[42].Name)
				end
			end
		end
		CastSpell(NECROSIS_SPELL_TABLE[type].ID, "spell")
		MenuState.LastCurse = type
		MenuState.LastCurseClick = click
		if (click == "MiddleButton") and (UnitExists("Pet")) then
			PetAttack()
		end
	end
	MenuState.AlphaCurseMenu = 1
	MenuState.AlphaCurseVar = GetTime() + 3
end

-- Gestion des casts du menu des démons
function Necrosis_PetCast(type, click)
	if type == 8 and InfernalStone == 0 then
		Necrosis_Msg(NECROSIS_MESSAGE.Error.InfernalStoneNotPresent, "USER")
		return
	elseif type == 30 and DemoniacStone == 0 then
		Necrosis_Msg(NECROSIS_MESSAGE.Error.DemoniacStoneNotPresent, "USER")
		return
	elseif type ~= 15 and type ~= 3 and type ~= 8 and type ~= 30 and ShardState.Count == 0 then
		Necrosis_Msg(NECROSIS_MESSAGE.Error.SoulShardNotPresent, "USER")
		return
	end
	if type == 3 or type == 4 or type == 5 or type == 6 then
		MenuState.LastDemon = type
		if (click == "RightButton") and (NECROSIS_SPELL_TABLE[15].ID ~= nil) then
			local start, duration = GetSpellCooldown(NECROSIS_SPELL_TABLE[15].ID, "spell")
			if not (start > 0 and duration > 0) then
				CastSpell(NECROSIS_SPELL_TABLE[15].ID, "spell")
				SpellStopCasting(NECROSIS_SPELL_TABLE[15].Name)
			end
		end
		if NecrosisConfig.DemonSummon and NecrosisConfig.ChatMsg and not NecrosisConfig.SM then
			if NecrosisConfig.PetName[(type - 2)] == " " and NECROSIS_PET_MESSAGE[5] then
				local tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[5]))
				while tempnum == PetMess and table.getn(NECROSIS_PET_MESSAGE[5]) >= 2 do
					tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[5]))
				end
				PetMess = tempnum
				for i = 1, table.getn(NECROSIS_PET_MESSAGE[5][tempnum]) do
					Necrosis_Msg(Necrosis_MsgReplace(NECROSIS_PET_MESSAGE[5][tempnum][i]), "SAY")
				end
			elseif NECROSIS_PET_MESSAGE[(type - 2)] then
				local tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[(type - 2)]))
				while tempnum == PetMess and table.getn(NECROSIS_PET_MESSAGE[(type - 2)]) >= 2 do
					tempnum = random(1, table.getn(NECROSIS_PET_MESSAGE[(type - 2)]))
				end
				PetMess = tempnum
				for i = 1, table.getn(NECROSIS_PET_MESSAGE[(type - 2)][tempnum]) do
					Necrosis_Msg(
						Necrosis_MsgReplace(NECROSIS_PET_MESSAGE[(type - 2)][tempnum][i], nil, type - 2),
						"SAY"
					)
				end
			end
		end
	end
	CastSpell(NECROSIS_SPELL_TABLE[type].ID, "spell")
	MenuState.AlphaPetMenu = 1
	MenuState.AlphaPetVar = GetTime() + 3
end

-- Fonction permettant l'affichage des différentes pages du livre des configurations
function NecrosisGeneralTab_OnClick(id)
	local TabName
	for index = 1, 5, 1 do
		TabName = getglobal("NecrosisGeneralTab" .. index)
		if index == id then
			TabName:SetChecked(1)
		else
			TabName:SetChecked(nil)
		end
	end
	if id == 1 then
		ShowUIPanel(NecrosisShardMenu)
		HideUIPanel(NecrosisMessageMenu)
		HideUIPanel(NecrosisButtonMenu)
		HideUIPanel(NecrosisTimerMenu)
		HideUIPanel(NecrosisGraphOptionMenu)
		NecrosisGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
		NecrosisGeneralPageText:SetText(NECROSIS_CONFIGURATION.Menu1)
	elseif id == 2 then
		HideUIPanel(NecrosisShardMenu)
		ShowUIPanel(NecrosisMessageMenu)
		HideUIPanel(NecrosisButtonMenu)
		HideUIPanel(NecrosisTimerMenu)
		HideUIPanel(NecrosisGraphOptionMenu)
		NecrosisGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
		NecrosisGeneralPageText:SetText(NECROSIS_CONFIGURATION.Menu2)
	elseif id == 3 then
		HideUIPanel(NecrosisShardMenu)
		HideUIPanel(NecrosisMessageMenu)
		ShowUIPanel(NecrosisButtonMenu)
		HideUIPanel(NecrosisTimerMenu)
		HideUIPanel(NecrosisGraphOptionMenu)
		NecrosisGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
		NecrosisGeneralPageText:SetText(NECROSIS_CONFIGURATION.Menu3)
	elseif id == 4 then
		HideUIPanel(NecrosisShardMenu)
		HideUIPanel(NecrosisMessageMenu)
		HideUIPanel(NecrosisButtonMenu)
		ShowUIPanel(NecrosisTimerMenu)
		HideUIPanel(NecrosisGraphOptionMenu)
		NecrosisGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
		NecrosisGeneralPageText:SetText(NECROSIS_CONFIGURATION.Menu4)
	elseif id == 5 then
		HideUIPanel(NecrosisShardMenu)
		HideUIPanel(NecrosisMessageMenu)
		HideUIPanel(NecrosisButtonMenu)
		HideUIPanel(NecrosisTimerMenu)
		ShowUIPanel(NecrosisGraphOptionMenu)
		NecrosisGeneralIcon:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
		NecrosisGeneralPageText:SetText(NECROSIS_CONFIGURATION.Menu5)
	end
end

-- Bon, pour pouvoir utiliser le Timer sur les sorts instants, j'ai été obligé de m'inspirer de Cosmos
-- Comme je ne voulais pas rendre le mod dépendant de Sea, j'ai repris ses fonctions
-- Apparemment, la version Stand-Alone de ShardTracker a fait pareil :) :)
Necrosis_Hook = function(orig, new, type)
	if not type then
		type = "before"
	end
	if not Hx_Hooks then
		Hx_Hooks = {}
	end
	if not Hx_Hooks[orig] then
		Hx_Hooks[orig] = {}
		Hx_Hooks[orig].before = {}
		Hx_Hooks[orig].before.n = 0
		Hx_Hooks[orig].after = {}
		Hx_Hooks[orig].after.n = 0
		Hx_Hooks[orig].hide = {}
		Hx_Hooks[orig].hide.n = 0
		Hx_Hooks[orig].replace = {}
		Hx_Hooks[orig].replace.n = 0
		Hx_Hooks[orig].orig = getglobal(orig)
	else
		for key, value in Hx_Hooks[orig][type] do
			if value == getglobal(new) then
				return
			end
		end
	end
	Necrosis_Push(Hx_Hooks[orig][type], getglobal(new))
	setglobal(orig, function(...)
		Necrosis_HookHandler(orig, arg)
	end)
end

Necrosis_HookHandler = function(name, arg)
	local called = false
	local continue = true
	local retval
	for key, value in Hx_Hooks[name].hide do
		if type(value) == "function" then
			if not value(unpack(arg)) then
				continue = false
			end
			called = true
		end
	end
	if not continue then
		return
	end
	for key, value in Hx_Hooks[name].before do
		if type(value) == "function" then
			value(unpack(arg))
			called = true
		end
	end
	continue = false
	local replacedFunction = false
	for key, value in Hx_Hooks[name].replace do
		if type(value) == "function" then
			replacedFunction = true
			if value(unpack(arg)) then
				continue = true
			end
			called = true
		end
	end
	if continue or not replacedFunction then
		retval = Hx_Hooks[name].orig(unpack(arg))
	end
	for key, value in Hx_Hooks[name].after do
		if type(value) == "function" then
			value(unpack(arg))
			called = true
		end
	end
	if not called then
		setglobal(name, Hx_Hooks[name].orig)
		Hx_Hooks[name] = nil
	end
	return retval
end

function Necrosis_Push(table, val)
	if not table or not table.n then
		return nil
	end
	table.n = table.n + 1
	table[table.n] = val
end

function Necrosis_UseAction(id, number, onSelf)
	Necrosis_MoneyToggle()
	NecrosisTooltip:SetAction(id)
	local tip = tostring(NecrosisTooltipTextLeft1:GetText())
	if tip then
		SpellCast.Name = tip
		SpellCast.TargetName = UnitName("target")
		if not SpellCast.TargetName then
			SpellCast.TargetName = ""
		end
		SpellCast.TargetLevel = UnitLevel("target")
		if not SpellCast.TargetLevel then
			SpellCast.TargetLevel = ""
		end
	end
end

function Necrosis_CastSpell(spellId, spellbookTabNum)
	local Name, Rank = GetSpellName(spellId, spellbookTabNum)
	if Rank ~= nil then
		local _, _, Rank2 = string.find(Rank, "(%d+)")
		SpellCast.Rank = tonumber(Rank2)
	end
	SpellCast.Name = Name

	SpellCast.TargetName = UnitName("target")
	if not SpellCast.TargetName then
		SpellCast.TargetName = ""
	end
	SpellCast.TargetLevel = UnitLevel("target")
	if not SpellCast.TargetLevel then
		SpellCast.TargetLevel = ""
	end
end

function Necrosis_CastSpellByName(Spell)
	local _, _, Name = string.find(Spell, "(.+)%(")
	local _, _, Rank = string.find(Spell, "([%d]+)")

	if Rank ~= nil then
		local _, _, Rank2 = string.find(Rank, "(%d+)")
		SpellCast.Rank = tonumber(Rank2)
	end

	if not Name then
		_, _, Name = string.find(Spell, "(.+)")
	end
	SpellCast.Name = Name

	SpellCast.TargetName = UnitName("target")
	if not SpellCast.TargetName then
		SpellCast.TargetName = ""
	end
	SpellCast.TargetLevel = UnitLevel("target")
	if not SpellCast.TargetLevel then
		SpellCast.TargetLevel = ""
	end
end

function NecrosisTimer(nom, duree)
	local Cible = UnitName("target")
	local Niveau = UnitLevel("target")
	local truc = 6
	if not Cible then
		Cible = ""
		truc = 2
	end
	if not Niveau then
		Niveau = ""
	end

	SpellGroup, SpellTimer, TimerTable =
		NecrosisTimerX(nom, duree, truc, Cible, Niveau, SpellGroup, SpellTimer, TimerTable)
end

function NecrosisSpellCast(name)
	if string.find(name, "coa") then
		SpellCast.Name = NECROSIS_SPELL_TABLE[22].Name
		SpellCast.TargetName = UnitName("target")
		if not SpellCast.TargetName then
			SpellCast.TargetName = ""
		end
		SpellCast.TargetLevel = UnitLevel("target")
		if not SpellCast.TargetLevel then
			SpellCast.TargetLevel = ""
		end
		CastSpell(NECROSIS_SPELL_TABLE[22].ID, "spell")
	end
end
