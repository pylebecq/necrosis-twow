------------------------------------------------------------------------------------------------------
-- Necrosis LdC
--
-- Créateur initial (US) : Infernal (http://www.shadydesign.com/necrosis/files/)
-- Implémentation de base (FR) : Tilienna Thorondor
-- Reprise du projet : Lomig & Nyx des Larmes de Cenarius, Kael'Thas
-- Skins et voix Françaises : Eliah, Ner'zhul
-- Version 01.05.2006-2
------------------------------------------------------------------------------------------------------


-- Les textes d'invocation du démoniste
----------------------------------------
-- Ici sont rassemblés les textes d'invocation pour le démoniste. Vous pouvez les modifier
-- Pour qu'ils collent plus à votre personnage !
-- Pour ceci, voici une aide :
-- Les invocations sont de type "Blah blah blah" Le joueur invoqué "Blah blah blah"
-- Si vous voulez écrire "Je vous invoque 'Nom du joueur' si vous cliquez sur mon portail"
-- Il faut savoir que le nom de la cible est remplacé par <target>
-- alors il faudra rajouter avant } :
-- "Je vous invoque <target> si vous cliquez sur mon portail"
--
-- La même chose est valable pour les messages de pierre d'âme
--
-- En ce qui concerne l'invocation des démons, ça a l'air compliqué mais ça ne l'est pas vraiment
-- Chaque démon est numéroté de 1 à 4
-- A l'intérieur de ces démons chaque discours d'invocation est numérotée de 1 à x
-- A l'intérieur de ces discours d'invocation, des retours à la ligne sur la fenetre de chat est possible
-- J'espère que les commentaires que j'y ai mis sont compréhensibles
-- Sinon n'hésitez pas à poster dans le sujet du forum officiel ou écrivez moi (lomig@larmes-cenarius.net)


-- Texts for a summoning by a warlock
--------------------------------------
-- Here are some summoning speeches for your warlock. You can change them for them to
-- fit your warlock-way-of-thinking a little more !
-- Need some help ? :)
-- Correct syntax is "Blah blah blah" SelectedPlayer "Blah blah blah"
-- If you want to write "In few seconds 'Player's name' will be able to help us"
-- The target's name is replaced by <target>
-- you need to add before the } :
-- "In few seconds <target> will be able to help us",
-- 
-- The same thing is available for soulstone messages
--
-- As for the demon summoning, it seems to be complicated but it is not
-- Each demon is numbered from 1 to 4
-- Inside those demons, each summon speech is numbered from 1 to x
-- Thoses speeches can contain several sentences in the chat window, in game
-- I made notes on the sentences given by example, I hope they are understandable
-- If not, do not hesistate to mail me (lomig@larmes-cenarius.net)


-- Texte für das Ritual der Beschwörung
----------------------------------------
-- Hier sind einige Beschwörungstexte für deinen Hexenmeister. Du kannst sie ändern
-- um deinen Hexenmeisterdenken ein wenig anzupassen!
-- Hier ein paar Tipps. :)
-- Der korrekte Syntax ist "Blah blah blah" ausgewälter Spieler "Blah blah blah"
-- Wenn du schreiben möchtest "In wenigen Sekunden wird 'Spielername' in der Lage sein uns zu helfen"
-- musst du vor dem }; hinzufügen:
-- "In wenigen Sekunden wird <target> in der Lage sein uns zu helfen",
-- 
-- Das gleiche gilt für Seelenstein Nachrichten.
--
-- Das Beschwören von Dämonen: Es sieht zwar kompliziert aus, aber es ist nicht kompliziert
-- Jeder Dämon ist von 1 bis 4 durchnummeriert
-- Innerhalb dieser Dämonen ist jeder Beschwörungsspruch von 1 bis X durchnummeriert
-- Diese Sprüche können einige Sequenzen enthalten, die ingame dann im Chatfenster angezeigt werden
-- Ich habe einige Anmerkungen bei den Beispielsätzen hinzugefügt, ich hoffe sie sind verständlich
-- Sollten sie es nicht sein, zögert nicht mich zu kontaktieren (lomig@larmes-cenarius.net)


-------------------------------------
--  ENGLISH VERSION --
-------------------------------------

function Necrosis_Localization_Speech_En()

	NECROSIS_INVOCATION_MESSAGES = {
		[1] = {
			"Arcanum Taxi Cab ! I am summoning <target>, please click on the portal.",
		},
		[2] = {
			"Welcome aboard, <target>, you are flying on the ~Succubus Air Lines~ to <player>...",
			"Air Hostesses and their lashes are at your service during your trip !",
		},
		[3] = {
			"If you click on the portal, someone named <target> will appear and do your job for you !",
		},
		[4] = {
			"If you do not want a sprawling, phlegm-looking and asthmatic creature to come from this portal, click on it to help <target> find a path in Hell as quick as possible !",
		},
	};

	NECROSIS_SOULSTONE_ALERT_MESSAGE = {
		[1] = {
			"If you cherish the idea of a mass suicide, <target> now can self-resurrect, so all should be fine. Go ahead.",
		},
		[2]= {
			"<target> can go afk to drink a cup of coffee or so, soulstone is in place to allow for the wipe...",
		},
	};

	NECROSIS_PET_MESSAGE = {
		-- Imp
		[1] = {
			-- Summon speech 1
			[1] = {
				"Well, crapy nasty little Imp, now you stop sulking and you come to help ! AND THAT'S AN ORDER !",
			},
			-- Summon speech 2
			[2] = {
				"<pet>! HEEL ! NOW !",
			},
		};
		-- Voidwalker
		[2] = {
			-- Summon speech 1
			[1] = {
				-- First sentence in the chat window
				"Oops, I will probably need an idiot to be knocked for me...",
				-- Second setence in the chat window
				"<pet>, please help !",
			},
		};
		-- Succubus
		[3] = {
			-- Summon speech 1
			[1] = {
				"<pet> baby, please help me sweet heart !",
			},
		};
		-- Felhunter
		[4] = {
			-- Summon speech 1			
			[1] = {
				"<pet> ! <pet> ! Come on boy, come here ! <pet> !",
			},
		};
		-- Sentences for the first summon : When Necrosis do not know the name of your demons yet
		[5] = {
			-- Summon speech 1
			[1] = {
				-- First sentence in the chat window
				"Fishing ? Yes I love fishing... Look !",
				-- Second sentence in the chat window				
				"I close my eyes, I move my fingers like that... And voila ! Yes, yes, it is a fish, I can swear you !",
			},
			-- Summon speech 2			
			[2] = {
				-- First sentence in the chat window				
				"Anyway I hate you all ! I don't need you, I have friends.... Powerful friends !",
				-- Second sentence in the chat window				
				"COME TO ME, CREATURE OF HELL AND NIGHTMARE !",
			},
		};
		-- Sentences for the stead summon
		[6] = {
			-- Summon speech 1	
			[1] = {
				-- First sentence in the chat window
				"Hey, I'm late ! Let's find a horse that roxes !",
			},
			-- Summon speech 2	
			[2] = {
				-- First sentence in the chat window
				"I am summoning a stead from nightmare !",
				-- Second sentence in the chat window
				"AH AHA HA HA AH AH !",
			},
		};
	};
	
	NECROSIS_SHORT_MESSAGES = {
		{{"--> <target> is soulstoned for 30 minutes <--"}},
		{{"<TP> Summoning <target>, please click on the portal <TP>"}},
	};

end

-- Pour les caractères spéciaux :
-- Besondere Zeichen :
-- é = \195\169 ---- è = \195\168
-- à = \195\160 ---- â = \195\162
-- ô = \195\180 ---- ê = \195\170
-- û = \195\187 ---- ä = \195\164
-- Ä = \195\132 ---- ö = \195\182
-- Ö = \195\150 ---- ü = \195\188
-- Ü = \195\156 ---- ß = \195\159
-- ç = \195\167 ---- î = \195\174
