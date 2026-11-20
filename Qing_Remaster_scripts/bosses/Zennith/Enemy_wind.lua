-- Storm V5: Enemy_wind is a compatibility re-export of wind_runtime.
-- All Session / physics / visual ownership lives in threads/wind/wind_runtime.lua.
-- Kept so historical require paths and boss_manager registration remain stable.

return require("Qing_Remaster_scripts.threads.wind.wind_runtime")
