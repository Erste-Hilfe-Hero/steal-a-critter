-- Start-Reihenfolge aller Services. Server und Smoke-Test laden genau diese Liste, damit ein neuer
-- Service nie nur an einer Stelle eingetragen ist (sonst bricht der Server-Start ab und es gibt keine Arena).
return { "DataService", "ArenaService", "ProgressService", "BallService", "CombatService", "BotService", "MatchService", "MonetizationService", "ExtrasService", "FeaturesService", "PlusService", "DiagService" }
