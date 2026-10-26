-- Prueft, ob der DataStore "SurfDiag" aus der Luau Execution les- und schreibbar ist
local store = game:GetService("DataStoreService"):GetDataStore("SurfDiag")
local ok, err = pcall(store.SetAsync, store, "probe", os.time())
local out = { "SUMMARY: 0 failed of 1", "set " .. tostring(ok) .. " " .. tostring(err) }
local ok2, value = pcall(store.GetAsync, store, "probe")
table.insert(out, "get " .. tostring(ok2) .. " " .. tostring(value))
local ok3, value3 = pcall(store.GetAsync, store, "u_2979321382")
table.insert(out, "ali " .. tostring(ok3) .. " " .. tostring(value3))
return table.concat(out, "\n")
