class_name InterstitialRules
## When a between-levels ("interstitial") ad may show. Never in the first
## levels, never right after a rewarded ad, never twice within a couple of
## minutes, at most every few levels (Rush Hour: every few runs) and a daily
## cap. Settings in data/economy.json ("interstitial").


## `state`: {levels: levels finished since the last one, runs: Rush runs
## since the last one, last_shown: seconds, last_rewarded: seconds,
## today: shown today}. `context`: "level" or "rush". `progress_level`:
## the player's level number across worlds (0-based).
static func due(cfg: Dictionary, state: Dictionary, now: float, context: String, progress_level: int) -> bool:
	if progress_level < int(cfg.from_level):
		return false
	if int(state.get("today", 0)) >= int(cfg.max_per_day):
		return false
	if now - float(state.get("last_shown", -1e9)) < float(cfg.min_gap_s):
		return false
	if now - float(state.get("last_rewarded", -1e9)) < float(cfg.after_rewarded_gap_s):
		return false
	if context == "rush":
		return int(state.get("runs", 0)) >= int(cfg.rush_every_runs)
	return int(state.get("levels", 0)) >= int(cfg.every_levels)
