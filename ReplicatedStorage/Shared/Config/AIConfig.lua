local AIConfig = {}

AIConfig.profiles = {
	passiveWild = {
		brainType = "passiveWild",
		thinkInterval = 0.25,
		targetLockSeconds = 0.8,
		leashRadius = 60,
		aggroRadius = 42,
		disengageRadius = 78,
		preferredRange = 14,
		roamRadius = 26,
		movementRefresh = 0.9,
		retainBias = 4,
		ownerThreatBias = 0,
		holdDefenseRange = 0,
	},
	hostileWild = {
		brainType = "hostileWild",
		thinkInterval = 0.2,
		targetLockSeconds = 1.5,
		leashRadius = 86,
		aggroRadius = 66,
		disengageRadius = 112,
		preferredRange = 12,
		roamRadius = 34,
		movementRefresh = 0.7,
		retainBias = 14,
		ownerThreatBias = 0,
		holdDefenseRange = 0,
	},
	petFollower = {
		brainType = "petFollower",
		thinkInterval = 0.18,
		targetLockSeconds = 1.2,
		leashRadius = 90,
		aggroRadius = 68,
		disengageRadius = 110,
		preferredRange = 11,
		roamRadius = 24,
		movementRefresh = 0.55,
		retainBias = 18,
		ownerThreatBias = 28,
		holdDefenseRange = 30,
	},
}

return AIConfig
