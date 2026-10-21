@tool
extends McpTestSuite

# Party frames (scripts/ui/party_frames.gd): one per member, you first, with
# name, health and shield, a role icon and a Rime Shell / Thawing pip. Clicking
# one picks that ally; hovering one sends heals to them. Roles come from the
# abilities on a player's bars (Abilities.role_of_bar).

const Abilities = preload("res://scripts/abilities.gd")
const PartyFramesScript = preload("res://scripts/ui/party_frames.gd")

func suite_name() -> String:
	return "party_frames"

func test_every_spec_has_a_role() -> void:
	for cat in Abilities.SPECS:
		for spec in Abilities.SPECS[cat]:
			assert_true(Abilities.SPEC_ROLES.has(spec[0]), "%s has a role in Abilities.SPEC_ROLES" % spec[0])

func test_role_comes_from_the_bars() -> void:
	assert_eq(Abilities.role_of_bar([]), "dps", "nothing on the bars: damage")
	assert_eq(Abilities.role_of_bar(["dewfall", "fawn", "rootguard", "frostbolt"]), "healer")
	assert_eq(Abilities.role_of_bar(["frostbolt", "blizzard", "dewfall"]), "dps")
	# Utility doesn't count.
	assert_eq(Abilities.role_of_bar(["rimelock", "flashfreeze", "winterhide", "dewfall"]), "healer")
	# A tie goes to the healer, then the tank.
	assert_eq(Abilities.role_of_bar(["dewfall", "frostbolt"]), "healer")

func test_frames_list_you_first_and_cap_at_the_party_size() -> void:
	assert_eq(PartyFramesScript.MAX_FRAMES, 5, "parties are up to 5")
	var src := FileAccess.get_file_as_string("res://scripts/ui/party_frames.gd")
	assert_true(src.find("out.append(player)") < src.find("for id in net.order"), "you come first, then party order")

func test_hovering_a_frame_sends_a_heal_there() -> void:
	var src := PlayerSource.text()
	assert_true(src.contains("frames.member_at(at)"), "_mouseover_begin asks the party frames first")
	assert_true(src.contains("func select_friendly(ally: Node3D)"), "a clicked frame picks that ally")

func test_role_and_shield_reach_the_others() -> void:
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_true(net.contains("_my_role(),"), "my role rides along with my state")
	assert_true(net.contains("p.apply_state(pos, yaw, anim, hp, mhp, role, shield)"))
	var rp := FileAccess.get_file_as_string("res://scripts/net/remote_player.gd")
	assert_true(rp.contains("var role :=") and rp.contains("var shield :="))
