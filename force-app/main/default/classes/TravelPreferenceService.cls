/**
 * TravelPreferenceService
 * -----------------------
 * Populates Account.Travel_Preference__c.
 *
 * Two entry points:
 *   1. applyDefaults(List<Account>)  - call from a BEFORE trigger. Fills in a
 *      preference (when blank) based on the Account's billing country.
 *      No DML, so it is safe to call in before insert / before update.
 *   2. setPreference(Set<Id>, String) - updates existing Accounts to a given
 *      value (e.g. from a button, Flow, or batch job). Performs DML.
 *
 * Adjust the values below to match your Travel_Preference__c picklist values.
 */
public with sharing class TravelPreferenceService {

    public static final String PREF_DOMESTIC      = 'Domestic';
    public static final String PREF_INTERNATIONAL = 'International';
    public static final String PREF_NONE          = 'No Travel';

    // Country treated as "home" for the domestic/international rule.
    @TestVisible
    private static final String HOME_COUNTRY = 'United States';

    /**
     * Fills Travel_Preference__c on records where it is blank.
     * Intended for before insert / before update triggers (no DML).
     */
    public static void applyDefaults(List<Account> accounts) {
        if (accounts == null || accounts.isEmpty()) {
            return;
        }
        for (Account acc : accounts) {
            if (String.isBlank(acc.Travel_Preference__c)) {
                acc.Travel_Preference__c = derivePreference(acc);
            }
        }
    }

    /**
     * Sets Travel_Preference__c to the given value on the specified Accounts.
     * Returns the number of records successfully updated.
     */
    public static Integer setPreference(Set<Id> accountIds, String preference) {
        if (accountIds == null || accountIds.isEmpty()) {
            return 0;
        }
        if (String.isBlank(preference)) {
            throw new IllegalArgumentException('Travel preference cannot be blank.');
        }

        List<Account> toUpdate = new List<Account>();
        for (Id accountId : accountIds) {
            toUpdate.add(new Account(Id = accountId, Travel_Preference__c = preference));
        }

        // allOrNone = false: one bad record does not roll back the rest.
        Integer successCount = 0;
        for (Database.SaveResult sr : Database.update(toUpdate, false)) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Failed to set Travel_Preference__c on ' + sr.getId() + ': ' + err.getMessage());
                }
            }
        }
        return successCount;
    }

    /**
     * Business rule for the default value. Replace with your own logic.
     */
    @TestVisible
    private static String derivePreference(Account acc) {
        if (String.isBlank(acc.BillingCountry)) {
            return PREF_NONE;
        }
        return acc.BillingCountry.equalsIgnoreCase(HOME_COUNTRY)
            ? PREF_DOMESTIC
            : PREF_INTERNATIONAL;
    }
}