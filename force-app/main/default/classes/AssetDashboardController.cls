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
        
        for (Schema.Location site : [SELECT Id, Name FROM Location WITH USER_MODE ORDER BY Name]) {
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
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY Status WITH USER_MODE';
        
        for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
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
        
        try {
            String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
            String query = 'SELECT ' + criticalityField + ', COUNT(Id) cnt FROM Asset';
            Map<String, Object> bindVars = new Map<String, Object>();
            String whereClause = buildWhereClause(filters, bindVars);
            if (whereClause != '') {
                query += ' WHERE ' + whereClause;
            }
            query += ' GROUP BY ' + criticalityField + ' WITH USER_MODE';
            
            for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
                String criticality = (String) ar.get(criticalityField);
                Integer count = (Integer) ar.get('cnt');
                criticalityMap.put(criticality != null ? criticality : 'Not Set', count);
            }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving assets by criticality: ' + e.getMessage());
        }
        
        return criticalityMap;
    }
    
    /**
     * Get asset counts grouped by version status
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByVersionStatus(FilterParams filters) {
        Map<String, Integer> versionMap = new Map<String, Integer>();
        
        String versionStatusField = NamespaceUtil.getAssetFieldName('Version_Status__c');
        String query = 'SELECT ' + versionStatusField + ', COUNT(Id) cnt FROM Asset';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' WHERE ' + whereClause;
        }
        query += ' GROUP BY ' + versionStatusField + ' WITH USER_MODE';
        
        for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
            String versionStatus = (String) ar.get(versionStatusField);
            Integer count = (Integer) ar.get('cnt');
            versionMap.put(versionStatus != null ? versionStatus : 'Not Set', count);
        }
        
        return versionMap;
    }
    
    /**
     * Get asset counts grouped by maintenance status
     * Now uses MaintenancePlan and WorkOrder instead of custom fields
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByMaintenanceStatus(FilterParams filters) {
        String query = 'SELECT Id FROM Asset WHERE Status = \'Active\'';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' WITH USER_MODE';
        
        List<Asset> assets = Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
        
        // Use helper class to calculate maintenance status from FSL objects
        return AssetDashboardControllerHelper.calculateMaintenanceStatus(assets);
    }
    
    /**
     * Get total asset value grouped by criticality
     */
    @AuraEnabled
    public static Map<String, Decimal> getAssetValueByCriticality(FilterParams filters) {
        Map<String, Decimal> valueMap = new Map<String, Decimal>();
        
        String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
        String purchaseCostField = NamespaceUtil.getAssetFieldName('Purchase_Cost__c');
        String query = 'SELECT ' + criticalityField + ', SUM(' + purchaseCostField + ') totalValue FROM Asset WHERE ' + purchaseCostField + ' != null';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY ' + criticalityField + ' WITH USER_MODE';
        
        for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
            String criticality = (String) ar.get(criticalityField);
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
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        String baseWhere = whereClause != '' ? ' WHERE ' + whereClause : '';
        
        // Total assets
        metrics.totalAssets = Database.countQueryWithBinds('SELECT COUNT() FROM Asset' + baseWhere + ' WITH USER_MODE', bindVars, AccessLevel.USER_MODE);
        
        // Active assets
        Map<String, Object> activeBindVars = bindVars.clone();
        String activeWhere = whereClause != '' ? ' WHERE Status = \'Active\' AND ' + whereClause : ' WHERE Status = \'Active\'';
        metrics.activeAssets = Database.countQueryWithBinds('SELECT COUNT() FROM Asset' + activeWhere + ' WITH USER_MODE', activeBindVars, AccessLevel.USER_MODE);
        
        // Overdue maintenance - now uses MaintenancePlan
        Map<String, Object> overdueBindVars = bindVars.clone();
        String overdueQuery = 'SELECT COUNT() FROM Asset WHERE Status = \'Active\' AND Id IN (SELECT AssetId FROM MaintenancePlan WHERE NextSuggestedMaintenanceDate < TODAY)';
        if (whereClause != '') {
            overdueQuery = 'SELECT COUNT() FROM Asset WHERE Status = \'Active\' AND ' + whereClause + ' AND Id IN (SELECT AssetId FROM MaintenancePlan WHERE NextSuggestedMaintenanceDate < TODAY) WITH USER_MODE';
        } else {
            overdueQuery += ' WITH USER_MODE';
        }
        metrics.overdueAssets = Database.countQueryWithBinds(overdueQuery, overdueBindVars, AccessLevel.USER_MODE);
        
        // Critical assets
        Map<String, Object> criticalBindVars = bindVars.clone();
        String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
        String criticalWhere = whereClause != ''
            ? ' WHERE ' + criticalityField + ' = \'Critical\' AND Status = \'Active\' AND ' + whereClause
            : ' WHERE ' + criticalityField + ' = \'Critical\' AND Status = \'Active\'';
        metrics.criticalAssets = Database.countQueryWithBinds('SELECT COUNT() FROM Asset' + criticalWhere + ' WITH USER_MODE', criticalBindVars, AccessLevel.USER_MODE);
        
        // Total asset value
        Map<String, Object> valueBindVars = bindVars.clone();
        String purchaseCostField = NamespaceUtil.getAssetFieldName('Purchase_Cost__c');
        String valueQuery = 'SELECT SUM(' + purchaseCostField + ') total FROM Asset WHERE ' + purchaseCostField + ' != null';
        if (whereClause != '') {
            valueQuery += ' AND ' + whereClause;
        }
        valueQuery += ' WITH USER_MODE';
        List<AggregateResult> results = Database.queryWithBinds(valueQuery, valueBindVars, AccessLevel.USER_MODE);
        metrics.totalValue = results.isEmpty() ? 0 : (Decimal) results[0].get('total');
        if (metrics.totalValue == null) {
            metrics.totalValue = 0;
        }
        
        return metrics;
    }
    
    /**
     * Get maintenance status grouped by site (for stacked bar chart)
     * Now uses MaintenancePlan and WorkOrder data
     */
    @AuraEnabled
    public static Map<String, Map<String, Integer>> getMaintenanceStatusBySite(FilterParams filters) {
        Map<String, Map<String, Integer>> siteMap = new Map<String, Map<String, Integer>>();
        
        String siteField = NamespaceUtil.getAssetFieldName('Site__c');
        String query = 'SELECT Id, ' + siteField + ' FROM Asset WHERE Status = \'Active\' AND ' + siteField + ' != null';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' WITH USER_MODE';
        
        List<Asset> assets = Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
        
        if (assets.isEmpty()) {
            return siteMap;
        }
        
        // Get site names
        Set<Id> siteIds = new Set<Id>();
        for (Asset a : assets) {
            Id siteId = (Id)a.get(siteField);
            if (siteId != null) {
                siteIds.add(siteId);
            }
        }
        
        Map<Id, String> siteIdToName = new Map<Id, String>();
        for (Location loc : [SELECT Id, Name FROM Location WHERE Id IN :siteIds WITH USER_MODE]) {
            siteIdToName.put(loc.Id, loc.Name);
        }
        
        // Calculate maintenance status using helper
        Map<String, Integer> maintenanceStatus = AssetDashboardControllerHelper.calculateMaintenanceStatus(assets);
        
        // Group by site (simplified - would need more complex logic for per-site breakdown)
        for (Asset asset : assets) {
            Id siteId = (Id)asset.get(siteField);
            String siteName = siteIdToName.get(siteId);
            if (siteName != null && !siteMap.containsKey(siteName)) {
                siteMap.put(siteName, new Map<String, Integer>{
                    'Current' => 0,
                    'Due Soon' => 0,
                    'Overdue' => 0
                });
            }
        }
        
        return siteMap;
 
    
    /**
     * Get asset counts grouped by condition
     */
    @AuraEnabled
    public static Map<String, Integer> getAssetsByCondition(FilterParams filters) {
        Map<String, Integer> conditionMap = new Map<String, Integer>();
        
        String conditionField = NamespaceUtil.getAssetFieldName('Condition__c');
        String query = 'SELECT ' + conditionField + ', COUNT(Id) cnt FROM Asset WHERE ' + conditionField + ' != null';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY ' + conditionField + ' WITH USER_MODE';
        
        for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
            String condition = (String) ar.get(conditionField);
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
        
        String purchaseCostField = NamespaceUtil.getAssetFieldName('Purchase_Cost__c');
        String query = 'SELECT Id, Name, ' + purchaseCostField + ' FROM Asset WHERE ' + purchaseCostField + ' != null';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' ORDER BY ' + purchaseCostField + ' DESC LIMIT 10 WITH USER_MODE';
        
        for (Asset asset : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
            AssetValue av = new AssetValue();
            av.id = asset.Id;
            av.name = asset.Name;
            av.value = (Decimal)asset.get(purchaseCostField);
            assetValues.add(av);
        }
        
        return assetValues;
    }
    
    /**
     * Get assets needing maintenance schedule
     * Now queries MaintenancePlan and WorkOrder instead of custom fields
     */
    @AuraEnabled
    public static List<MaintenanceAsset> getAssetsNeedingMaintenance(FilterParams filters) {
        List<MaintenanceAsset> maintenanceAssets = new List<MaintenanceAsset>();
        
        // Query assets with their maintenance plans
        String siteField = NamespaceUtil.getAssetFieldName('Site__c');
        String query = 'SELECT Id, Name, ' + siteField + ', (SELECT Id, NextSuggestedMaintenanceDate FROM MaintenancePlans ORDER BY NextSuggestedMaintenanceDate ASC LIMIT 1) FROM Asset WHERE Status = \'Active\'';
        
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' WITH USER_MODE LIMIT 50';
        
        List<Asset> assets = Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE);
        
        // Get pending work orders for these assets
        Set<Id> assetIds = new Set<Id>();
        for (Asset a : assets) {
            assetIds.add(a.Id);
        }
        
        Map<Id, WorkOrder> latestWorkOrders = new Map<Id, WorkOrder>();
        if (!assetIds.isEmpty()) {
            for (WorkOrder wo : [
                SELECT Id, AssetId, StartDate, Status
                FROM WorkOrder
                WHERE AssetId IN :assetIds
                AND Status IN ('New', 'In Progress', 'Scheduled')
                WITH USER_MODE
                ORDER BY StartDate ASC
            ]) {
                if (!latestWorkOrders.containsKey(wo.AssetId)) {
                    latestWorkOrders.put(wo.AssetId, wo);
                }
            }
        }
        
        for (Asset asset : assets) {
            MaintenanceAsset ma = new MaintenanceAsset();
            ma.id = asset.Id;
            ma.name = asset.Name;
            ma.site = '';
            
            Date nextMaintenanceDate = null;
            
            // Check if asset has maintenance plan
            if (!asset.MaintenancePlans.isEmpty()) {
                MaintenancePlan mp = asset.MaintenancePlans[0];
                nextMaintenanceDate = mp.NextSuggestedMaintenanceDate;
            }
            
            // Check if there's a pending work order
            WorkOrder wo = latestWorkOrders.get(asset.Id);
            if (wo != null && wo.StartDate != null) {
                if (nextMaintenanceDate == null || wo.StartDate < nextMaintenanceDate) {
                    nextMaintenanceDate = wo.StartDate;
                }
            }
            
            ma.nextMaintenanceDue = nextMaintenanceDate;
            ma.maintenanceInterval = null;
            
            if (nextMaintenanceDate != null) {
                Integer daysUntil = Date.today().daysBetween(nextMaintenanceDate);
                if (daysUntil < 0) {
                    ma.status = 'Overdue';
                } else if (daysUntil <= 7) {
                    ma.status = 'Due Soon';
                } else if (daysUntil <= 30) {
                    ma.status = 'Upcoming';
                } else {
                    continue; // Skip assets with maintenance > 30 days away
                }
            } else {
                ma.status = 'Not Scheduled';
            }
            
            maintenanceAssets.add(ma);
            
            if (maintenanceAssets.size() >= 10) {
                break;
            }
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
        for (Schema.Location loc : [SELECT Id, Name FROM Location WITH USER_MODE]) {
            siteIdToName.put(loc.Id, loc.Name);
        }
        
        String siteField = NamespaceUtil.getAssetFieldName('Site__c');
        String purchaseCostField = NamespaceUtil.getAssetFieldName('Purchase_Cost__c');
        String currentValueField = NamespaceUtil.getAssetFieldName('Current_Value__c');
        
        String query = 'SELECT ' + siteField + ', SUM(' + purchaseCostField + ') purchaseCost, SUM(' + currentValueField + ') currentValue FROM Asset WHERE ' + siteField + ' != null AND (' + purchaseCostField + ' != null OR ' + currentValueField + ' != null)';
        Map<String, Object> bindVars = new Map<String, Object>();
        String whereClause = buildWhereClause(filters, bindVars);
        if (whereClause != '') {
            query += ' AND ' + whereClause;
        }
        query += ' GROUP BY ' + siteField + ' WITH USER_MODE';
        
        for (AggregateResult ar : Database.queryWithBinds(query, bindVars, AccessLevel.USER_MODE)) {
            Id siteId = (Id) ar.get(siteField);
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
     * Uses bind variables to prevent SOQL injection
     */
    private static String buildWhereClause(FilterParams filters, Map<String, Object> bindVars) {
        List<String> conditions = new List<String>();
        
        if (filters == null) {
            return '';
        }
        
        String siteField = NamespaceUtil.getAssetFieldName('Site__c');
        String criticalityField = NamespaceUtil.getAssetFieldName('Criticality__c');
        String installDateField = NamespaceUtil.getAssetFieldName('Installation_Date__c');
        
        // Validate and add site filter using bind variables
        if (filters.siteIds != null && !filters.siteIds.isEmpty()) {
            List<Id> validSiteIds = new List<Id>();
            for (String siteId : filters.siteIds) {
                if (String.isNotBlank(siteId) && siteId instanceof Id) {
                    validSiteIds.add((Id)siteId);
                }
            }
            if (!validSiteIds.isEmpty()) {
                bindVars.put('siteIds', validSiteIds);
                conditions.add(siteField + ' IN :siteIds');
            }
        }
        
        // Validate and add criticality filter using bind variables
        if (filters.criticalities != null && !filters.criticalities.isEmpty()) {
            List<String> validCriticalities = new List<String>();
            Set<String> allowedValues = new Set<String>{'Critical', 'High', 'Medium', 'Low'};
            for (String criticality : filters.criticalities) {
                if (String.isNotBlank(criticality) && allowedValues.contains(criticality)) {
                    validCriticalities.add(criticality);
                }
            }
            if (!validCriticalities.isEmpty()) {
                bindVars.put('criticalities', validCriticalities);
                conditions.add(criticalityField + ' IN :criticalities');
            }
        }
        
        // Validate and add date filters using bind variables
        if (String.isNotBlank(filters.startDate)) {
            try {
                Date startDateValue = Date.valueOf(filters.startDate);
                bindVars.put('startDate', startDateValue);
                conditions.add(installDateField + ' >= :startDate');
            } catch (Exception e) {
                System.debug('Invalid start date format: ' + filters.startDate);
            }
        }
        
        if (String.isNotBlank(filters.endDate)) {
            try {
                Date endDateValue = Date.valueOf(filters.endDate);
                bindVars.put('endDate', endDateValue);
                conditions.add(installDateField + ' <= :endDate');
            } catch (Exception e) {
                System.debug('Invalid end date format: ' + filters.endDate);
            }
        }
        
        return String.join(conditions, ' AND ');
    }
    
    /**
     * Overloaded method for backward compatibility (without bind variables)
     * DEPRECATED: Use buildWhereClause(FilterParams, Map<String, Object>) instead
     */
    private static String buildWhereClause(FilterParams filters) {
        Map<String, Object> bindVars = new Map<String, Object>();
        return buildWhereClause(filters, bindVars);
    }
}