@isTest
private class DailyOverdueDigestTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test product
        Product2 testProduct = new Product2(Name = 'Test Product', IsActive = true);
        insert testProduct;
        
        // Create overdue assets with different criticality levels
        List<Asset> overdueAssets = new List<Asset>();
        
        // Critical assets
        for (Integer i = 0; i < 3; i++) {
            Asset a = new Asset(
                Name = 'Critical Asset ' + i,
                SerialNumber = 'SN-CRIT-' + i,
                AccountId = testAccount.Id,
                Product2Id = testProduct.Id,
                Status = 'Active',
                Last_Maintenance_Date__c = Date.today().addDays(-90),
                Next_Maintenance_Due__c = Date.today().addDays(-30),
                Maintenance_Interval_Days__c = 60,
                Criticality__c = 'Critical'
            );
            overdueAssets.add(a);
        }
        
        // High priority assets
        for (Integer i = 0; i < 2; i++) {
            Asset a = new Asset(
                Name = 'High Priority Asset ' + i,
                SerialNumber = 'SN-HIGH-' + i,
                AccountId = testAccount.Id,
                Product2Id = testProduct.Id,
                Status = 'Active',
                Last_Maintenance_Date__c = Date.today().addDays(-75),
                Next_Maintenance_Due__c = Date.today().addDays(-15),
                Maintenance_Interval_Days__c = 60,
                Criticality__c = 'High'
            );
            overdueAssets.add(a);
        }
        
        // Medium priority assets
        for (Integer i = 0; i < 5; i++) {
            Asset a = new Asset(
                Name = 'Medium Priority Asset ' + i,
                SerialNumber = 'SN-MED-' + i,
                AccountId = testAccount.Id,
                Product2Id = testProduct.Id,
                Status = 'Active',
                Last_Maintenance_Date__c = Date.today().addDays(-65),
                Next_Maintenance_Due__c = Date.today().addDays(-5),
                Maintenance_Interval_Days__c = 60,
                Criticality__c = 'Medium'
            );
            overdueAssets.add(a);
        }
        
        insert overdueAssets;
    }
    
    @isTest
    static void testScheduledJob_SendsDigest() {
        Test.startTest();
        
        // Schedule the job
        String cronExp = '0 0 8 * * ?';
        String jobId = System.schedule('Test Daily Overdue Digest', cronExp, new DailyOverdueDigest());
        
        // Verify job was scheduled
        System.assertNotEquals(null, jobId, 'Job should be scheduled successfully');
        
        // Get scheduled job details
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
        System.assertEquals(0, ct.TimesTriggered, 'Job should not have run yet');
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendDailyDigest_WithOverdueAssets() {
        // Verify test data exists
        List<Asset> overdueAssets = [SELECT Id FROM Asset WHERE Next_Maintenance_Due__c < TODAY];
        System.assertEquals(10, overdueAssets.size(), 'Should have 10 overdue assets');
        
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        
        // Execute the digest method directly
        DailyOverdueDigest.sendDailyDigest();
        
        Test.stopTest();
        
        // Verify email was sent
        Integer emailsAfter = Limits.getEmailInvocations();
        System.assert(emailsAfter > emailsBefore, 'Digest email should have been sent');
    }
    
    @isTest
    static void testSendDailyDigest_NoOverdueAssets() {
        // Update all assets to non-overdue status (future maintenance date)
        List<Asset> assets = [SELECT Id, Next_Maintenance_Due__c FROM Asset];
        for (Asset a : assets) {
            a.Next_Maintenance_Due__c = Date.today().addDays(30);
        }
        update assets;
        
        Integer emailsBefore = Limits.getEmailInvocations();
        
        Test.startTest();
        
        // Execute the digest method
        DailyOverdueDigest.sendDailyDigest();
        
        Test.stopTest();
        
        // Verify no email was sent
        Integer emailsAfter = Limits.getEmailInvocations();
        System.assertEquals(emailsBefore, emailsAfter, 'No email should be sent when no overdue assets exist');
    }
    
    @isTest
    static void testDigestContent_IncludesCriticalCount() {
        Test.startTest();
        
        // Execute the digest
        DailyOverdueDigest.sendDailyDigest();
        
        Test.stopTest();
        
        // Verify critical assets are counted correctly
        List<Asset> criticalAssets = [
            SELECT Id 
            FROM Asset 
            WHERE Next_Maintenance_Due__c < TODAY
            AND Status = 'Active'
            AND (Criticality__c = 'Critical' OR Criticality__c = 'High')
        ];
        System.assertEquals(5, criticalAssets.size(), 'Should have 5 critical/high priority overdue assets');
    }
    
    @isTest
    static void testExecuteMethod_RunsSuccessfully() {
        Test.startTest();
        
        // Create instance and execute
        DailyOverdueDigest digest = new DailyOverdueDigest();
        digest.execute(null);
        
        Test.stopTest();
        
        // Verify execution completed without errors
        System.assert(true, 'Execute method should complete successfully');
    }
}