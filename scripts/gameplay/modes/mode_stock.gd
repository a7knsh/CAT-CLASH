extends BaseMode
## Stock Battle: every cat has N lives and respawns after a KO until they run
## out. Last cat (or team) with lives remaining wins.


func respawns() -> bool:
	return true


func hud_top() -> String:
	return "STOCK BATTLE · %s" % UI.fmt_time(ctl.match_time)
