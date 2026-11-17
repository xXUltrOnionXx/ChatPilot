local _, ns = ...

-- Chat abbreviations explained on mouse-over.
-- up = only matched when written in CAPITALS (to avoid normal words).
-- { de, en [, up] }
local G = {
	-- looking for group / trade
	lfg = { "Sucht eine Gruppe", "Looking for group" },
	lfm = { "Sucht weitere Mitspieler", "Looking for more players" },
	lf = { "Sucht (looking for)", "Looking for" },
	wts = { "Will verkaufen (want to sell)", "Want to sell" },
	wtb = { "Will kaufen (want to buy)", "Want to buy" },
	wtt = { "Will tauschen (want to trade)", "Want to trade" },
	pst = { "Schreib mir eine Flüsternachricht (please send tell)", "Please send me a whisper" },
	pug = { "Zufallsgruppe (pick-up group)", "Pick-up group of random players" },
	inv = { "Bitte einladen (invite)", "Invite (to group)" },
	ah = { "Auktionshaus", "Auction House", true },
	cod = { "Nachnahme per Post (cash on delivery)", "Cash on delivery (mail)", true },
	boe = { "Wird beim Anlegen gebunden (handelbar)", "Bind on equip (tradeable)" },
	bop = { "Wird beim Aufheben gebunden (nicht handelbar)", "Bind on pickup (not tradeable)" },
	bis = { "Bestes Item für den Slot (best in slot)", "Best in slot" },
	ilvl = { "Gegenstandsstufe (item level)", "Item level" },
	sr = { "Soft Reserve: Item ist vorab reserviert", "Soft reserve (loot rule)", true },
	hr = { "Hard Reserve: Item ist fest reserviert", "Hard reserve (loot rule)", true },
	ms = { "Hauptspezialisierung (main spec)", "Main spec", true },
	os = { "Zweitspezialisierung (off spec)", "Off spec", true },
	ml = { "Plündermeister (master loot)", "Master looter", true },
	ffa = { "Jeder darf alles plündern (free for all)", "Free for all (loot)" },
	-- group play
	dps = { "Schadensverursacher (damage per second)", "Damage dealer (damage per second)" },
	aoe = { "Flächenschaden (area of effect)", "Area of effect" },
	cc = { "Gegner kontrollieren, z. B. Schafen (crowd control)", "Crowd control (sheep, sap ...)", true },
	mt = { "Haupt-Tank (main tank)", "Main tank", true },
	ot = { "Zweit-Tank (off tank)", "Off tank", true },
	oom = { "Kein Mana mehr (out of mana)", "Out of mana" },
	cd = { "Abklingzeit (cooldown)", "Cooldown" },
	cds = { "Abklingzeiten (cooldowns)", "Cooldowns" },
	inc = { "Gegner kommen (incoming)", "Enemies incoming" },
	rez = { "Wiederbelebung (resurrect)", "Resurrect" },
	ress = { "Wiederbelebung", "Resurrect" },
	afk = { "Nicht an der Tastatur (away from keyboard)", "Away from keyboard" },
	brb = { "Bin gleich zurück (be right back)", "Be right back" },
	rdy = { "Bereit (ready)", "Ready" },
	omw = { "Bin unterwegs (on my way)", "On my way" },
	xp = { "Erfahrungspunkte", "Experience points", true },
	-- social
	ty = { "Danke (thank you)", "Thank you" },
	thx = { "Danke (thanks)", "Thanks" },
	np = { "Kein Problem / gern geschehen", "No problem" },
	gz = { "Glückwunsch (grats)", "Congratulations" },
	grats = { "Glückwunsch", "Congratulations" },
	gg = { "Gut gespielt (good game)", "Good game" },
	wp = { "Gut gespielt (well played)", "Well played" },
	glhf = { "Viel Glück und Spaß (good luck, have fun)", "Good luck, have fun" },
	sry = { "Entschuldigung (sorry)", "Sorry" },
	wb = { "Willkommen zurück (welcome back)", "Welcome back" },
	re = { "Wieder da (return)", "I'm back" },
	idk = { "Weiß ich nicht (I don't know)", "I don't know" },
	imo = { "Meiner Meinung nach (in my opinion)", "In my opinion" },
	ofc = { "Natürlich (of course)", "Of course" },
	lol = { "Lache laut (laughing out loud)", "Laughing out loud" },
	rofl = { "Lache mich kaputt (rolling on floor laughing)", "Rolling on the floor laughing" },
	bb = { "Tschüss (bye bye)", "Bye bye" },
	gn = { "Gute Nacht", "Good night" },
	gn8 = { "Gute Nacht", "Good night" },
	lg = { "Liebe Grüße", "Best wishes (German)" },
	mfg = { "Mit freundlichen Grüßen", "Kind regards (German)" },
	-- places
	sw = { "Sturmwind", "Stormwind", true },
	og = { "Orgrimmar", "Orgrimmar", true },
	uc = { "Unterstadt", "Undercity", true },
	tb = { "Donnerfels", "Thunder Bluff", true },
	xr = { "Wegekreuz (Brachland)", "The Crossroads (Barrens)", true },
	gy = { "Friedhof (oder Kloster-Friedhof)", "Graveyard (or SM Graveyard)", true },
	-- dungeons & raids
	rfc = { "Flammenschlund", "Ragefire Chasm" },
	wc = { "Höhlen des Wehklagens", "Wailing Caverns", true },
	dm = { "Todesminen (oder Düsterbruch)", "Deadmines (or Dire Maul)", true },
	vc = { "Todesminen (Van Cleef)", "Deadmines (VanCleef)", true },
	sfk = { "Burg Schattenfang", "Shadowfang Keep" },
	bfd = { "Tiefschwarze Grotte", "Blackfathom Deeps" },
	stocks = { "Das Verlies (Sturmwind)", "The Stockade", true },
	gnomer = { "Gnomeregan", "Gnomeregan" },
	rfk = { "Kral der Klingenhauer", "Razorfen Kraul" },
	sm = { "Scharlachrotes Kloster", "Scarlet Monastery", true },
	lib = { "Kloster: Bibliothek", "SM: Library", true },
	arms = { "Kloster: Waffenkammer", "SM: Armory", true },
	cath = { "Kloster: Kathedrale", "SM: Cathedral", true },
	rfd = { "Hügel der Klingenhauer", "Razorfen Downs" },
	ulda = { "Uldaman", "Uldaman" },
	zf = { "Zul'Farrak", "Zul'Farrak" },
	mara = { "Maraudon", "Maraudon" },
	st = { "Versunkener Tempel", "Sunken Temple", true },
	brd = { "Schwarzfelstiefen", "Blackrock Depths" },
	lbrs = { "Untere Schwarzfelsspitze", "Lower Blackrock Spire" },
	ubrs = { "Obere Schwarzfelsspitze", "Upper Blackrock Spire" },
	strat = { "Stratholme", "Stratholme" },
	scholo = { "Scholomance", "Scholomance" },
	dme = { "Düsterbruch Ost", "Dire Maul East" },
	dmw = { "Düsterbruch West", "Dire Maul West" },
	dmn = { "Düsterbruch Nord", "Dire Maul North" },
	ony = { "Onyxias Hort", "Onyxia's Lair" },
	mc = { "Geschmolzener Kern", "Molten Core", true },
	bwl = { "Pechschwingenhort", "Blackwing Lair" },
	zg = { "Zul'Gurub", "Zul'Gurub", true },
	aq20 = { "Ruinen von Ahn'Qiraj", "Ruins of Ahn'Qiraj" },
	aq40 = { "Tempel von Ahn'Qiraj", "Temple of Ahn'Qiraj" },
	naxx = { "Naxxramas", "Naxxramas" },
}

local useDE = GetLocale() == "deDE"

-- Returns the explanation for a word, or nil.
function ns.Explain(word)
	local lw = word:lower()
	local e = G[lw]
	if e then
		if e[3] and word ~= word:upper() then return nil end
		return useDE and e[1] or e[2]
	end
	local n = lw:match("^lf(%d+)m$")
	if n then
		return useDE and ("Sucht noch " .. n .. " Mitspieler") or ("Looking for " .. n .. " more players")
	end
end
