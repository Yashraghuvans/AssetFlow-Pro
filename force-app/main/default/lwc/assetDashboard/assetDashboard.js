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
    recentAssets = [];
    searchTerm = '';
    
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
    
    get hasRecentAssets() {
        return this.recentAssets && this.recentAssets.length > 0;
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
        // Sample data for recent assets table
        this.recentAssets = [
            {
                id: '1',
                number: 'WO-23501',
                type: 'PM',
                typeClass: 'badge badge-pm',
                priority: '3 - Medium',
                priorityClass: 'priority-medium',
                name: 'Backup Gen 1',
                status: 'In Progress',
                technician: 'John S',
                initiationSource: 'Auto (Time)'
            },
            {
                id: '2',
                number: 'WO-00125',
                type: 'PM',
                typeClass: 'badge badge-pm',
                priority: '3 - Medium',
                priorityClass: 'priority-medium',
                name: 'LED Panel - Room 201',
                status: 'In Progress',
                technician: 'Demo Supervisor',
                initiationSource: 'Auto (Time)'
            },
            {
                id: '3',
                number: 'WO-23550',
                type: 'CM',
                typeClass: 'badge badge-cm',
                priority: '1 - Critical',
                priorityClass: 'priority-critical',
                name: 'GEN-A',
                status: 'Approved',
                technician: 'Mike J',
                initiationSource: 'Asset Failure'
            },
            {
                id: '4',
                number: 'WO-23499',
                type: 'PM',
                typeClass: 'badge badge-pm',
                priority: '2 - High',
                priorityClass: 'priority-high',
                name: 'CHIL-B1',
                status: 'On Hold',
                technician: 'Sarah',
                initiationSource: 'Auto (Time)'
            },
            {
                id: '5',
                number: 'WO-23475',
                type: 'CM',
                typeClass: 'badge badge-cm',
                priority: '2 - High',
                priorityClass: 'priority-high',
                name: 'PUMP-A3',
                status: 'In Progress',
                technician: 'David',
                initiationSource: 'Service Request'
            },
            {
                id: '6',
                number: 'WO-23470',
                type: 'PM',
                typeClass: 'badge badge-pm',
                priority: '3 - Medium',
                priorityClass: 'priority-medium',
                name: 'Fire Pump 1',
                status: 'Completed',
                technician: 'Mike J',
                initiationSource: 'Auto (Meter)'
            },
            {
                id: '7',
                number: 'WO-23468',
                type: 'CM',
                typeClass: 'badge badge-cm',
                priority: '3 - Medium',
                priorityClass: 'priority-medium',
                name: 'Door Latch',
                status: 'New',
                technician: 'Unassigned',
                initiationSource: 'Manual'
            }
        ];
    }
    
    prepareMaintenanceAssetsTable(data) {
        // This method is no longer needed but kept for compatibility
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
    
    handleRowClick(event) {
        const assetId = event.currentTarget.dataset.id;
        if (assetId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: assetId,
                    objectApiName: 'Asset',
                    actionName: 'view'
                }
            });
        }
    }
    
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        // Implement search filtering logic here
    }
    
    handleNewAsset() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'new'
            }
        });
    }
    
    navigateToReports() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Report',
                actionName: 'home'
            }
        });
    }
    
    handleViewSchedule(event) {
        event.preventDefault();
        this.dispatchEvent(new ShowToastEvent({
            title: 'View Schedule',
            message: 'Opening maintenance schedule...',
            variant: 'info'
        }));
    }
    
    handleViewEmergency(event) {
        event.preventDefault();
        this.dispatchEvent(new ShowToastEvent({
            title: 'Emergency Work Orders',
            message: 'Opening emergency work orders...',
            variant: 'info'
        }));
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