/**
 * Comprehensive test class for AssetTemplateService
 * Tests all methods and edge cases with 85%+ coverage target
 */
@IsTest
private class AssetTemplateServiceTest {
    
    /**
     * Test data setup - creates active AssetTemplate__c with all fields
     */
    @TestSetup
    static void setupTestData() {
        // Create test account for Asset records
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create active asset template with all fields populated
        AssetTemplate__c activeTemplate = new AssetTemplate__c(
            Description__c = 'Test template for vehicle assets',
            Asset_Type__c = 'Vehicle',
            Manufacturer__c = 'Tesla',
            Model__c = 'Model 3',
            Default_Status__c = 'Active',
            Is_Active__c = true
        );
        insert activeTemplate;
        
        // Create inactive template for testing
        AssetTemplate__c inactiveTemplate = new AssetTemplate__c(
            Description__c = 'Inactive template',
            Asset_Type__c = 'Equipment',
            Manufacturer__c = 'Generic',
            Model__c = 'Test Model',
            Default_Status__c = 'Planned',
            Is_Active__c = false
        );
        insert inactiveTemplate;
    }
    
    /**
     * Test 1: Successful asset generation with valid data
     * Verifies naming convention, relationships, and field values
     */
    @IsTest
    static void testGenerateAssets_Success() {
        // Get active template from test data
        AssetTemplate__c template = [
            SELECT Id, Asset_Type__c 
            FROM AssetTemplate__c 
            WHERE Is_Active__c = true 
            LIMIT 1
        ];
        
        // Test parameters
        Integer quantity = 10;
        String sitePrefix = 'SITE-A';
        Integer startNumber = 1;
        
        Test.startTest();
        
        // Call method to generate assets
        List<Id> assetIds = AssetTemplateService.generateAssetsFromTemplate(
            template.Id,
            quantity,
            sitePrefix,
            startNumber
        );
        
        Test.stopTest();
        
        // Assert correct number of assets created
        System.assertEquals(quantity, assetIds.size(), 'Should create exactly 10 assets');
        
        // Query created assets to verify data
        List<Asset> createdAssets = [
            SELECT Id, Name, Status, Asset_Template__c, 
                   Created_From_Template__c, Template_Applied_Date__c
            FROM Asset
            WHERE Id IN :assetIds
            ORDER BY Name
        ];
        
        System.assertEquals(quantity, createdAssets.size(), 'Should query all created assets');
        
        // Verify first asset naming convention: SITE-A-VEHICLE-0001
        Asset firstAsset = createdAssets[0];
        String expectedFirstName = sitePrefix + '-VEHICLE-0001';
        System.assertEquals(expectedFirstName, firstAsset.Name, 'First asset name should match convention');
        
        // Verify last asset naming convention: SITE-A-VEHICLE-0010
        Asset lastAsset = createdAssets[9];
        String expectedLastName = sitePrefix + '-VEHICLE-0010';
        System.assertEquals(expectedLastName, lastAsset.Name, 'Last asset name should match convention');
        
        // Verify all relationships and fields are set correctly
        for (Asset a : createdAssets) {
            System.assertEquals(template.Id, a.Asset_Template__c, 'Asset_Template__c lookup should be set');
            System.assertEquals(true, a.Created_From_Template__c, 'Created_From_Template__c should be true');
            System.assertNotEquals(null, a.Template_Applied_Date__c, 'Template_Applied_Date__c should be set');
            System.assertEquals('Active', a.Status, 'Status should match template default');
        }
    }
    
    /**
     * Test 2: Attempt to generate assets from inactive template
     * Should throw exception
     */
    @IsTest
    static void testGenerateAssets_InactiveTemplate() {
        // Get inactive template from test data
        AssetTemplate__c inactiveTemplate = [
            SELECT Id 
            FROM AssetTemplate__c 
            WHERE Is_Active__c = false 
            LIMIT 1
        ];
        
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        
        Test.startTest();
        
        try {
            // Attempt to generate assets from inactive template
            AssetTemplateService.generateAssetsFromTemplate(
                inactiveTemplate.Id,
                5,
                'SITE-B',
                1
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        
        Test.stopTest();
        
        // Assert exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for inactive template');
        // Error message is wrapped, so just verify exception was thrown
        System.assertNotEquals('', exceptionMessage, 'Error message should not be empty');
        
        // Verify no assets were created
        List<Asset> assets = [SELECT Id FROM Asset WHERE Asset_Template__c = :inactiveTemplate.Id];
        System.assertEquals(0, assets.size(), 'No assets should be created from inactive template');
    }
    
    /**
     * Test 3: Invalid quantity validation (exceeds max of 100)
     * Should throw exception
     */
    @IsTest
    static void testGenerateAssets_InvalidQuantity() {
        // Get active template
        AssetTemplate__c template = [
            SELECT Id 
            FROM AssetTemplate__c 
            WHERE Is_Active__c = true 
            LIMIT 1
        ];
        
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        
        Test.startTest();
        
        try {
            // Attempt to generate 200 assets (exceeds max of 100)
            AssetTemplateService.generateAssetsFromTemplate(
                template.Id,
                200,
                'SITE-C',
                1
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        
        Test.stopTest();
        
        // Assert exception was thrown
        System.assert(exceptionThrown, 'Exception should be thrown for invalid quantity');
        // Error message is wrapped, so just verify exception was thrown
        System.assertNotEquals('', exceptionMessage, 'Error message should not be empty');
        
        // Verify no assets were created
        List<Asset> assets = [SELECT Id FROM Asset];
        System.assertEquals(0, assets.size(), 'No assets should be created with invalid quantity');
    }
    
    /**
     * Test 4: Bulk operation with maximum quantity (100 assets)
     * Verifies governor limits are not hit
     */
    @IsTest
    static void testGenerateAssets_BulkOperation() {
        // Get active template
        AssetTemplate__c template = [
            SELECT Id 
            FROM AssetTemplate__c 
            WHERE Is_Active__c = true 
            LIMIT 1
        ];
        
        Integer maxQuantity = 100;
        
        Test.startTest();
        
        // Generate maximum allowed assets
        List<Id> assetIds = AssetTemplateService.generateAssetsFromTemplate(
            template.Id,
            maxQuantity,
            'BULK-TEST',
            1
        );
        
        Test.stopTest();
        
        // Assert all 100 assets were created
        System.assertEquals(maxQuantity, assetIds.size(), 'Should create exactly 100 assets');
        
        // Query and verify all assets
        List<Asset> createdAssets = [
            SELECT Id, Name, Asset_Template__c, Created_From_Template__c
            FROM Asset
            WHERE Id IN :assetIds
        ];
        
        System.assertEquals(maxQuantity, createdAssets.size(), 'All 100 assets should be queryable');
        
        // Verify first and last asset names
        List<Asset> orderedAssets = [
            SELECT Name 
            FROM Asset 
            WHERE Id IN :assetIds 
            ORDER BY Name
        ];
        
        System.assertEquals('BULK-TEST-VEHICLE-0001', orderedAssets[0].Name, 'First asset name correct');
        System.assertEquals('BULK-TEST-VEHICLE-0100', orderedAssets[99].Name, 'Last asset name correct');
        
        // Verify all assets have correct relationships
        for (Asset a : createdAssets) {
            System.assertEquals(template.Id, a.Asset_Template__c, 'Template lookup should be set');
            System.assertEquals(true, a.Created_From_Template__c, 'Created from template flag should be true');
        }
        
        // Verify governor limits not exceeded
        System.assert(Limits.getQueries() < Limits.getLimitQueries(), 'SOQL queries within limits');
        System.assert(Limits.getDmlStatements() < Limits.getLimitDmlStatements(), 'DML statements within limits');
    }
    
    /**
     * Test 5: Get active templates method
     * Verifies only active templates are returned and ordering is correct
     */
    @IsTest
    static void testGetActiveTemplates() {
        Test.startTest();
        
        // Call method to get active templates
        List<AssetTemplate__c> activeTemplates = AssetTemplateService.getActiveTemplates();
        
        Test.stopTest();
        
        // Assert only active templates are returned
        System.assertNotEquals(null, activeTemplates, 'Result should not be null');
        System.assertEquals(1, activeTemplates.size(), 'Should return only 1 active template');
        
        // Verify the returned template is active
        AssetTemplate__c returnedTemplate = activeTemplates[0];
        System.assertEquals(true, returnedTemplate.Is_Active__c, 'Returned template should be active');
        
        // Verify essential fields are populated
        System.assertNotEquals(null, returnedTemplate.Id, 'Template ID should be populated');
        System.assertNotEquals(null, returnedTemplate.Name, 'Template Name should be populated');
        System.assertEquals('Vehicle', returnedTemplate.Asset_Type__c, 'Asset Type should be populated');
        System.assertEquals('Tesla', returnedTemplate.Manufacturer__c, 'Manufacturer should be populated');
        System.assertEquals('Model 3', returnedTemplate.Model__c, 'Model should be populated');
    }
    
    /**
     * Test 6: Null template ID validation
     */
    @IsTest
    static void testGenerateAssets_NullTemplateId() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
        
        try {
            AssetTemplateService.generateAssetsFromTemplate(null, 5, 'SITE-D', 1);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for null template ID');
    }
    
    /**
     * Test 7: Empty site prefix validation
     */
    @IsTest
    static void testGenerateAssets_EmptySitePrefix() {
        AssetTemplate__c template = [SELECT Id FROM AssetTemplate__c WHERE Is_Active__c = true LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        
        try {
            AssetTemplateService.generateAssetsFromTemplate(template.Id, 5, '', 1);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for empty site prefix');
    }
    
    /**
     * Test 8: Negative start number validation
     */
    @IsTest
    static void testGenerateAssets_NegativeStartNumber() {
        AssetTemplate__c template = [SELECT Id FROM AssetTemplate__c WHERE Is_Active__c = true LIMIT 1];
        Boolean exceptionThrown = false;
        
        Test.startTest();
        
        try {
            AssetTemplateService.generateAssetsFromTemplate(template.Id, 5, 'SITE-E', -1);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown for negative start number');
    }
}
