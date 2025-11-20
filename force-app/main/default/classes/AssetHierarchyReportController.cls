public with sharing class AssetHierarchyReportController {
    
    /**
     * Get hierarchical asset data for custom visualization
     */
    @AuraEnabled(cacheable=true)
    public static List<AssetHierarchyNode> getAssetHierarchy(String siteFilter, String statusFilter) {
        List<AssetHierarchyNode> hierarchyNodes = new List<AssetHierarchyNode>();
        
        // Build dynamic query
        String query = 'SELECT Id, Name, SerialNumber, ParentId, Parent.Name, ' +
                      'Asset_Type__c, Criticality__c, Condition__c, ' +
                      'Purchase_Cost__c, Last_Maintenance_Date__c, ' +
                      'Version__c, Version_Status__c, InstallDate, ' +
                      'Site__c, Site__r.Name, Status, Hierarchy_Level__c ' +
                      'FROM Asset WHERE Status != \'Retired\' AND Status != \'Disposed\'';
        
        if (String.isNotBlank(siteFilter)) {
            query += ' AND Site__c = :siteFilter';
        }
        
        if (String.isNotBlank(statusFilter)) {
            query += ' AND Status = :statusFilter';
        }
        
        query += ' ORDER BY Parent.Name NULLS FIRST, Name ASC';
        
        List<Asset> assets = Database.query(query);
        
        // Build hierarchy map
        Map<Id, List<Asset>> parentToChildrenMap = new Map<Id, List<Asset>>();
        List<Asset> parentAssets = new List<Asset>();
        
        for (Asset asset : assets) {
            if (asset.ParentId == null) {
                parentAssets.add(asset);
            } else {
                if (!parentToChildrenMap.containsKey(asset.ParentId)) {
                    parentToChildrenMap.put(asset.ParentId, new List<Asset>());
                }
                parentToChildrenMap.get(asset.ParentId).add(asset);
            }
        }
        
        // Build hierarchy nodes
        for (Asset parent : parentAssets) {
            AssetHierarchyNode parentNode = new AssetHierarchyNode(parent, 0);
            
            if (parentToChildrenMap.containsKey(parent.Id)) {
                for (Asset child : parentToChildrenMap.get(parent.Id)) {
                    parentNode.children.add(new AssetHierarchyNode(child, 1));
                }
            }
            
            hierarchyNodes.add(parentNode);
        }
        
        return hierarchyNodes;
    }
    
    /**
     * Get hierarchy statistics
     */
    @AuraEnabled(cacheable=true)
    public static HierarchyStats getHierarchyStats() {
        HierarchyStats stats = new HierarchyStats();
        
        // Count parent assets
        stats.totalParents = [SELECT COUNT() FROM Asset 
                             WHERE ParentId = null 
                             AND Status != 'Retired' 
                             AND Status != 'Disposed'];
        
        // Count child assets
        stats.totalChildren = [SELECT COUNT() FROM Asset 
                              WHERE ParentId != null 
                              AND Status != 'Retired' 
                              AND Status != 'Disposed'];
        
        // Calculate average
        if (stats.totalParents > 0) {
            stats.avgChildrenPerParent = Decimal.valueOf(stats.totalChildren) / 
                                        Decimal.valueOf(stats.totalParents);
        }
        
        // Get total value
        AggregateResult[] results = [SELECT SUM(Purchase_Cost__c) totalValue 
                                    FROM Asset 
                                    WHERE Status != 'Retired' 
                                    AND Status != 'Disposed'];
        
        if (results.size() > 0 && results[0].get('totalValue') != null) {
            stats.totalValue = (Decimal)results[0].get('totalValue');
        }
        
        // Count assets requiring attention
        stats.assetsRequiringAttention = [SELECT COUNT() FROM Asset 
                                         WHERE (Condition__c = 'Poor' OR Condition__c = 'Critical')
                                         AND Status != 'Retired' 
                                         AND Status != 'Disposed'];
        
        return stats;
    }
    
    /**
     * Export hierarchy data to CSV format
     */
    @AuraEnabled
    public static String exportHierarchyToCSV() {
        List<Asset> assets = [SELECT Id, Name, SerialNumber, ParentId, Parent.Name,
                             Asset_Type__c, Criticality__c, Condition__c,
                             Purchase_Cost__c, Last_Maintenance_Date__c,
                             Version__c, Version_Status__c, InstallDate,
                             Site__r.Name, Status, Hierarchy_Level__c
                             FROM Asset 
                             WHERE Status != 'Retired' AND Status != 'Disposed'
                             ORDER BY Parent.Name NULLS FIRST, Name ASC];
        
        String csv = 'Asset Name,Serial Number,Parent Asset,Site,Asset Type,Criticality,' +
                    'Condition,Purchase Cost,Last Maintenance,Version,Version Status,' +
                    'Install Date,Hierarchy Level\n';
        
        for (Asset asset : assets) {
            csv += '"' + asset.Name + '",';
            csv += '"' + (asset.SerialNumber != null ? asset.SerialNumber : '') + '",';
            csv += '"' + (asset.Parent?.Name != null ? asset.Parent.Name : '') + '",';
            csv += '"' + (asset.Site__r?.Name != null ? asset.Site__r.Name : '') + '",';
            csv += '"' + (asset.Asset_Type__c != null ? asset.Asset_Type__c : '') + '",';
            csv += '"' + (asset.Criticality__c != null ? asset.Criticality__c : '') + '",';
            csv += '"' + (asset.Condition__c != null ? asset.Condition__c : '') + '",';
            csv += (asset.Purchase_Cost__c != null ? String.valueOf(asset.Purchase_Cost__c) : '') + ',';
            csv += (asset.Last_Maintenance_Date__c != null ? String.valueOf(asset.Last_Maintenance_Date__c) : '') + ',';
            csv += '"' + (asset.Version__c != null ? asset.Version__c : '') + '",';
            csv += '"' + (asset.Version_Status__c != null ? asset.Version_Status__c : '') + '",';
            csv += (asset.InstallDate != null ? String.valueOf(asset.InstallDate) : '') + ',';
            csv += (asset.Hierarchy_Level__c != null ? String.valueOf(asset.Hierarchy_Level__c) : '0') + '\n';
        }
        
        return csv;
    }
    
    // Wrapper classes
    public class AssetHierarchyNode {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String serialNumber;
        @AuraEnabled public String parentName;
        @AuraEnabled public String assetType;
        @AuraEnabled public String criticality;
        @AuraEnabled public String condition;
        @AuraEnabled public Decimal purchaseCost;
        @AuraEnabled public Date lastMaintenanceDate;
        @AuraEnabled public String version;
        @AuraEnabled public String versionStatus;
        @AuraEnabled public Date installDate;
        @AuraEnabled public String siteName;
        @AuraEnabled public Integer level;
        @AuraEnabled public List<AssetHierarchyNode> children;
        
        public AssetHierarchyNode(Asset asset, Integer hierarchyLevel) {
            this.id = asset.Id;
            this.name = asset.Name;
            this.serialNumber = asset.SerialNumber;
            this.parentName = asset.Parent?.Name;
            this.assetType = asset.Asset_Type__c;
            this.criticality = asset.Criticality__c;
            this.condition = asset.Condition__c;
            this.purchaseCost = asset.Purchase_Cost__c;
            this.lastMaintenanceDate = asset.Last_Maintenance_Date__c;
            this.version = asset.Version__c;
            this.versionStatus = asset.Version_Status__c;
            this.installDate = asset.InstallDate;
            this.siteName = asset.Site__r?.Name;
            this.level = hierarchyLevel;
            this.children = new List<AssetHierarchyNode>();
        }
    }
    
    public class HierarchyStats {
        @AuraEnabled public Integer totalParents = 0;
        @AuraEnabled public Integer totalChildren = 0;
        @AuraEnabled public Decimal avgChildrenPerParent = 0;
        @AuraEnabled public Decimal totalValue = 0;
        @AuraEnabled public Integer assetsRequiringAttention = 0;
    }
}
