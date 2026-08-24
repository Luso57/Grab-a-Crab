export type EventPhase = "countdown" | "running"
export type StopReason = "completed" | "expired" | "shutdown" | "failed"

export type EventState = {
	phase: EventPhase,
	eventId: string?,
	displayName: string?,
	startsAt: number?,
	endsAt: number?,
	notificationText: string?,
	soundId: string?,
	soundVolume: number?,
}

export type EventContext = {
	random: Random,
	complete: () -> (),
}

export type EventSession = {
	stop: (self: EventSession, reason: StopReason) -> (),
}

return {}
