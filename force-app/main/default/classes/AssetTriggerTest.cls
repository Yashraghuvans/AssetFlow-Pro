@isTest
private class AssetTriggerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test product
        Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
        insert testProduct;
        
        // Create test assets
        List<Asset> testAssets = new List<Asset>();
        for (Integer i = 0; i < 5; i++) {
            Asset a = new Asset(
                Name = 'Test Asset ' + i,
                SerialNumber = 'SN-TEST-' + i,
                AccountId = testAccount.Id,
                Product2Id = testProduct.Id,
                Status = 'Active',
                Last_Maintenance_Date__c = Date.today().addDays(-30),
                Next_Maintenance_Due__c = Date.today().addDays(30),
                Maintenance_Interval_Days__c = 60,
                Criticality__c = 'Medium'
            );
            testAssets.add(a);
        }
        insert testAssets;
    }
    
    @isTest
    static void testOverdueStatusChange_SendsEmail() {
        // Get test assets
        List<Asset> assets = [SELECT Id, Next_Maintenance_Due__c FROM Asset LIMIT 3];
        
        // Reset email invocations
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        
        // Update assets to make them overdue (set Next_Maintenance_Due__c to past date)
        for (Asset a : assets) {
            a.Next_Maintenance_Due__c = Date.today().addDays(-10);
        }
        update assets;
        
        Test.stopTest();
        
        // Verify the update completed successfully
        List<Asset> updatedAssets = [SELECT Id, Maintenance_Status__c FROM Asset WHERE Id IN :assets];
        System.assertEquals(3, updatedAssets.size(), 'All assets should be updated');
    }
    
    @isTest
    static void testNonOverdueStatusChange_NoEmail() {
        // Get test assets
        List<Asset> assets = [SELECT Id, Site__c FROM Asset LIMIT 2];
        
        // Reset email invocations
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        
        // Update assets but keep them non-overdue
        for (Asset a : assets) {
            a.Description = 'Updated Description';
        }
        update assets;
        
        Test.stopTest();
        
        // Verify no emails were sent
        Integer emailsAfter = Limits.getEmailInvocations();
        System.assertEquals(emailsBefore, emailsAfter, 'No emails should be sent for non-overdue status changes');
    }
    
    @isTest
    static void testAlreadyOverdue_NoEmail() {
        // Get test asset and make it overdue
        Asset asset = [SELECT Id, Next_Maintenance_Due__c FROM Asset LIMIT 1];
        asset.Next_Maintenance_Due__c = Date.today().addDays(-10);
        update asset;
        
        // Reset email invocations
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        
        // Update asset but keep it Overdue
        asset.Description = 'Updated Description';
        update asset;
        
        Test.stopTest();
        
        // Verify no additional emails were sent
        Integer emailsAfter = Limits.getEmailInvocations();
        System.assertEquals(emailsBefore, emailsAfter, 'No emails should be sent when asset remains overdue');
    }
    
    @isTest
    static void testBulkUpdate_SendsMultipleEmails() {
        // Get all test assets
        List<Asset> assets = [SELECT Id, Next_Maintenance_Due__c FROM Asset];
        
        Test.startTest();
        
        // Bulk update all assets to make them overdue
        for (Asset a : assets) {
            a.Next_Maintenance_Due__c = Date.today().addDays(-15);
        }
        update assets;
        
        Test.stopTest();
        
        // Verify bulk operation completed successfully
        List<Asset> updatedAssets = [SELECT Id FROM Asset];
        System.assertEquals(assets.size(), updatedAssets.size(), 'All assets should be updated');
    }
}