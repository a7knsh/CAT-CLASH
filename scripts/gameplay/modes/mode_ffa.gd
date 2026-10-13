extends BaseMode
## Free-for-All, 2v2 Team Battle, 1v1 Duel and tournament bracket duels:
## round-based, no respawns, last cat (or team) standing wins the round.
## (Duels default to "same start weapon" via ModeDefs so both cats are equal.)


func uses_rounds() -> bool:
	return true
