trigger AssetTemplateTrigger on Asset (after insert, after update, after delete, after undelete) {
    Set<Id> templateIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUndelete) {
        for (Asset asset : Trigger.new) {
            if (asset.Asset_Template__c != null && asset.Created_From_Template__c) {
                templateIds.add(asset.Asset_Template__c);
            }
        }
    }
    
    if (Trigger.isUpdate) {
        for (Asset asset : Trigger.new) {
            Asset oldAsset = Trigger.oldMap.get(asset.Id);
            if (asset.Asset_Template__c != oldAsset.Asset_Template__c || 
                asset.Created_From_Template__c != oldAsset.Created_From_Template__c) {
                if (asset.Asset_Template__c != null) {
                    templateIds.add(asset.Asset_Template__c);
                }
                if (oldAsset.Asset_Template__c != null) {
                    templateIds.add(oldAsset.Asset_Template__c);
                }
            }
        }
    }
    
    if (Trigger.isDelete) {
        for (Asset asset : Trigger.old) {
            if (asset.Asset_Template__c != null && asset.Created_From_Template__c) {
                templateIds.add(asset.Asset_Template__c);
            }
        }
    }
    
    if (!templateIds.isEmpty()) {
        AssetTemplateTriggerHelper.updateAssetCounts(templateIds);
    }
}