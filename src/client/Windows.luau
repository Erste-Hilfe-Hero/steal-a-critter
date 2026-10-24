-- Gemeinsame Fenster-Verwaltung fuer HUD (UI.luau) und Hub (Hub.luau): immer nur ein Fenster offen.
-- Solange ein Fenster offen ist, blenden beide HUDs ihre Seitenknoepfe, Angebote und Infoleisten aus.
local Windows = {}

local closers: { [string]: () -> () } = {}
local listeners: { (boolean) -> () } = {}
local current: string? = nil

local function notify(open: boolean)
	for _, listener in listeners do
		task.spawn(listener, open)
	end
end

-- Jedes HUD meldet, wie man sein Fenster schliesst
function Windows.Register(owner: string, close: () -> ())
	closers[owner] = close
end

-- Vor dem Oeffnen aufrufen: schliesst das Fenster des anderen HUDs
function Windows.Opening(owner: string)
	for name, close in closers do
		if name ~= owner then
			close()
		end
	end
	current = owner
	notify(true)
end

function Windows.Closed(owner: string)
	if current == owner then
		current = nil
		notify(false)
	end
end

function Windows.IsOpen(): boolean
	return current ~= nil
end

function Windows.OnChanged(listener: (boolean) -> ())
	table.insert(listeners, listener)
end

return Windows
