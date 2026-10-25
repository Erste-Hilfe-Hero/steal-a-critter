-- Liest die Client-Protokolle aus dem DataStore "SurfDiag" (alle Spieler der letzten Zeit)
local store = game:GetService("DataStoreService"):GetDataStore("SurfDiag")
local out = { "SUMMARY: 0 failed of 0" }
local pages = store:ListKeysAsync()
while true do
	for _, key in pages:GetCurrentPage() do
		local ok, value = pcall(store.GetAsync, store, key.KeyName)
		table.insert(out, "== " .. key.KeyName)
		table.insert(out, if ok then tostring(value) else "read error " .. tostring(value))
	end
	if pages.IsFinished then
		break
	end
	pages:AdvanceToNextPageAsync()
end
return table.concat(out, "\n")
