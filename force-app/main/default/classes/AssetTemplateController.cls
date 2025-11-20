public with sharing class AssetTemplateController {
    
    @AuraEnabled(cacheable=true)
    public static List<AssetTemplate__c> getActiveTemplates() {
        return [
            SELECT Id, Name, Description__c, Asset_Type__c, Manufacturer__c, 
                   Model__c, Default_Status__c, Is_Active__c, Assets_Created_Count__c
            FROM AssetTemplate__c
            WHERE Is_Active__c = true
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static AssetTemplate__c getTemplateById(Id templateId) {
        return [
            SELECT Id, Name, Description__c, Asset_Type__c, Manufacturer__c, 
                   Model__c, Default_Status__c, Is_Active__c, Assets_Created_Count__c
            FROM AssetTemplate__c
            WHERE Id = :templateId
            LIMIT 1
        ];
    }
    
    @AuraEnabled
    public static Id createAssetFromTemplate(Id templateId, String assetName, Id accountId) {
        AssetTemplate__c template = getTemplateById(templateId);
        
        Asset newAsset = new Asset();
        newAsset.Name = assetName;
        newAsset.AccountId = accountId;
        newAsset.Asset_Template__c = templateId;
        newAsset.Created_From_Template__c = true;
        newAsset.Template_Applied_Date__c = System.now();
        
        if (String.isNotBlank(template.Description__c)) {
            newAsset.Description = template.Description__c;
        }
        
        insert newAsset;
        
        updateTemplateCount(templateId);
        
        return newAsset.Id;
    }
    
    private static void updateTemplateCount(Id templateId) {
        AssetTemplate__c template = [
            SELECT Id, Assets_Created_Count__c
            FROM AssetTemplate__c
            WHERE Id = :templateId
            LIMIT 1
        ];
        
        if (template.Assets_Created_Count__c == null) {
            template.Assets_Created_Count__c = 1;
        } else {
            template.Assets_Created_Count__c += 1;
        }
        
        update template;
    }
}