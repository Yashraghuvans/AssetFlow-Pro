import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getAssetsByStatus from '@salesforce/apex/AssetDashboardController.getAssetsByStatus';
import getAssetsByCriticality from '@salesforce/apex/AssetDashboardController.getAssetsByCriticality';
import getAssetsByVersionStatus from '@salesforce/apex/AssetDashboardController.getAssetsByVersionStatus';
import getAssetsByMaintenanceStatus from '@salesforce/apex/AssetDashboardController.getAssetsByMaintenanceStatus';
import getAssetValueByCriticality from '@salesforce/apex/AssetDashboardController.getAssetValueByCriticality';
import getDashboardMetrics from '@salesforce/apex/AssetDashboardController.getDashboardMetrics';
import getMaintenanceStatusBySite from '@salesforce/apex/AssetDashboardController.getMaintenanceStatusBySite';
import getAssetsByCondition from '@salesforce/apex/AssetDashboardController.getAssetsByCondition';
import getTop10ExpensiveAssets from '@salesforce/apex/AssetDashboardController.getTop10ExpensiveAssets';
import getAssetsNeedingMaintenance from '@salesforce/apex/AssetDashboardController.getAssetsNeedingMaintenance';
import getAssetValueBySite from '@salesforce/apex/AssetDashboardController.getAssetValueBySite';
import getSiteOptions from '@salesforce/apex/AssetDashboardController.getSiteOptions';

export default class AssetDashboard extends NavigationMixin(LightningElement) {
    isLoading = true;
    
    metrics = {
        totalAssets: 0,
        activeAssets: 0,
        overdueAssets: 0,
        criticalAssets: 0,
        totalValue: 0
    };
    
    // Filter options
    siteOptions = [];
    criticalityOptions = [
        { label: 'Critical', value: 'Critical' },
        { label: 'High', value: 'High' },
        { label: 'Medium', value: 'Medium' },
        { label: 'Low', value: 'Low' }
    ];
    
    // Selected filter values
    selectedSites = [];
    selectedCriticalities = [];
    startDate = null;
    endDate = null;
    
    // Applied filters (used for actual filtering)
    appliedFilters = {
        sites: [],
        criticalities: [],
        startDate: null,
        endDate: null
    };
    
    // Chart configurations
    statusChartConfig;
    criticalityChartConfig;
    versionChartConfig;
    maintenanceChartConfig;
    valueChartConfig;
    maintenanceBySiteConfig;
    conditionChartConfig;
    siteValueChartConfig;
    
    // Table data
    expensiveAssets = [];
    maintenanceAssets = [];
    
    // Table columns
    expensiveColumns = [
        { label: 'Asset Name', fieldName: 'assetUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
        { label: 'Value', fieldName: 'value', type: 'currency', cellAttributes: { alignment: 'left' } },
        { 
            type: 'action',
            typeAttributes: { 
                rowActions: [
                    { label: 'View Details', name: 'view' },
                    { label: 'Edit', name: 'edit' }
                ]
            }
        }
    ];
    
    maintenanceColumns = [
        { label: 'Asset Name', fieldName: 'assetUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_blank' } },
        { label: 'Site', fieldName: 'site', type: 'text' },
        { label: 'Next Due', fieldName: 'nextMaintenanceDue', type: 'date' },
        { 
            label: 'Status', 
            fieldName: 'status', 
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            }
        },
        { label: 'Days Until Due', fieldName: 'daysUntilDue', type: 'number' },
        { 
            type: 'action',
            typeAttributes: { 
                rowActions: [
                    { label: 'View Details', name: 'view' },
                    { label: 'Schedule Maintenance', name: 'schedule' }
                ]
            }
        }
    ];
    
    async loadMetrics() {
        try {
            const filters = {
                siteIds: this.appliedFilters.sites,
                criticalities: this.appliedFilters.criticalities,
                startDate: this.appliedFilters.startDate,
                endDate: this.appliedFilters.endDate
            };
            this.metrics = await getDashboardMetrics(filters);
        } catch (error) {
            this.showError('Error loading metrics', error);
        }
    }
    
    get formattedTotalValue() {
        const value = this.metrics.totalValue || 0;
        
        if (value >= 1000000000000) {
            return '$' + (value / 1000000000000).toFixed(1) + 'T';
        } else if (value >= 1000000000) {
            return '$' + (value / 1000000000).toFixed(1) + 'B';
        } else if (value >= 1000000) {
            return '$' + (value / 1000000).toFixed(1) + 'M';
        } else if (value >= 1000) {
            return '$' + (value / 1000).toFixed(1) + 'K';
        }
        
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0
        }).format(value);
    }
    
    get activePercentage() {
        if (this.metrics.totalAssets === 0) return 0;
        return Math.round((this.metrics.activeAssets / this.metrics.totalAssets) * 100);
    }
    
    get hasExpensiveAssets() {
        return this.expensiveAssets && this.expensiveAssets.length > 0;
    }
    
    get hasMaintenanceAssets() {
        return this.maintenanceAssets && this.maintenanceAssets.length > 0;
    }
    
    connectedCallback() {
        this.loadSiteOptions();
        this.loadMetrics();
        this.loadAllCharts();
    }
    
    async loadSiteOptions() {
        try {
            const sites = await getSiteOptions();
            this.siteOptions = sites.map(site => ({
                label: site.name,
                value: site.id
            }));
        } catch (error) {
            this.showError('Error loading site options', error);
        }
    }
    
    handleSiteChange(event) {
        this.selectedSites = event.detail.value;
    }
    
    handleCriticalityChange(event) {
        this.selectedCriticalities = event.detail.value;
    }
    
    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }
    
    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }
    
    handleApplyFilters() {
        this.appliedFilters = {
            sites: [...this.selectedSites],
            criticalities: [...this.selectedCriticalities],
            startDate: this.startDate,
            endDate: this.endDate
        };
        this.isLoading = true;
        this.loadMetrics();
        this.loadAllCharts();
    }
    
    handleClearFilters() {
        this.selectedSites = [];
        this.selectedCriticalities = [];
        this.startDate = null;
        this.endDate = null;
        this.appliedFilters = {
            sites: [],
            criticalities: [],
            startDate: null,
            endDate: null
        };
        this.isLoading = true;
        this.loadMetrics();
        this.loadAllCharts();
    }
    
    async loadAllCharts() {
        try {
            const filters = {
                siteIds: this.appliedFilters.sites,
                criticalities: this.appliedFilters.criticalities,
                startDate: this.appliedFilters.startDate,
                endDate: this.appliedFilters.endDate
            };
            
            const [
                statusData, 
                criticalityData, 
                versionData, 
                maintenanceData, 
                valueData,
                maintenanceBySiteData,
                conditionData,
                expensiveAssetsData,
                maintenanceAssetsData,
                siteValueData
            ] = await Promise.all([
                getAssetsByStatus(filters),
                getAssetsByCriticality(filters),
                getAssetsByVersionStatus(filters),
                getAssetsByMaintenanceStatus(filters),
                getAssetValueByCriticality(filters),
                getMaintenanceStatusBySite(filters),
                getAssetsByCondition(filters),
                getTop10ExpensiveAssets(filters),
                getAssetsNeedingMaintenance(filters),
                getAssetValueBySite(filters)
            ]);
            
            this.prepareStatusChart(statusData);
            this.prepareCriticalityChart(criticalityData);
            this.prepareVersionChart(versionData);
            this.prepareMaintenanceChart(maintenanceData);
            this.prepareValueChart(valueData);
            this.prepareMaintenanceBySiteChart(maintenanceBySiteData);
            this.prepareConditionChart(conditionData);
            this.prepareSiteValueChart(siteValueData);
            this.prepareExpensiveAssetsTable(expensiveAssetsData);
            this.prepareMaintenanceAssetsTable(maintenanceAssetsData);
            
            this.isLoading = false;
        } catch (error) {
            this.showError('Error loading charts', error);
            this.isLoading = false;
        }
    }
    
    prepareStatusChart(data) {
        this.statusChartConfig = {
            type: 'donut',
            title: 'Assets by Status',
            labels: Object.keys(data),
            datasets: [{
                label: 'Count',
                backgroundColor: ['#1589EE', '#4BCA81', '#FFB75D'],
                data: Object.values(data)
            }]
        };
    }
    
    prepareCriticalityChart(data) {
        this.criticalityChartConfig = {
            type: 'pie',
            title: 'Assets by Criticality',
            labels: Object.keys(data),
            datasets: [{
                label: 'Count',
                backgroundColor: ['#E74C3C', '#FFB75D', '#FFD700', '#4BCA81'],
                data: Object.values(data)
            }]
        };
    }
    
    prepareVersionChart(data) {
        const total = Object.values(data).reduce((sum, val) => sum + val, 0);
        const liveCount = data['Live'] || 0;
        const percentage = total > 0 ? Math.round((liveCount / total) * 100) : 0;
        
        this.versionChartConfig = {
            type: 'gauge',
            title: 'Version Status (% Live)',
            value: percentage,
            labels: Object.keys(data),
            datasets: [{
                label: 'Count',
                backgroundColor: ['#4BCA81', '#FFB75D', '#E74C3C'],
                data: Object.values(data)
            }]
        };
    }
    
    prepareMaintenanceChart(data) {
        this.maintenanceChartConfig = {
            type: 'bar',
            title: 'Maintenance Status',
            labels: Object.keys(data),
            datasets: [{
                label: 'Asset Count',
                backgroundColor: ['#4BCA81', '#FFB75D', '#E74C3C'],
                data: Object.values(data)
            }]
        };
    }
    
    prepareValueChart(data) {
        const values = Object.values(data);
        this.valueChartConfig = {
            type: 'bar',
            title: 'Asset Value by Criticality',
            labels: Object.keys(data),
            datasets: [{
                label: 'Total Value ($)',
                backgroundColor: '#1589EE',
                data: values
            }]
        };
    }
    
    prepareMaintenanceBySiteChart(data) {
        const sites = Object.keys(data);
        const currentData = sites.map(site => data[site]['Current'] || 0);
        const dueSoonData = sites.map(site => data[site]['Due Soon'] || 0);
        const overdueData = sites.map(site => data[site]['Overdue'] || 0);
        
        this.maintenanceBySiteConfig = {
            type: 'horizontalBar',
            title: 'Maintenance Status by Site',
            labels: sites,
            datasets: [
                {
                    label: 'Current',
                    backgroundColor: '#4BCA81',
                    data: currentData
                },
                {
                    label: 'Due Soon',
                    backgroundColor: '#FFB75D',
                    data: dueSoonData
                },
                {
                    label: 'Overdue',
                    backgroundColor: '#E74C3C',
                    data: overdueData
                }
            ]
        };
    }
    
    prepareConditionChart(data) {
        // Order conditions from best to worst for funnel effect
        const conditionOrder = ['Excellent', 'Good', 'Fair', 'Poor', 'Critical'];
        const orderedLabels = [];
        const orderedData = [];
        const colors = ['#4BCA81', '#A8E6CF', '#FFB75D', '#FF8C69', '#E74C3C'];
        
        conditionOrder.forEach(condition => {
            if (data[condition]) {
                orderedLabels.push(condition);
                orderedData.push(data[condition]);
            }
        });
        
        this.conditionChartConfig = {
            type: 'funnel',
            title: 'Assets by Condition',
            labels: orderedLabels,
            datasets: [{
                label: 'Asset Count',
                backgroundColor: colors.slice(0, orderedLabels.length),
                data: orderedData
            }]
        };
    }
    
    prepareSiteValueChart(data) {
        const sites = Object.keys(data);
        const purchaseCosts = sites.map(site => data[site].purchaseCost || 0);
        const currentValues = sites.map(site => data[site].currentValue || 0);
        
        this.siteValueChartConfig = {
            type: 'bar',
            title: 'Asset Value by Site',
            labels: sites,
            datasets: [
                {
                    label: 'Purchase Cost',
                    backgroundColor: '#1589EE',
                    data: purchaseCosts
                },
                {
                    label: 'Current Value',
                    backgroundColor: '#4BCA81',
                    data: currentValues
                }
            ]
        };
    }
    
    prepareExpensiveAssetsTable(data) {
        this.expensiveAssets = data.map(asset => ({
            id: asset.id,
            name: asset.name,
            value: asset.value,
            assetUrl: `/lightning/r/Asset/${asset.id}/view`
        }));
    }
    
    prepareMaintenanceAssetsTable(data) {
        const today = new Date();
        this.maintenanceAssets = data.map(asset => {
            let daysUntilDue = null;
            let statusClass = '';
            
            if (asset.nextMaintenanceDue) {
                const dueDate = new Date(asset.nextMaintenanceDue);
                daysUntilDue = Math.ceil((dueDate - today) / (1000 * 60 * 60 * 24));
                
                if (asset.status === 'Overdue') {
                    statusClass = 'slds-text-color_error slds-text-title_bold';
                } else if (asset.status === 'Due Soon') {
                    statusClass = 'slds-text-color_warning slds-text-title_bold';
                }
            }
            
            return {
                id: asset.id,
                name: asset.name,
                site: asset.site || 'Not Assigned',
                nextMaintenanceDue: asset.nextMaintenanceDue,
                status: asset.status,
                statusClass: statusClass,
                daysUntilDue: daysUntilDue,
                assetUrl: `/lightning/r/Asset/${asset.id}/view`
            };
        });
    }
    
    handleRefresh() {
        this.isLoading = true;
        this.loadMetrics();
        this.loadAllCharts();
    }
    
    // Navigation handlers
    navigateToAllAssets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }
    
    navigateToActiveAssets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'list'
            },
            state: {
                filterName: 'Active_Assets'
            }
        });
    }
    
    navigateToOverdueAssets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'list'
            },
            state: {
                filterName: 'Overdue_Maintenance'
            }
        });
    }
    
    navigateToCriticalAssets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'list'
            },
            state: {
                filterName: 'Critical_Assets'
            }
        });
    }
    
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'view':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.id,
                        objectApiName: 'Asset',
                        actionName: 'view'
                    }
                });
                break;
            case 'edit':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.id,
                        objectApiName: 'Asset',
                        actionName: 'edit'
                    }
                });
                break;
            case 'schedule':
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Schedule Maintenance',
                    message: `Opening maintenance scheduler for ${row.name}`,
                    variant: 'info'
                }));
                // Navigate to edit page with focus on maintenance fields
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.id,
                        objectApiName: 'Asset',
                        actionName: 'edit'
                    }
                });
                break;
            default:
        }
    }
    
    handleScheduleMaintenance() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Bulk Maintenance Scheduling',
            message: 'Opening maintenance work order creation...',
            variant: 'info'
        }));
        
        // Navigate to create new maintenance record
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Maintenance__c',
                actionName: 'new'
            }
        });
    }
    
    showError(title, error) {
        let message = 'Unknown error';
        if (error && error.body && error.body.message) {
            message = error.body.message;
        } else if (error && error.message) {
            message = error.message;
        }
        
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error'
        }));
    }
}