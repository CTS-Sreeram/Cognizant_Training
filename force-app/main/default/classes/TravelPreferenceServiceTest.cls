@IsTest
private class TravelPreferenceServiceTest {

    @IsTest
    static void insertPopulatesDefaultsByBillingCountry() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Home Co',    BillingCountry = 'United States'),
            new Account(Name = 'Abroad Co',  BillingCountry = 'India'),
            new Account(Name = 'Unknown Co')
        };

        Test.startTest();
        insert accounts;
        Test.stopTest();

        Map<String, String> prefByName = new Map<String, String>();
        for (Account a : [SELECT Name, Travel_Preference__c FROM Account]) {
            prefByName.put(a.Name, a.Travel_Preference__c);
        }
        Assert.areEqual(TravelPreferenceService.PREF_DOMESTIC,      prefByName.get('Home Co'));
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, prefByName.get('Abroad Co'));
        Assert.areEqual(TravelPreferenceService.PREF_NONE,          prefByName.get('Unknown Co'));
    }

    @IsTest
    static void existingValueIsNotOverwritten() {
        Account acc = new Account(
            Name = 'Preset Co',
            BillingCountry = 'United States',
            Travel_Preference__c = TravelPreferenceService.PREF_INTERNATIONAL
        );

        Test.startTest();
        insert acc;
        Test.stopTest();

        acc = [SELECT Travel_Preference__c FROM Account WHERE Id = :acc.Id];
        Assert.areEqual(TravelPreferenceService.PREF_INTERNATIONAL, acc.Travel_Preference__c);
    }

    @IsTest
    static void setPreferenceUpdatesRecords() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i, BillingCountry = 'United States'));
        }
        insert accounts;

        Set<Id> ids = new Map<Id, Account>(accounts).keySet();

        Test.startTest();
        Integer updated = TravelPreferenceService.setPreference(ids, TravelPreferenceService.PREF_NONE);
        Test.stopTest();

        Assert.areEqual(200, updated);
        for (Account a : [SELECT Travel_Preference__c FROM Account WHERE Id IN :ids]) {
            Assert.areEqual(TravelPreferenceService.PREF_NONE, a.Travel_Preference__c);
        }
    }

    @IsTest
    static void setPreferenceHandlesEmptyAndBlankInput() {
        Assert.areEqual(0, TravelPreferenceService.setPreference(new Set<Id>(), 'Domestic'));

        Account acc = new Account(Name = 'Blank Test');
        insert acc;
        try {
            TravelPreferenceService.setPreference(new Set<Id>{ acc.Id }, '  ');
            Assert.fail('Expected IllegalArgumentException for blank preference');
        } catch (IllegalArgumentException e) {
            Assert.isTrue(e.getMessage().contains('cannot be blank'));
        }
    }
}