-- Baut das komplette HUD per Code: Geldanzeige, Shop, Rebirth, Meldungen.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local FONT = Enum.Font.FredokaOne

local function create(className: string, props, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(thickness: number)
	return create("UIStroke", { Thickness = thickness, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local text = create("TextLabel", props, { create("UIStroke", { Thickness = 2 }) })
	return text
end

local function button(props, color: Color3)
	props.BackgroundColor3 = color
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = Color3.new(1, 1, 1)
	props.AutoButtonColor = true
	return create("TextButton", props, { corner(10), stroke(2), create("UITextSizeConstraint", { MaxTextSize = 28 }) })
end

---------------------------------------------------------------- Meldungen

local toastContainer: Frame
local announceLabel: TextLabel

local function showToast(text: string, color: Color3?)
	local toast = label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		Parent = toastContainer,
	})
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(text: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Color3.new(1, 1, 1)
	announceLabel.Visible = true
	task.delay(5, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Shop

local function sortedEntries(source)
	local list = {}
	for key, entry in source do
		if not entry.Hidden then
			table.insert(list, { Key = key, Entry = entry })
		end
	end
	table.sort(list, function(a, b)
		return (a.Entry.Order or 99) < (b.Entry.Order or 99)
	end)
	return list
end

local function buildShopRow(parent: Instance, kind: string, key: string, entry, color: Color3)
	local row = create("Frame", {
		Size = UDim2.new(1, -10, 0, 70),
		BackgroundColor3 = Color3.fromRGB(40, 40, 55),
		Parent = parent,
	}, { corner(10) })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.65, -12, 0, 30), Text = entry.Name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(0.65, -12, 0, 22),
		Text = entry.Description,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Parent = row,
	})
	local buy = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.3, 0, 0, 46),
		Text = "R$ " .. entry.PriceHint,
		Parent = row,
	}, color)

	-- Pass ohne Gamepass-ID wird als dauerhaftes Developer Product verkauft
	local productId = if kind == "Pass" and entry.Id == 0 then entry.ProductId else nil
	if entry.Id ~= 0 or productId then
		task.spawn(function()
			local infoType = if kind == "Pass" and not productId then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId or entry.Id, infoType)
			if ok and info and info.PriceInRobux then
				buy.Text = "R$ " .. info.PriceInRobux
			end
		end)
	end

	if kind == "Pass" then
		local function refreshOwned()
			if player:GetAttribute("Pass_" .. key) then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
				buy.Active = false
			end
		end
		refreshOwned()
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(refreshOwned)
	end

	buy.Activated:Connect(function()
		if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
			return
		end
		if productId then
			MarketplaceService:PromptProductPurchase(player, productId)
		elseif entry.Id ~= 0 then
			if kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, entry.Id)
			else
				MarketplaceService:PromptProductPurchase(player, entry.Id)
			end
		else
			-- Nur in Studio wirksam (Server prueft das)
			remotes.FakePurchase:FireServer(kind, key)
		end
	end)
end

---------------------------------------------------------------- Start

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Geldanzeige oben
	local top = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(420, 175),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2) }) })
	local cashLabel = label({ Size = UDim2.new(1, 0, 0, 52), Text = "$0", TextColor3 = Color3.fromRGB(120, 255, 120), LayoutOrder = 1, Parent = top })
	local incomeLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "+$0/s", LayoutOrder = 2, Parent = top })
	local statusLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextColor3 = Color3.fromRGB(255, 200, 40), LayoutOrder = 3, Parent = top })
	local rankLabel = label({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Color3.fromRGB(200, 200, 255), LayoutOrder = 5, Parent = top })
	local luckLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextColor3 = Color3.fromRGB(90, 255, 140), LayoutOrder = 4, Visible = false, Parent = top })

	announceLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 190),
		Size = UDim2.new(0.7, 0, 0, 36),
		Visible = false,
		Parent = gui,
	})

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 180),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	-- Seitenbuttons
	local side = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(120, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { Padding = UDim.new(0, 10) }) })
	local shopButton = button({ Size = UDim2.new(1, 0, 0, 60), Text = "SHOP", Parent = side }, Color3.fromRGB(60, 200, 90))
	local rebirthButton = button({ Size = UDim2.new(1, 0, 0, 60), Text = "REBIRTH", Parent = side }, Color3.fromRGB(160, 80, 255))

	-- Shop-Fenster
	local shop = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.7, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(3), create("UISizeConstraint", { MinSize = Vector2.new(340, 300), MaxSize = Vector2.new(620, 700) }) })
	label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 44), Text = "SHOP", TextXAlignment = Enum.TextXAlignment.Left, Parent = shop })
	local closeShop = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44), Text = "X", Parent = shop }, Color3.fromRGB(220, 60, 60))
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -70),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = shop,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	label({ Size = UDim2.new(1, -10, 0, 30), Text = "Game Passes (forever)", TextColor3 = Color3.fromRGB(255, 200, 40), Parent = list })
	for _, item in sortedEntries(Config.GamePasses) do
		buildShopRow(list, "Pass", item.Key, item.Entry, Color3.fromRGB(255, 170, 30))
	end
	label({ Size = UDim2.new(1, -10, 0, 30), Text = "Boosts", TextColor3 = Color3.fromRGB(90, 220, 255), Parent = list })
	for _, item in sortedEntries(Config.DevProducts) do
		buildShopRow(list, "Product", item.Key, item.Entry, Color3.fromRGB(40, 170, 255))
	end

	-- Rebirth-Fenster
	local rebirth = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 260),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(3) })
	label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 44), Text = "REBIRTH", TextXAlignment = Enum.TextXAlignment.Left, Parent = rebirth })
	local closeRebirth = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44), Text = "X", Parent = rebirth }, Color3.fromRGB(220, 60, 60))
	local rebirthInfo = label({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 110), Text = "", Parent = rebirth })
	local confirmRebirth = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0.7, 0, 0, 54), Text = "REBIRTH", Parent = rebirth }, Color3.fromRGB(160, 80, 255))

	shopButton.Activated:Connect(function()
		shop.Visible = not shop.Visible
		rebirth.Visible = false
	end)
	closeShop.Activated:Connect(function()
		shop.Visible = false
	end)
	rebirthButton.Activated:Connect(function()
		rebirth.Visible = not rebirth.Visible
		shop.Visible = false
	end)
	closeRebirth.Activated:Connect(function()
		rebirth.Visible = false
	end)
	confirmRebirth.Activated:Connect(function()
		remotes.RequestRebirth:FireServer()
		rebirth.Visible = false
	end)

	remotes.Notify.OnClientEvent:Connect(showToast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)

	-- Anzeige laufend aktualisieren
	task.spawn(function()
		while gui.Parent do
			local cash = player:GetAttribute("Cash") or 0
			local rebirths = player:GetAttribute("Rebirths") or 0
			local cost = player:GetAttribute("RebirthCost") or 0
			cashLabel.Text = Format.Cash(cash)
			incomeLabel.Text = `+{Format.Cash(player:GetAttribute("IncomePerSec") or 0)}/s   (x{player:GetAttribute("Multiplier") or 1})`

			local carrying = player:GetAttribute("Carrying")
			local lockedFor = player:GetAttribute("LockedFor") or 0
			if carrying then
				statusLabel.Text = `Carrying {carrying} - run to your base!`
			elseif lockedFor > 0 then
				statusLabel.Text = "Base locked " .. Format.Time(lockedFor)
			else
				statusLabel.Text = ""
			end

			local nextRank = player:GetAttribute("NextRank")
			rankLabel.Text = `Rank: {player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  (next {nextRank})` else "") .. "  /rank"
			if player:GetAttribute("RankColor") then
				rankLabel.TextColor3 = Color3.fromHex(player:GetAttribute("RankColor"))
			end

			local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - workspace:GetServerTimeNow()
			luckLabel.Visible = luckLeft > 0
			if luckLeft > 0 then
				luckLabel.Text = `SERVER LUCK x{Config.ServerLuckMultiplier}  {Format.Time(luckLeft)}`
			end

			local current = 1 + rebirths * Config.RebirthMultiplierPer
			rebirthInfo.Text = `Cost: {Format.Cash(cost)}\nRebirth multiplier: x{current} -> x{current + Config.RebirthMultiplierPer}\nResets your cash and critters.`
			confirmRebirth.BackgroundColor3 = if cash >= cost then Color3.fromRGB(160, 80, 255) else Color3.fromRGB(90, 90, 100)
			task.wait(0.2)
		end
	end)
end

return UI
