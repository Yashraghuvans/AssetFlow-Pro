public with sharing class AssetHierarchyService {
    
    /**
     * Calculate hierarchy level for assets
     * Supports multi-level hierarchies (grandchildren, etc.)
     */
    public static void calculateHierarchyLevel(List<Asset> assets) {
        Set<Id> parentIds = new Set<Id>();
        
        for (Asset asset : assets) {
            if (asset.ParentId != null) {
                parentIds.add(asset.ParentId);
            }
        }
        
        if (parentIds.isEmpty()) {
            // All are parent assets
            for (Asset asset : assets) {
                asset.Hierarchy_Level__c = 0;
            }
            return;
        }
        
        // Get parent hierarchy levels
        Map<Id, Asset> parentMap = new Map<Id, Asset>(
            [SELECT Id, Hierarchy_Level__c FROM Asset WHERE Id IN :parentIds]
        );
        
        for (Asset asset : assets) {
            if (asset.ParentId == null) {
                asset.Hierarchy_Level__c = 0;
            } else {
                Asset parent = parentMap.get(asset.ParentId);
                if (parent != null && parent.Hierarchy_Level__c != null) {
                    asset.Hierarchy_Level__c = parent.Hierarchy_Level__c + 1;
                } else {
                    asset.Hierarchy_Level__c = 1;
                }
            }
        }
    }
    
    /**
     * Get full hierarchy path for an asset
     * Returns: "Grandparent > Parent > Child"
     */
    public static String getHierarchyPath(Id assetId) {
        List<String> pathParts = new List<String>();
        Id currentId = assetId;
        Integer maxDepth = 10; // Prevent infinite loops
        Integer depth = 0;
        
        while (currentId != null && depth < maxDepth) {
            List<Asset> assets = [SELECT Id, Name, ParentId 
                                 FROM Asset 
                                 WHERE Id = :currentId 
                                 LIMIT 1];
            
            if (assets.isEmpty()) {
                break;
            }
            
            Asset current = assets[0];
            pathParts.add(0, current.Name); // Add to beginning
            currentId = current.ParentId;
            depth++;
        }
        
        return String.join(pathParts, ' > ');
    }
    
    /**
     * Get all descendants of a parent asset
     */
    public static List<Asset> getAllDescendants(Id parentAssetId) {
        List<Asset> allDescendants = new List<Asset>();
        Set<Id> processedIds = new Set<Id>();
        List<Id> currentLevelIds = new List<Id>{parentAssetId};
        
        Integer maxDepth = 10;
        Integer depth = 0;
        
        while (!currentLevelIds.isEmpty() && depth < maxDepth) {
            List<Asset> children = [SELECT Id, Name, ParentId, SerialNumber,
                                   Asset_Type__c, Criticality__c, Condition__c
                                   FROM Asset 
                                   WHERE ParentId IN :currentLevelIds
                                   AND Id NOT IN :processedIds];
            
            if (children.isEmpty()) {
                break;
            }
            
            allDescendants.addAll(children);
            currentLevelIds.clear();
            
            for (Asset child : children) {
                processedIds.add(child.Id);
                currentLevelIds.add(child.Id);
            }
            
            depth++;
        }
        
        return allDescendants;
    }
    
    /**
     * Validate hierarchy to prevent circular references
     */
    public static Boolean validateHierarchy(Id assetId, Id newParentId) {
        if (newParentId == null) {
            return true; // No parent is always valid
        }
        
        if (assetId == newParentId) {
            return false; // Can't be its own parent
        }
        
        // Check if newParent is a descendant of asset
        List<Asset> descendants = getAllDescendants(assetId);
        for (Asset descendant : descendants) {
            if (descendant.Id == newParentId) {
                return false; // Would create circular reference
            }
        }
        
        return true;
    }
    
    /**
     * Get hierarchy statistics for a parent asset with governor limit protection
     */
    public static Map<String, Object> getParentStatistics(Id parentAssetId) {
        Map<String, Object> stats = new Map<String, Object>();
        
        // Check SOQL query limits before proceeding
        if (Limits.getQueries() >= Limits.getLimitQueries() - 10) {
            stats.put('error', 'Query limit approaching');
            return stats;
        }
        
        List<Asset> descendants = getAllDescendants(parentAssetId);
        
        stats.put('totalChildren', descendants.size());
        
        // Count by criticality
        Map<String, Integer> criticalityCount = new Map<String, Integer>();
        Map<String, Integer> conditionCount = new Map<String, Integer>();
        Decimal totalValue = 0;
        
        for (Asset child : descendants) {
            // Criticality
            String crit = child.Criticality__c != null ? child.Criticality__c : 'Unknown';
            criticalityCount.put(crit, criticalityCount.containsKey(crit) ? 
                               criticalityCount.get(crit) + 1 : 1);
            
            // Condition
            String cond = child.Condition__c != null ? child.Condition__c : 'Unknown';
            conditionCount.put(cond, conditionCount.containsKey(cond) ? 
                             conditionCount.get(cond) + 1 : 1);
        }
        
        stats.put('criticalityBreakdown', criticalityCount);
        stats.put('conditionBreakdown', conditionCount);
        stats.put('queriesUsed', Limits.getQueries());
        
        return stats;
    }
}
