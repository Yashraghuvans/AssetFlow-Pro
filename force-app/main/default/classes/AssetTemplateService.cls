/**
 * Service class for Asset Template operations
 * Handles bulk asset generation from templates and template queries
 */
public with sharing class AssetTemplateService {
    
    // Constants for validation
    private static final Integer MIN_QUANTITY = 1;
    private static final Integer MAX_QUANTITY = 100;
    
    /**
     * Generates multiple Asset records from a template
     * @param templateId - ID of the AssetTemplate__c record
     * @param quantity - Number of assets to create (1-100)
     * @param sitePrefix - Prefix for asset names (e.g., 'SITE-A')
     * @param startNumber - Starting number for sequential naming
     * @return List<Id> - IDs of created Asset records
     * @throws AuraHandledException for validation or DML errors
     */
    @AuraEnabled
    public static List<Id> generateAssetsFromTemplate(
        Id templateId, 
        Integer quantity, 
        String sitePrefix, 
        Integer startNumber
    ) {
        try {
            // Step 1: Validate input parameters
            validateInputs(templateId, quantity, sitePrefix, startNumber);
            
            // Step 2: Query the template with all custom fields
            AssetTemplate__c template = queryTemplate(templateId);
            
            // Step 3: Validate template is active
            if (!template.Is_Active__c) {
                throw new AuraHandledException('Template is not active. Please select an active template.');
            }
            
            // Step 4: Get first account for Asset records (query once outside loop)
            List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
            Id accountId = !accounts.isEmpty() ? accounts[0].Id : null;
            
            // Step 5: Generate assets in bulk
            List<Asset> assetsToInsert = new List<Asset>();
            
            for (Integer i = 0; i < quantity; i++) {
                Asset newAsset = createAssetFromTemplate(template, sitePrefix, startNumber + i, accountId);
                assetsToInsert.add(newAsset);
            }
            
            // Step 6: Bulk insert all assets
            insert assetsToInsert;
            
            // Step 7: Return list of created Asset IDs
            List<Id> assetIds = new List<Id>();
            for (Asset a : assetsToInsert) {
                assetIds.add(a.Id);
            }
            
            return assetIds;
            
        } catch (Exception e) {
            // Handle and throw user-friendly error
            throw new AuraHandledException('Error generating assets: ' + e.getMessage());
        }
    }
    
    /**
     * Retrieves all active Asset Templates for dropdown selection
     * @return List<AssetTemplate__c> - Active templates with key fields
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetTemplate__c> getActiveTemplates() {
        try {
            // Query active templates with essential fields for LWC dropdown
            return [
                SELECT Id, Name, Asset_Type__c, Manufacturer__c, Model__c, Description__c, Is_Active__c
                FROM AssetTemplate__c
                WHERE Is_Active__c = true
                ORDER BY Name ASC
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving templates: ' + e.getMessage());
        }
    }
    
    // ========== PRIVATE HELPER METHODS ==========
    
    /**
     * Validates all input parameters with enhanced validation
     */
    private static void validateInputs(Id templateId, Integer quantity, String sitePrefix, Integer startNumber) {
        if (templateId == null) {
            throw new AuraHandledException('Template ID is required.');
        }
        
        if (quantity == null || quantity < MIN_QUANTITY || quantity > MAX_QUANTITY) {
            throw new AuraHandledException('Quantity must be between ' + MIN_QUANTITY + ' and ' + MAX_QUANTITY + '.');
        }
        
        if (String.isBlank(sitePrefix)) {
            throw new AuraHandledException('Site prefix is required.');
        }
        
        // Validate site prefix format (alphanumeric and hyphens only, max 20 chars)
        Pattern sitePrefixPattern = Pattern.compile('^[A-Za-z0-9-]{1,20}$');
        if (!sitePrefixPattern.matcher(sitePrefix).matches()) {
            throw new AuraHandledException('Site prefix must be alphanumeric with hyphens only (max 20 characters).');
        }
        
        if (startNumber == null || startNumber < 0) {
            throw new AuraHandledException('Start number must be a positive integer.');
        }
        
        if (startNumber > 9999) {
            throw new AuraHandledException('Start number must be less than 10000.');
        }
    }
    
    /**
     * Queries template with all custom fields
     */
    private static AssetTemplate__c queryTemplate(Id templateId) {
        List<AssetTemplate__c> templates = [
            SELECT Id, Name, Description__c, Asset_Type__c, Manufacturer__c, 
                   Model__c, Default_Status__c, Is_Active__c
            FROM AssetTemplate__c
            WHERE Id = :templateId
            LIMIT 1
        ];
        
        if (templates.isEmpty()) {
            throw new AuraHandledException('Template not found with ID: ' + templateId);
        }
        
        return templates[0];
    }
    
    /**
     * Creates a single Asset record from template
     * Naming format: {sitePrefix}-{AssetType}-{sequenceNum}
     * Example: SITE-A-VEHICLE-0001
     */
    private static Asset createAssetFromTemplate(AssetTemplate__c template, String sitePrefix, Integer sequenceNum, Id accountId) {
        Asset newAsset = new Asset();
        
        // Generate asset name with format: SITE-A-VEHICLE-0001
        String assetType = template.Asset_Type__c != null ? template.Asset_Type__c.toUpperCase() : 'ASSET';
        String formattedNumber = String.valueOf(sequenceNum).leftPad(4, '0');
        newAsset.Name = sitePrefix + '-' + assetType + '-' + formattedNumber;
        
        // Copy template fields to asset
        newAsset.Description = template.Description__c;
        
        // Set account if available
        if (accountId != null) {
            newAsset.AccountId = accountId;
        }
        
        // Set custom fields
        newAsset.Asset_Template__c = template.Id;
        newAsset.Created_From_Template__c = true;
        newAsset.Template_Applied_Date__c = System.now();
        
        // Set status from template default
        if (template.Default_Status__c != null) {
            newAsset.Status = template.Default_Status__c;
        }
        
        return newAsset;
    }
}