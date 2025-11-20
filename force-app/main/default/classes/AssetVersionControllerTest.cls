@isTest
private class AssetVersionControllerTest {
    
    @testSetup
    static void setup() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test product
        Product2 testProduct = new Product2(Name = 'Test Router', IsActive = true);
        insert testProduct;
        
        // Create a base "Live" asset
        Asset liveAsset = new Asset(
            Name = 'Router-Main',
            Version__c = 'V1.0',
            Version_Status__c = 'Live',
            Status = 'Active',
            AccountId = testAccount.Id,
            Product2Id = testProduct.Id
        );
        insert liveAsset;
    }
    
    @isTest
    static void testGetAssetDetails() {
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        
        Test.startTest();
        AssetVersionController.AssetInitData initData = 
            AssetVersionController.getAssetDetails(asset.Id);
        Test.stopTest();
        
        System.assertEquals('Router-Main', initData.name);
        System.assertEquals('V1.0', initData.version);
        System.assertEquals('Live', initData.versionStatus);
    }
    
    @isTest
    static void testCreatePlannedVersion() {
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        
        Test.startTest();
        Asset newPlannedAsset = AssetVersionController.createPlannedVersion(
            asset.Id, 
            'V2.0', 
            'Test notes', 
            null, 
            null
        );
        Test.stopTest();
        
        // Verify new asset
        System.assertNotEquals(null, newPlannedAsset);
        System.assertEquals('V2.0', newPlannedAsset.Version__c);
        System.assertEquals('Planned', newPlannedAsset.Version_Status__c);
        System.assert(newPlannedAsset.Name.contains('(Planned)'));
        
        // Verify original asset is unchanged
        Asset original = [SELECT Version_Status__c FROM Asset WHERE Id = :asset.Id];
        System.assertEquals('Live', original.Version_Status__c);
    }
    
    @isTest
    static void testCreatePlannedVersion_InvalidVersion() {
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AssetVersionController.createPlannedVersion(
                asset.Id, 
                'V0.5', 
                'Test notes', 
                null, 
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('must be greater'), 'Expected error message about version');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should have thrown exception');
    }
    
    @isTest
    static void testActivatePlannedVersion() {
        Asset liveAsset = [SELECT Id, Name, AccountId, Product2Id FROM Asset LIMIT 1];
        
        // Create a related "Planned" asset
        Asset plannedAsset = new Asset(
            Name = 'Router-Main - V2.0 (Planned)',
            Version__c = 'V2.0',
            Version_Status__c = 'Planned',
            Status = 'Active',
            AccountId = liveAsset.AccountId,
            Product2Id = liveAsset.Product2Id
        );
        insert plannedAsset;
        
        Test.startTest();
        AssetVersionController.activatePlannedVersion(plannedAsset.Id, liveAsset.Id);
        Test.stopTest();
        
        // Verify planned asset is now live
        Asset newLive = [
            SELECT Name, Version_Status__c, Activated_Date__c 
            FROM Asset 
            WHERE Id = :plannedAsset.Id
        ];
        System.assertEquals('Live', newLive.Version_Status__c);
        System.assert(!newLive.Name.contains('(Planned)'));
        System.assertEquals(Date.today(), newLive.Activated_Date__c);
        
        // Verify old live asset is now superseded
        Asset oldLive = [
            SELECT Name, Version_Status__c, Superseded_By__c, Superseded_Date__c 
            FROM Asset 
            WHERE Id = :liveAsset.Id
        ];
        System.assertEquals('Superseded', oldLive.Version_Status__c);
        System.assertEquals(plannedAsset.Id, oldLive.Superseded_By__c);
        System.assert(oldLive.Name.contains('(Superseded)'));
        System.assertEquals(Date.today(), oldLive.Superseded_Date__c);
    }
    
    @isTest
    static void testSupersedeVersion() {
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        
        Test.startTest();
        AssetVersionController.supersedeVersion(asset.Id);
        Test.stopTest();
        
        Asset superseded = [
            SELECT Version_Status__c, Superseded_Date__c 
            FROM Asset 
            WHERE Id = :asset.Id
        ];
        System.assertEquals('Superseded', superseded.Version_Status__c);
        System.assertEquals(Date.today(), superseded.Superseded_Date__c);
    }
    
    @isTest
    static void testFindRelatedLiveAsset() {
        Asset asset = [SELECT Id, Name FROM Asset LIMIT 1];
        
        Test.startTest();
        Id foundId = AssetVersionController.findRelatedLiveAsset('Router-Main - V2.0 (Planned)');
        Test.stopTest();
        
        System.assertEquals(asset.Id, foundId);
    }
    
    @isTest
    static void testFindRelatedLiveAsset_NotFound() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AssetVersionController.findRelatedLiveAsset('NonExistent Asset');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('No related Live asset found'), 'Expected error message');
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Should have thrown exception');
    }
}