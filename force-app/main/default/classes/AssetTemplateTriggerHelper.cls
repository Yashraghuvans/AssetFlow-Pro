public class AssetTemplateTriggerHelper {
    public static void updateAssetCounts(Set<Id> templateIds) {
        Map<Id, Integer> countMap = new Map<Id, Integer>();
        
        for (AggregateResult ar : [SELECT Asset_Template__c, COUNT(Id) cnt 
                                   FROM Asset 
                                   WHERE Asset_Template__c IN :templateIds 
                                   AND Created_From_Template__c = true 
                                   GROUP BY Asset_Template__c]) {
            countMap.put((Id)ar.get('Asset_Template__c'), (Integer)ar.get('cnt'));
        }
        
        List<AssetTemplate__c> templatesToUpdate = new List<AssetTemplate__c>();
        for (Id templateId : templateIds) {
            AssetTemplate__c template = new AssetTemplate__c(
                Id = templateId,
                Asset_Count__c = countMap.containsKey(templateId) ? countMap.get(templateId) : 0
            );
            templatesToUpdate.add(template);
        }
        
        if (!templatesToUpdate.isEmpty()) {
            update templatesToUpdate;
        }
    }
}