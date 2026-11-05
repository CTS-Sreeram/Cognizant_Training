/**
 * @description Tests for TravelPreferenceService and AccountTravelPreferenceTrigger.
 */
@IsTest
private class TravelPreferenceServiceTest {

    private static User runningUser() {
        return new User(Id = UserInfo.getUserId());
    }

    @IsTest
    static void applyDefaultsSetsValuesWithoutTrigger() {
        Account home    = new Account(Name = 'Home Co',   BillingCountry = 'United States');
        Account abroad  = new Account(Name = 'Abroad Co', BillingCountry = 'India');
        Account unknown = new Account(Name = 'Unknown Co');
        Account preset  = new Account(Name = 'Preset Co', BillingCountry = 'United States',
                                      Travel_Preference__c = TravelPreferenceService.PREF_INTERNATIONAL);

        System.runAs(runningUser()) {
            Test.startTest();
            TravelPreferenceService.applyDefaults(new List<Account>{ home, abroad, unknown, preset });
            Test.stopTest();
        }

        Assert.areEqual(TravelPreferenceService.PREF_DOMESTIC, home.Travel_Preference__c,
            'Home-country Account should be Domestic');
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, abroad.Travel_Preference__c,
            'Foreign Account should be International');
        Assert.areEqual(TravelPreferenceService.PREF_NONE, unknown.Travel_Preference__c,
            'Account without country should be No Travel');
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, preset.Travel_Preference__c,
            'Existing value must not be overwritten');
    }

    @IsTest
    static void applyDefaultsIgnoresNullAndEmptyLists() {
        List<Account> empty = new List<Account>();

        System.runAs(runningUser()) {
            Test.startTest();
            TravelPreferenceService.applyDefaults(null);
            TravelPreferenceService.applyDefaults(empty);
            Test.stopTest();
        }

        Assert.areEqual(0, empty.size(), 'Empty list should stay empty');
    }

    @IsTest
    static void insertPopulatesDefaultsByBillingCountry() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Home Co',    BillingCountry = 'United States'),
            new Account(Name = 'Abroad Co',  BillingCountry = 'India'),
            new Account(Name = 'Unknown Co')
        };

        System.runAs(runningUser()) {
            Test.startTest();
            insert accounts;
            Test.stopTest();
        }

        Map<String, String> prefByName = new Map<String, String>();
        for (Account a : [SELECT Name, Travel_Preference__c FROM Account]) {
            prefByName.put(a.Name, a.Travel_Preference__c);
        }
        Assert.areEqual(TravelPreferenceService.PREF_DOMESTIC, prefByName.get('Home Co'),
            'Trigger should set Domestic on insert');
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, prefByName.get('Abroad Co'),
            'Trigger should set International on insert');
        Assert.areEqual(TravelPreferenceService.PREF_NONE, prefByName.get('Unknown Co'),
            'Trigger should set No Travel on insert');
    }

    @IsTest
    static void updateFillsBlankValue() {
        Account acc = new Account(Name = 'Update Co', BillingCountry = 'India');
        insert acc;

        System.runAs(runningUser()) {
            Test.startTest();
            acc.Travel_Preference__c = null;
            update acc;
            Test.stopTest();
        }

        acc = [SELECT Travel_Preference__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, acc.Travel_Preference__c,
            'Trigger should refill a cleared value on update');
    }

    @IsTest
    static void setPreferenceUpdatesRecordsInBulk() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i, BillingCountry = 'United States'));
        }
        insert accounts;
        Set<Id> ids = new Map<Id, Account>(accounts).keySet();

        Integer updated;
        System.runAs(runningUser()) {
            Test.startTest();
            updated = TravelPreferenceService.setPreference(ids, TravelPreferenceService.PREF_NONE);
            Test.stopTest();
        }

        Assert.areEqual(200, updated, 'All 200 Accounts should update');
        for (Account a : [SELECT Travel_Preference__c FROM Account WHERE Id IN :ids]) {
            Assert.areEqual(TravelPreferenceService.PREF_NONE, a.Travel_Preference__c,
                'Each Account should have the new value');
        }
    }

    @IsTest
    static void setPreferenceCountsOnlySuccessfulUpdates() {
        Account kept    = new Account(Name = 'Kept Co');
        Account deleted = new Account(Name = 'Deleted Co');
        insert new List<Account>{ kept, deleted };
        delete deleted; // updating a deleted record fails -> covers the error branch

        Integer updated;
        System.runAs(runningUser()) {
            Test.startTest();
            updated = TravelPreferenceService.setPreference(
                new Set<Id>{ kept.Id, deleted.Id },
                TravelPreferenceService.PREF_DOMESTIC
            );
            Test.stopTest();
        }

        Assert.areEqual(1, updated, 'Only the non-deleted Account should update');
        Assert.areEqual(1, TravelPreferenceService.lastErrors.size(),
            'The failed record should be reported in lastErrors');
        kept = [SELECT Travel_Preference__c FROM Account WHERE Id = :kept.Id];
        Assert.areEqual(TravelPreferenceService.PREF_DOMESTIC, kept.Travel_Preference__c,
            'Kept Account should have the new value');
    }

    @IsTest
    static void setPreferenceReturnsZeroForEmptyIds() {
        Integer updated;
        System.runAs(runningUser()) {
            Test.startTest();
            updated = TravelPreferenceService.setPreference(new Set<Id>(), TravelPreferenceService.PREF_DOMESTIC);
            Test.stopTest();
        }
        Assert.areEqual(0, updated, 'No Ids means nothing is updated');
    }

    @IsTest
    static void setPreferenceRejectsBlankValue() {
        Account acc = new Account(Name = 'Blank Test');
        insert acc;

        Boolean thrown = false;
        System.runAs(runningUser()) {
            Test.startTest();
            try {
                TravelPreferenceService.setPreference(new Set<Id>{ acc.Id }, '  ');
            } catch (IllegalArgumentException e) {
                thrown = e.getMessage().contains('cannot be blank');
            }
            Test.stopTest();
        }
        Assert.isTrue(thrown, 'Blank preference should throw IllegalArgumentException');
    }
}