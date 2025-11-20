/**
 * Apex controller for the assetVersionTransition LWC.
 * Handles all logic for creating planned versions, activating live versions,
 * and superseding old versions of Assets.
 */
public with sharing class AssetVersionController {
    
    /**
     * Data Transfer Object (DTO) to hold the initial asset state
     * for the LWC.
     */
    public class AssetInitData {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String version { get; set; }
        @AuraEnabled public String versionStatus { get; set; }
    }
    
    /**
     * Fetches the minimal data needed to initialize the LWC.
     * This replaces "Screen 1".
     */
    @AuraEnabled(cacheable=true)
    public static AssetInitData getAssetDetails(Id assetId) {
        Asset asset = [
            SELECT Name, Version__c, Version_Status__c
            FROM Asset
            WHERE Id = :assetId
            LIMIT 1
        ];
        
        AssetInitData initData = new AssetInitData();
        initData.name = asset.Name;
        initData.version = asset.Version__c;
        initData.versionStatus = asset.Version_Status__c;
        
        return initData;
    }
    
    /**
     * Replaces "Branch 1: Create Planned Version".
     * This clones the asset and sets it up as a "Planned" version.
     */
    @AuraEnabled
    public static Asset createPlannedVersion(
        Id originalAssetId, 
        String newVersion, 
        String versionNotes, 
        Date goLiveDate, 
        Id assignedEngineerId
    ) {
        // Query the original asset
        Asset original = [
            SELECT Id, Name, SerialNumber, Status, Product2Id, AccountId, ContactId, 
                   LocationId, ParentId, InstallDate, Purchase_Cost__c, Current_Value__c, 
                   GL_Account__c, Cost_Center__c, Firmware_Version__c, Software_Version__c,
                   Warranty_Expiration__c, External_Asset_Id__c, IP_Address__c, 
                   MAC_Address__c, Criticality__c, Condition__c, Configuration_Notes__c, 
                   Asset_Category__c, Version__c
            FROM Asset
            WHERE Id = :originalAssetId
            LIMIT 1
        ];
        
        // Validation: New version must be greater
        if (String.isNotBlank(newVersion) && String.isNotBlank(original.Version__c)) {
            if (newVersion <= original.Version__c) {
                throw new AuraHandledException(
                    'New version must be greater than the current version (' + 
                    original.Version__c + ').'
                );
            }
        }
        
        // Clone the asset
        Asset clonedAsset = original.clone(false, true, false, false);
        
        // Set planned version fields
        clonedAsset.Name = original.Name + ' - ' + newVersion + ' (Planned)';
        clonedAsset.Version__c = newVersion;
        clonedAsset.Version_Status__c = 'Planned';
        clonedAsset.Version_Notes__c = versionNotes;
        
        // Clear fields that shouldn't be copied
        clonedAsset.SerialNumber = null;
        clonedAsset.External_Asset_Id__c = null;
        
        insert clonedAsset;
        
        return clonedAsset;
    }
    
    /**
     * Replaces "Branch 2: Activate Planned Version".
     */
    @AuraEnabled
    public static void activatePlannedVersion(Id plannedAssetId, Id relatedLiveAssetId) {
        // Get both assets
        Asset plannedAsset = [
            SELECT Id, Name, Version__c
            FROM Asset
            WHERE Id = :plannedAssetId
            LIMIT 1
        ];
        
        Asset liveAsset = [
            SELECT Id, Name
            FROM Asset
            WHERE Id = :relatedLiveAssetId
            LIMIT 1
        ];
        
        // Update planned asset to Live
        plannedAsset.Version_Status__c = 'Live';
        plannedAsset.Activated_Date__c = Date.today();
        plannedAsset.Name = plannedAsset.Name.replace(' (Planned)', '');
        
        // Update live asset to Superseded
        liveAsset.Version_Status__c = 'Superseded';
        liveAsset.Superseded_Date__c = Date.today();
        liveAsset.Superseded_By__c = plannedAsset.Id;
        liveAsset.Name = liveAsset.Name + ' (Superseded)';
        
        // Update both records in one transaction
        List<Asset> assetsToUpdate = new List<Asset>{plannedAsset, liveAsset};
        update assetsToUpdate;
        
        // Fire Platform Event
        Version_Transitioned__e event = new Version_Transitioned__e(
            New_Version__c = plannedAsset.Id,
            Old_Version__c = liveAsset.Id
        );
        EventBus.publish(event);
    }
    
    /**
     * Replaces "Branch 3: Supersede Without Replacement".
     */
    @AuraEnabled
    public static void supersedeVersion(Id assetId) {
        try {
            // First verify the asset exists and get its current state
            Asset existingAsset = [
                SELECT Id, Name, Version_Status__c
                FROM Asset
                WHERE Id = :assetId
                LIMIT 1
            ];
            
            // Update the asset
            existingAsset.Version_Status__c = 'Superseded';
            existingAsset.Superseded_Date__c = Date.today();
            existingAsset.Name = existingAsset.Name.contains('(Superseded)') ? 
                                 existingAsset.Name : 
                                 existingAsset.Name + ' (Superseded)';
            
            update existingAsset;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error superseding asset: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to find the related Live asset by name pattern
     */
    @AuraEnabled
    public static Id findRelatedLiveAsset(String assetName) {
        // Remove version suffix from name to find base name
        String baseName = assetName.replace(' (Planned)', '').replaceAll(' - V\\d+\\.\\d+', '');
        
        List<Asset> liveAssets = [
            SELECT Id
            FROM Asset
            WHERE Name LIKE :baseName + '%'
            AND Version_Status__c = 'Live'
            LIMIT 1
        ];
        
        if (liveAssets.isEmpty()) {
            throw new AuraHandledException('No related Live asset found for: ' + baseName);
        }
        
        return liveAssets[0].Id;
    }
}