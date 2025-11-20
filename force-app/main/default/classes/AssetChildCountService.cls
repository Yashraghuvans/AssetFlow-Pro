public with sharing class AssetChildCountService {
    
    /**
     * Update child asset counts for parent assets
     * Called by trigger when assets are created, updated, or deleted
     */
    public static void updateParentChildCounts(Set<Id> parentAssetIds) {
        if (parentAssetIds == null || parentAssetIds.isEmpty()) {
            return;
        }
        
        // Remove null values
        parentAssetIds.remove(null);
        
        if (parentAssetIds.isEmpty()) {
            return;
        }
        
        // Query to count active children for each parent
        Map<Id, Integer> parentToChildCountMap = new Map<Id, Integer>();
        
        // Initialize all parents with 0 count
        for (Id parentId : parentAssetIds) {
            parentToChildCountMap.put(parentId, 0);
        }
        
        // Count active children (exclude Retired and Disposed)
        AggregateResult[] results = [
            SELECT ParentId, COUNT(Id) childCount
            FROM Asset
            WHERE ParentId IN :parentAssetIds
            AND Status != 'Retired'
            AND Status != 'Disposed'
            GROUP BY ParentId
        ];
        
        // Update map with actual counts
        for (AggregateResult ar : results) {
            Id parentId = (Id)ar.get('ParentId');
            Integer count = (Integer)ar.get('childCount');
            parentToChildCountMap.put(parentId, count);
        }
        
        // Update parent assets with new counts
        List<Asset> parentsToUpdate = new List<Asset>();
        for (Id parentId : parentToChildCountMap.keySet()) {
            parentsToUpdate.add(new Asset(
                Id = parentId,
                Child_Assets_Count__c = parentToChildCountMap.get(parentId)
            ));
        }
        
        if (!parentsToUpdate.isEmpty()) {
            update parentsToUpdate;
        }
    }
    
    /**
     * Get parent IDs that need count updates from trigger context
     */
    public static Set<Id> getAffectedParentIds(
        List<Asset> newAssets, 
        List<Asset> oldAssets, 
        Boolean isDelete
    ) {
        Set<Id> parentIds = new Set<Id>();
        
        if (isDelete && oldAssets != null) {
            // For deletes, use old parent IDs
            for (Asset asset : oldAssets) {
                if (asset.ParentId != null) {
                    parentIds.add(asset.ParentId);
                }
            }
        } else if (newAssets != null) {
            // For inserts and updates
            for (Integer i = 0; i < newAssets.size(); i++) {
                Asset newAsset = newAssets[i];
                Asset oldAsset = (oldAssets != null && i < oldAssets.size()) ? oldAssets[i] : null;
                
                // Add new parent ID
                if (newAsset.ParentId != null) {
                    parentIds.add(newAsset.ParentId);
                }
                
                // If parent changed, also update old parent
                if (oldAsset != null && oldAsset.ParentId != null && 
                    oldAsset.ParentId != newAsset.ParentId) {
                    parentIds.add(oldAsset.ParentId);
                }
                
                // If status changed to/from Retired or Disposed, update parent
                if (oldAsset != null && newAsset.ParentId != null &&
                    oldAsset.Status != newAsset.Status &&
                    (oldAsset.Status == 'Retired' || oldAsset.Status == 'Disposed' ||
                     newAsset.Status == 'Retired' || newAsset.Status == 'Disposed')) {
                    parentIds.add(newAsset.ParentId);
                }
            }
        }
        
        return parentIds;
    }
    
    /**
     * Recalculate all parent asset counts (for data fix/migration)
     */
    public static void recalculateAllCounts() {
        // Get all assets that are parents (have children)
        Set<Id> parentIds = new Set<Id>();
        for (Asset asset : [SELECT ParentId FROM Asset WHERE ParentId != null]) {
            parentIds.add(asset.ParentId);
        }
        
        if (!parentIds.isEmpty()) {
            updateParentChildCounts(parentIds);
        }
        
        // Reset count to 0 for assets with no children
        List<Asset> assetsWithNoChildren = [
            SELECT Id 
            FROM Asset 
            WHERE Id NOT IN :parentIds 
            AND Child_Assets_Count__c > 0
        ];
        
        if (!assetsWithNoChildren.isEmpty()) {
            for (Asset asset : assetsWithNoChildren) {
                asset.Child_Assets_Count__c = 0;
            }
            update assetsWithNoChildren;
        }
    }
}
