public with sharing class AssetHierarchyService {
    
    private static final Integer MAX_HIERARCHY_DEPTH = 5;
    
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
                String hierarchyLevelField = NamespaceUtil.getAssetFieldName('Hierarchy_Level__c');
                asset.put(hierarchyLevelField, 0);
            }
            return;
        }
        
        // Get parent hierarchy levels
        String hierarchyLevelField = NamespaceUtil.getAssetFieldName('Hierarchy_Level__c');
        String query = 'SELECT Id, ' + hierarchyLevelField + ' FROM Asset WHERE Id IN :parentIds WITH USER_MODE';
        Map<Id, Asset> parentMap = new Map<Id, Asset>((List<Asset>)Database.query(query));
        
        for (Asset asset : assets) {
            if (asset.ParentId == null) {
                asset.put(hierarchyLevelField, 0);
            } else {
                Asset parent = parentMap.get(asset.ParentId);
                if (parent != null && parent.get(hierarchyLevelField) != null) {
                    Decimal parentLevel = (Decimal)parent.get(hierarchyLevelField);
                    asset.put(hierarchyLevelField, parentLevel + 1);
                } else {
                    asset.put(hierarchyLevelField, 1);
                }
            }
        }
    }
    
    /**
     * Get full hierarchy path for an asset
     * Returns: "Grandparent > Parent > Child"
     * Optimized to use a single query with parent relationships
     */
    public static String getHierarchyPath(Id assetId) {
        if (assetId == null) {
            return '';
        }
        
        // Check SOQL limits
        if (Limits.getQueries() >= Limits.getLimitQueries() - 3) {
            return 'Path unavailable (query limit)';
        }
        
        List<String> pathParts = new List<String>();
        
        try {
            // Query asset with up to 5 levels of parent relationships
            Asset asset = [
                SELECT Id, Name, ParentId,
                       Parent.Name, Parent.ParentId,
                       Parent.Parent.Name, Parent.Parent.ParentId,
                       Parent.Parent.Parent.Name, Parent.Parent.Parent.ParentId,
                       Parent.Parent.Parent.Parent.Name
                FROM Asset 
                WHERE Id = :assetId 
                WITH USER_MODE
                LIMIT 1
            ];
            
            // Build path from top to bottom
            if (asset.Parent != null && asset.Parent.Parent != null && 
                asset.Parent.Parent.Parent != null && asset.Parent.Parent.Parent.Parent != null) {
                pathParts.add(asset.Parent.Parent.Parent.Parent.Name);
            }
            if (asset.Parent != null && asset.Parent.Parent != null && asset.Parent.Parent.Parent != null) {
                pathParts.add(asset.Parent.Parent.Parent.Name);
            }
            if (asset.Parent != null && asset.Parent.Parent != null) {
                pathParts.add(asset.Parent.Parent.Name);
            }
            if (asset.Parent != null) {
                pathParts.add(asset.Parent.Name);
            }
            pathParts.add(asset.Name);
            
            return String.join(pathParts, ' > ');
        } catch (Exception e) {
            System.debug('Error building hierarchy path: ' + e.getMessage());
            return 'Path unavailable';
        }
    }
    
    /**
     * Get all descendants of a parent asset
     * Optimized for Large Data Volumes (LDV) with selective filters
     */
    public static List<Asset> getAllDescendants(Id parentAssetId) {
        // Check if we're approaching SOQL limits
        if (Limits.getQueries() >= Limits.getLimitQueries() - 5) {
            System.debug(LoggingLevel.WARN, 'Approaching SOQL query limit, skipping descendant query');
            return new List<Asset>();
        }
        
        List<Asset> allDescendants = new List<Asset>();
        Set<Id> processedIds = new Set<Id>();
        Set<Id> currentLevelIds = new Set<Id>{parentAssetId};
        
        try {
            // Get RootAssetId field if it exists
            String rootAssetIdField = null;
            try {
                rootAssetIdField = NamespaceUtil.getAssetFieldName('Root_Asset_Id__c');
            } catch (Exception e) {
                // Root_Asset_Id__c field doesn't exist, will use status filter instead
                System.debug('Root_Asset_Id__c field not found, using status filter');
            }
            
            // Query all potential descendants with selective filters
            // This prevents table scans in large orgs
            String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
            String conditionField = NamespaceUtil.getAssetFieldName('Condition__c');
            
            String query = 'SELECT Id, Name, ParentId, SerialNumber, ' + criticalityField + ', ' + conditionField + 
                           ' FROM Asset WHERE ParentId != null';
            
            // Add selective filter based on available fields
            if (rootAssetIdField != null) {
                // If RootAssetId is populated, use it for better selectivity
                query += ' AND ' + rootAssetIdField + ' = :parentAssetId';
            } else {
                // Otherwise, filter by active status to reduce row count
                query += ' AND Status != \'Retired\' AND Status != \'Disposed\'';
            }
            
            query += ' WITH USER_MODE LIMIT 10000';
            
            List<Asset> allAssets = Database.query(query);
            
            // Build parent-to-children map
            Map<Id, List<Asset>> parentToChildren = new Map<Id, List<Asset>>();
            for (Asset a : allAssets) {
                if (!parentToChildren.containsKey(a.ParentId)) {
                    parentToChildren.put(a.ParentId, new List<Asset>());
                }
                parentToChildren.get(a.ParentId).add(a);
            }
            
            // Traverse hierarchy in memory (max 5 levels to prevent infinite loops)
            Integer depth = 0;
            
            while (!currentLevelIds.isEmpty() && depth < MAX_HIERARCHY_DEPTH) {
                Set<Id> nextLevelIds = new Set<Id>();
                
                for (Id currentId : currentLevelIds) {
                    if (parentToChildren.containsKey(currentId)) {
                        for (Asset child : parentToChildren.get(currentId)) {
                            if (!processedIds.contains(child.Id)) {
                                allDescendants.add(child);
                                processedIds.add(child.Id);
                                nextLevelIds.add(child.Id);
                            }
                        }
                    }
                }
                
                currentLevelIds = nextLevelIds;
                depth++;
            }
            
        } catch (QueryException e) {
            // Handle query timeout or other query exceptions gracefully
            System.debug(LoggingLevel.ERROR, 'Query exception in getAllDescendants: ' + e.getMessage());
            // Return partial results if any were collected
            return allDescendants;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in getAllDescendants: ' + e.getMessage());
            return new List<Asset>();
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
        
        String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
        String conditionField = NamespaceUtil.getAssetFieldName('Condition__c');
        
        for (Asset child : descendants) {
            // Criticality
            String crit = child.get(criticalityField) != null ? (String)child.get(criticalityField) : 'Unknown';
            criticalityCount.put(crit, criticalityCount.containsKey(crit) ? 
                               criticalityCount.get(crit) + 1 : 1);
            
            // Condition
            String cond = child.get(conditionField) != null ? (String)child.get(conditionField) : 'Unknown';
            conditionCount.put(cond, conditionCount.containsKey(cond) ? 
                             conditionCount.get(cond) + 1 : 1);
        }
        
        stats.put('criticalityBreakdown', criticalityCount);
        stats.put('conditionBreakdown', conditionCount);
        stats.put('queriesUsed', Limits.getQueries());
        
        return stats;
    }
}
