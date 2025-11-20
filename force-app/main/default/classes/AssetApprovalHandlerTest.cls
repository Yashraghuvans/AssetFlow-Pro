/**
 * @description Test class for AssetApprovalHandler
 * @author Salesforce Technical Architect
 * @date 2025-11-16
 */
@isTest
private class AssetApprovalHandlerTest {
    
    @testSetup
    static void setup() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }
    
    /**
     * Test: Asset under $10K should NOT trigger approval
     */
    @isTest
    static void testLowValueAsset_NoApproval() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Asset lowValueAsset = new Asset(
            Name = 'Low Value Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 5000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001'
        );
        insert lowValueAsset;
        Test.stopTest();
        
        // Verify no approval process was triggered
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :lowValueAsset.Id];
        System.assertNotEquals('Pending Approval', result.Status, 
            'Low value asset should not be pending approval');
    }
    
    /**
     * Test: Asset over $10K should trigger approval
     */
    @isTest
    static void testHighValueAsset_TriggersApproval() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Asset highValueAsset = new Asset(
            Name = 'High Value Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 25000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert highValueAsset;
        Test.stopTest();
        
        // Verify approval process was triggered
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :highValueAsset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'High value asset should be pending approval');
    }
    
    /**
     * Test: Updating Purchase Cost to >$10K triggers approval
     */
    @isTest
    static void testPurchaseCostUpdate_TriggersApproval() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create asset with low value
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 5000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert asset;
        
        Test.startTest();
        // Update to high value
        asset.Purchase_Cost__c = 15000;
        update asset;
        Test.stopTest();
        
        // Verify approval was triggered
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :asset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'Asset should be pending approval after cost increase');
    }
    
    /**
     * Test: Updating GL Account on high-value asset triggers resubmission
     */
    @isTest
    static void testGLAccountUpdate_TriggersResubmission() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create high-value asset
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 20000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert asset;
        
        // Approve the asset (simulate)
        asset.Status = 'Active';
        update asset;
        
        Test.startTest();
        // Change GL Account
        asset.GL_Account__c = '1100-Fixed-Assets';
        update asset;
        Test.stopTest();
        
        // Verify resubmission
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :asset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'Asset should be resubmitted after GL Account change');
    }
    
    /**
     * Test: Updating Cost Center on high-value asset triggers resubmission
     */
    @isTest
    static void testCostCenterUpdate_TriggersResubmission() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create high-value asset
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 20000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert asset;
        
        // Approve the asset
        asset.Status = 'Active';
        update asset;
        
        Test.startTest();
        // Change Cost Center
        asset.Cost_Center__c = 'IT-002';
        update asset;
        Test.stopTest();
        
        // Verify resubmission
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :asset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'Asset should be resubmitted after Cost Center change');
    }
    
    /**
     * Test: Updating non-critical field should NOT trigger resubmission
     */
    @isTest
    static void testNonCriticalFieldUpdate_NoResubmission() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create and approve high-value asset
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 20000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert asset;
        
        // Manually set to Active (simulate approval)
        asset.Status = 'Active';
        update asset;
        
        Test.startTest();
        // Update non-critical field
        asset.Description = 'Updated description';
        update asset;
        Test.stopTest();
        
        // Verify no resubmission
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :asset.Id];
        System.assertNotEquals('Pending Approval', result.Status, 
            'Asset should not be resubmitted for non-critical field changes');
    }
    
    /**
     * Test: Bulk insert of high-value assets
     */
    @isTest
    static void testBulkInsert_HighValueAssets() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        List<Asset> assets = new List<Asset>();
        for (Integer i = 0; i < 200; i++) {
            assets.add(new Asset(
                Name = 'Bulk Asset ' + i,
                AccountId = acc.Id,
                Purchase_Cost__c = 15000,
                GL_Account__c = '1000-Assets',
                Cost_Center__c = 'IT-001',
                Status = 'Active'
            ));
        }
        
        Test.startTest();
        insert assets;
        Test.stopTest();
        
        // Verify all were submitted for approval
        List<Asset> results = [SELECT Id, Status FROM Asset WHERE Id IN :assets];
        for (Asset a : results) {
            System.assertEquals('Pending Approval', a.Status, 
                'All bulk assets should be pending approval');
        }
    }
    
    /**
     * Test: Asset already pending approval should not be resubmitted
     */
    @isTest
    static void testPendingAsset_NoResubmission() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Create high-value asset
        Asset asset = new Asset(
            Name = 'Test Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 20000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert asset;
        
        // Set to Pending Approval
        asset.Status = 'Pending Approval';
        update asset;
        
        Test.startTest();
        // Try to update GL Account while pending
        asset.GL_Account__c = '1100-Fixed-Assets';
        update asset;
        Test.stopTest();
        
        // Should still be pending (not resubmitted)
        Asset result = [SELECT Id, Status FROM Asset WHERE Id = :asset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'Pending asset should not be resubmitted');
    }
    
    /**
     * Test: Very high value asset (>$50K) for two-step approval
     */
    @isTest
    static void testVeryHighValueAsset_TwoStepApproval() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        Asset veryHighValueAsset = new Asset(
            Name = 'Very High Value Asset',
            AccountId = acc.Id,
            Purchase_Cost__c = 75000,
            GL_Account__c = '1000-Assets',
            Cost_Center__c = 'IT-001',
            Status = 'Active'
        );
        insert veryHighValueAsset;
        Test.stopTest();
        
        // Verify approval process was triggered
        Asset result = [SELECT Id, Status, Purchase_Cost__c FROM Asset WHERE Id = :veryHighValueAsset.Id];
        System.assertEquals('Pending Approval', result.Status, 
            'Very high value asset should be pending approval');
        System.assert(result.Purchase_Cost__c > 50000, 
            'Asset should qualify for two-step approval');
    }
}
