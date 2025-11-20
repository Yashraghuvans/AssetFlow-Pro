/**
 * Controller for Asset Management Dashboard LWC
 * Provides aggregated data for charts and metrics
 */
public with sharing class AssetDashboardController {
    
    /**
     * Get site options for filter
     */
    @AuraEnabled(cacheable=true)
    public static List<SiteOption> getSiteOptions() {
        List<SiteOption> options = new List<SiteOption>();
        
        for (Schema.Location site : [SELECT Id, Name FROM Location ORDER BY Name]) {
            SiteOption opt = new SiteOption();
            opt.id = site.Id;
            opt.name = site.Name;
            options.add(opt);
        }
        
        return options;
    }
    
    /**
     * Get asset counts grouped by status
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByStatus(FilterParams filters) {
        Map<String, Integer> statusMap = new Map<String, Integer>();
        
        String query = 'SELECT Status, COUNT(Id) cnt FROM Asset';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Status';
        
        for (AggregateResult ar : Database.query(query)) {
            String status = (String) ar.get('Status');
            Integer count = (Integer) ar.get('cnt');
            statusMap.put(status != null ? status : 'Unknown', count);
        }
        
        return statusMap;
    }
    
    /**
     * Get asset counts grouped by criticality
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByCriticality(FilterParams filters) {
        Map<String, Integer> criticalityMap = new Map<String, Integer>();
        
        String query = 'SELECT Criticality__c, COUNT(Id) cnt FROM Asset';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Criticality__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String criticality = (String) ar.get('Criticality__c');
            Integer count = (Integer) ar.get('cnt');
            criticalityMap.put(criticality != null ? criticality : 'Not Set', count);
        }
        
        return criticalityMap;
    }
    
    /**
     * Get asset counts grouped by version status
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByVersionStatus(FilterParams filters) {
        Map<String, Integer> versionMap = new Map<String, Integer>();
        
        String query = 'SELECT Version_Status__c, COUNT(Id) cnt FROM Asset';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Version_Status__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String versionStatus = (String) ar.get('Version_Status__c');
            Integer count = (Integer) ar.get('cnt');
            versionMap.put(versionStatus != null ? versionStatus : 'Not Set', count);
        }
        
        return versionMap;
    }
    
    /**
     * Get asset counts grouped by maintenance status
     * Note: Since Maintenance_Status__c is a formula field, we calculate it manually
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByMaintenanceStatus(FilterParams filters) {
        Map<String, Integer> maintenanceMap = new Map<String, Integer>{
            'Current' => 0,
            'Due Soon' => 0,
            'Overdue' => 0,
            'Not Set' => 0
        };
        
        String query = 'SELECT Id, Next_Maintenance_Due__c, Maintenance_Interval_Days__c FROM Asset WHERE Status = \'Active\'';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        
        List<Asset> assets = Database.query(query);
        Date today = Date.today();
        
        for (Asset asset : assets) {
            String status = 'Not Set';
            
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = today.daysBetween(asset.Next_Maintenance_Due__c);
                
                if (daysUntil < 0) {
                    status = 'Overdue';
                } else if (daysUntil <= 7) {
                    status = 'Due Soon';
                } else {
                    status = 'Current';
                }
            }
            
            maintenanceMap.put(status, maintenanceMap.get(status) + 1);
        }
        
        return maintenanceMap;
    }
    
    /**
     * Get total asset value grouped by criticality
     */
    @AuraEnabled
    public static Map<String, Decimal> getAssetValueByCriticality(FilterParams filters) {
        Map<String, Decimal> valueMap = new Map<String, Decimal>();
        
        String query = 'SELECT Criticality__c, SUM(Purchase_Cost__c) totalValue FROM Asset WHERE Purchase_Cost__c != null';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY Criticality__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String criticality = (String) ar.get('Criticality__c');
            Decimal value = (Decimal) ar.get('totalValue');
            valueMap.put(criticality != null ? criticality : 'Not Set', value);
        }
        
        return valueMap;
    }
    
    /**
     * Get key metrics for the dashboard
     */
    @AuraEnabled
    public static DashboardMetrics getDashboardMetrics(FilterParams filters) {
        DashboardMetrics metrics = new DashboardMetrics();
        String whereClause = buildWhereClause(filters);
        String baseWhere = whereClause != '' ? ' WHERE ' + whereClause : '';
        
        // Total assets
        metrics.totalAssets = Database.countQuery('SELECT COUNT() FROM Asset' + baseWhere);
        
        // Active assets
        String activeWhere = whereClause != '' ? ' WHERE Status = \'Active\' AND ' + whereClause : ' WHERE Status = \'Active\'';
        metrics.activeAssets = Database.countQuery('SELECT COUNT() FROM Asset' + activeWhere);
        
        // Overdue maintenance
        String overdueWhere = whereClause != '' 
            ? ' WHERE Next_Maintenance_Due__c < TODAY AND Status = \'Active\' AND ' + whereClause
            : ' WHERE Next_Maintenance_Due__c < TODAY AND Status = \'Active\'';
        metrics.overdueAssets = Database.countQuery('SELECT COUNT() FROM Asset' + overdueWhere);
        
        // Critical assets
        String criticalWhere = whereClause != ''
            ? ' WHERE Criticality__c = \'Critical\' AND Status = \'Active\' AND ' + whereClause
            : ' WHERE Criticality__c = \'Critical\' AND Status = \'Active\'';
        metrics.criticalAssets = Database.countQuery('SELECT COUNT() FROM Asset' + criticalWhere);
        
        // Total asset value
        String valueQuery = 'SELECT SUM(Purchase_Cost__c) total FROM Asset WHERE Purchase_Cost__c != null';
        if (whereClause != '') {
            valueQuery += ' AND ' + whereClause;
        }
        AggregateResult ar = Database.query(valueQuery);
        metrics.totalValue = (Decimal) ar.get('total');
        if (metrics.totalValue == null) {
            metrics.totalValue = 0;
        }
        
        return metrics;
    }
    
    /**
     * Get maintenance status grouped by site (for stacked bar chart)
     */
    @AuraEnabled
    public static Map<String, Map<String, Integer>> getMaintenanceStatusBySite(FilterParams filters) {
        Map<String, Map<String, Integer>> siteMap = new Map<String, Map<String, Integer>>();
        
        String query = 'SELECT Id, Site__r.Name, Next_Maintenance_Due__c FROM Asset WHERE Status = \'Active\' AND Site__c != null';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        
        List<Asset> assets = Database.query(query);
        Date today = Date.today();
        
        for (Asset asset : assets) {
            String siteName = asset.Site__r.Name;
            if (!siteMap.containsKey(siteName)) {
                siteMap.put(siteName, new Map<String, Integer>{
                    'Current' => 0,
                    'Due Soon' => 0,
                    'Overdue' => 0
                });
            }
            
            String status = 'Current';
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = today.daysBetween(asset.Next_Maintenance_Due__c);
                if (daysUntil < 0) {
                    status = 'Overdue';
                } else if (daysUntil <= 7) {
                    status = 'Due Soon';
                }
            }
            
            siteMap.get(siteName).put(status, siteMap.get(siteName).get(status) + 1);
        }
        
        return siteMap;
    }
    
    /**
     * Get asset counts grouped by condition
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByCondition(FilterParams filters) {
        Map<String, Integer> conditionMap = new Map<String, Integer>();
        
        String query = 'SELECT Condition__c, COUNT(Id) cnt FROM Asset WHERE Condition__c != null';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY Condition__c';
        
        for (AggregateResult ar : Database.query(query)) {
            String condition = (String) ar.get('Condition__c');
            Integer count = (Integer) ar.get('cnt');
            conditionMap.put(condition, count);
        }
        
        return conditionMap;
    }
    
    /**
     * Get top 10 most expensive assets
     */
    @AuraEnabled
    public static List<AssetValue> getTop10ExpensiveAssets(FilterParams filters) {
        List<AssetValue> assetValues = new List<AssetValue>();
        
        String query = 'SELECT Id, Name, Purchase_Cost__c FROM Asset WHERE Purchase_Cost__c != null';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' ORDER BY Purchase_Cost__c DESC LIMIT 10';
        
        for (Asset asset : Database.query(query)) {
            AssetValue av = new AssetValue();
            av.id = asset.Id;
            av.name = asset.Name;
            av.value = asset.Purchase_Cost__c;
            assetValues.add(av);
        }
        
        return assetValues;
    }
    
    /**
     * Get assets needing maintenance schedule
     */
    @AuraEnabled
    public static List<MaintenanceAsset> getAssetsNeedingMaintenance(FilterParams filters) {
        List<MaintenanceAsset> maintenanceAssets = new List<MaintenanceAsset>();
        
        String query = 'SELECT Id, Name, Site__r.Name, Next_Maintenance_Due__c, Maintenance_Interval_Days__c FROM Asset WHERE Status = \'Active\' AND (Next_Maintenance_Due__c = null OR Next_Maintenance_Due__c <= NEXT_N_DAYS:30)';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' ORDER BY Next_Maintenance_Due__c ASC NULLS FIRST LIMIT 10';
        
        for (Asset asset : Database.query(query)) {
            MaintenanceAsset ma = new MaintenanceAsset();
            ma.id = asset.Id;
            ma.name = asset.Name;
            ma.site = asset.Site__r != null ? asset.Site__r.Name : '';
            ma.nextMaintenanceDue = asset.Next_Maintenance_Due__c;
            ma.maintenanceInterval = asset.Maintenance_Interval_Days__c;
            
            if (asset.Next_Maintenance_Due__c != null) {
                Integer daysUntil = Date.today().daysBetween(asset.Next_Maintenance_Due__c);
                if (daysUntil < 0) {
                    ma.status = 'Overdue';
                } else if (daysUntil <= 7) {
                    ma.status = 'Due Soon';
                } else {
                    ma.status = 'Upcoming';
                }
            } else {
                ma.status = 'Not Scheduled';
            }
            
            maintenanceAssets.add(ma);
        }
        
        return maintenanceAssets;
    }
    
    /**
     * Get asset value by site (purchase cost vs current value)
     */
    @AuraEnabled
    public static Map<String, SiteValue> getAssetValueBySite(FilterParams filters) {
        Map<String, SiteValue> siteValueMap = new Map<String, SiteValue>();
        
        // First get site IDs and their names
        Map<Id, String> siteIdToName = new Map<Id, String>();
        for (Schema.Location loc : [SELECT Id, Name FROM Location]) {
            siteIdToName.put(loc.Id, loc.Name);
        }
        
        String query = 'SELECT Site__c, SUM(Purchase_Cost__c) purchaseCost, SUM(Current_Value__c) currentValue FROM Asset WHERE Site__c != null AND (Purchase_Cost__c != null OR Current_Value__c != null)';
        String whereClause = buildWhereClause(filters);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY Site__c';
        
        for (AggregateResult ar : Database.query(query)) {
            Id siteId = (Id) ar.get('Site__c');
            String siteName = siteIdToName.get(siteId);
            
            if (siteName != null) {
                SiteValue sv = new SiteValue();
                sv.purchaseCost = (Decimal) ar.get('purchaseCost');
                sv.currentValue = (Decimal) ar.get('currentValue');
                if (sv.purchaseCost == null) sv.purchaseCost = 0;
                if (sv.currentValue == null) sv.currentValue = 0;
                siteValueMap.put(siteName, sv);
            }
        }
        
        return siteValueMap;
    }
    
    /**
     * Wrapper class for dashboard metrics
     */
    public class DashboardMetrics {
        @AuraEnabled public Integer totalAssets { get; set; }
        @AuraEnabled public Integer activeAssets { get; set; }
        @AuraEnabled public Integer overdueAssets { get; set; }
        @AuraEnabled public Integer criticalAssets { get; set; }
        @AuraEnabled public Decimal totalValue { get; set; }
    }
    
    /**
     * Wrapper class for asset value
     */
    public class AssetValue {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal value { get; set; }
    }
    
    /**
     * Wrapper class for maintenance asset
     */
    public class MaintenanceAsset {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String site { get; set; }
        @AuraEnabled public Date nextMaintenanceDue { get; set; }
        @AuraEnabled public Decimal maintenanceInterval { get; set; }
        @AuraEnabled public String status { get; set; }
    }
    
    /**
     * Wrapper class for site value
     */
    public class SiteValue {
        @AuraEnabled public Decimal purchaseCost { get; set; }
        @AuraEnabled public Decimal currentValue { get; set; }
    }
    
    /**
     * Wrapper class for site options
     */
    public class SiteOption {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
    }
    
    /**
     * Wrapper class for filter parameters
     */
    public class FilterParams {
        @AuraEnabled public List<String> siteIds { get; set; }
        @AuraEnabled public List<String> criticalities { get; set; }
        @AuraEnabled public String startDate { get; set; }
        @AuraEnabled public String endDate { get; set; }
    }
    
    /**
     * Build WHERE clause based on filter parameters with proper validation
     */
    private static String buildWhereClause(FilterParams filters) {
        List<String> conditions = new List<String>();
        
        if (filters == null) {
            return '';
        }
        
        // Validate and add site filter
        if (filters.siteIds != null && !filters.siteIds.isEmpty()) {
            List<String> validSiteIds = new List<String>();
            for (String siteId : filters.siteIds) {
                if (String.isNotBlank(siteId) && siteId instanceof Id) {
                    validSiteIds.add('\'' + String.escapeSingleQuotes(siteId) + '\'');
                }
            }
            if (!validSiteIds.isEmpty()) {
                conditions.add('Site__c IN (' + String.join(validSiteIds, ',') + ')');
            }
        }
        
        // Validate and add criticality filter
        if (filters.criticalities != null && !filters.criticalities.isEmpty()) {
            List<String> validCriticalities = new List<String>();
            Set<String> allowedValues = new Set<String>{'Critical', 'High', 'Medium', 'Low'};
            for (String criticality : filters.criticalities) {
                if (String.isNotBlank(criticality) && allowedValues.contains(criticality)) {
                    validCriticalities.add('\'' + String.escapeSingleQuotes(criticality) + '\'');
                }
            }
            if (!validCriticalities.isEmpty()) {
                conditions.add('Criticality__c IN (' + String.join(validCriticalities, ',') + ')');
            }
        }
        
        // Validate and add date filters
        if (String.isNotBlank(filters.startDate)) {
            try {
                Date.valueOf(filters.startDate); // Validate date format
                conditions.add('Installation_Date__c >= ' + filters.startDate);
            } catch (Exception e) {
                System.debug('Invalid start date format: ' + filters.startDate);
            }
        }
        
        if (String.isNotBlank(filters.endDate)) {
            try {
                Date.valueOf(filters.endDate); // Validate date format
                conditions.add('Installation_Date__c <= ' + filters.endDate);
            } catch (Exception e) {
                System.debug('Invalid end date format: ' + filters.endDate);
            }
        }
        
        return String.join(conditions, ' AND ');
    }
}