/**
 * @description Populates Account.Travel_Preference__c. Call applyDefaults from a
 *              before trigger to default blank values from BillingCountry, or call
 *              setPreference to update existing Accounts to a chosen value.
 *              Adjust the PREF_* constants to match your picklist values.
 */
public with sharing class TravelPreferenceService {

    /** @description Value for Accounts in the home country. */
    public static final String PREF_DOMESTIC = 'Domestic';

    /** @description Value for Accounts outside the home country. */
    public static final String PREF_INTERNATIONAL = 'International';

    /** @description Value for Accounts with no billing country. */
    public static final String PREF_NONE = 'No Travel';

    @TestVisible
    private static final String HOME_COUNTRY = 'United States';

    /**
     * @description Error messages from the most recent setPreference call.
     */
    @TestVisible
    private static List<String> lastErrors = new List<String>();

    /**
     * @description Fills Travel_Preference__c on records where it is blank.
     *              Intended for before insert / before update triggers (no DML).
     * @param accounts Records from Trigger.new
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
     * @description Sets Travel_Preference__c to the given value on the specified
     *              Accounts, enforcing the running user's CRUD/FLS (user mode).
     * @param accountIds Ids of the Accounts to update
     * @param preference Value to set
     * @return Number of records successfully updated
     */
    public static Integer setPreference(Set<Id> accountIds, String preference) {
        lastErrors = new List<String>();
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
        List<Database.SaveResult> results =
            Database.update(toUpdate, false, AccessLevel.USER_MODE);
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                for (Database.Error err : sr.getErrors()) {
                    lastErrors.add(err.getMessage());
                }
            }
        }
        return successCount;
    }

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