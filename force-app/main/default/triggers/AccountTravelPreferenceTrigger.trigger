trigger AccountTravelPreferenceTrigger on Account (before insert, before update) {
    TravelPreferenceService.applyDefaults(Trigger.new);
}