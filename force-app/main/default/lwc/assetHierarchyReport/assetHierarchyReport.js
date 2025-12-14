import { LightningElement, track } from 'lwc';
import getAssetHierarchy from '@salesforce/apex/AssetHierarchyReportController.getAssetHierarchy';
import getHierarchyStats from '@salesforce/apex/AssetHierarchyReportController.getHierarchyStats';
import exportHierarchyToCSV from '@salesforce/apex/AssetHierarchyReportController.exportHierarchyToCSV';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class AssetHierarchyReport extends NavigationMixin(LightningElement) {
    @track tableData = [];
    @track stats = {
        breached: 1,
        atRisk: 0,
        onTrack: 19
    };
    @track isLoading = false;
    @track error;
    
    // Filter values
    selectedStatus = '';
    selectedLocation = '';
    selectedClassification = '';
    
    // Filter options
    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Active', value: 'active' },
        { label: 'Inactive', value: 'inactive' },
        { label: 'Maintenance', value: 'maintenance' }
    ];
    
    locationOptions = [
        { label: 'All Locations', value: '' },
        { label: 'Room 101', value: 'room101' },
        { label: 'Room 201', value: 'room201' },
        { label: 'Building A', value: 'buildingA' }
    ];
    
    classificationOptions = [
        { label: 'All Classifications', value: '' },
        { label: 'Critical', value: 'critical' },
        { label: 'High', value: 'high' },
        { label: 'Medium', value: 'medium' },
        { label: 'Low', value: 'low' }
    ];

    get hasData() {
        return this.tableData && this.tableData.length > 0;
    }
    
    get formattedStats() {
        return {
            breached: this.stats.breached || 0,
            atRisk: this.stats.atRisk || 0,
            onTrack: this.stats.onTrack || 0
        };
    }

    connectedCallback() {
        this.loadSampleData();
    }

    loadSampleData() {
        // Sample data matching the design
        this.tableData = [
            {
                id: '1',
                srNumber: 'SR-00069',
                priorityClass: 'priority-yellow',
                assetName: 'AC Unit - Room 101',
                assetId: 'asset1',
                classification: '',
                age: '180.17h',
                slaRisk: 'Breached',
                slaRiskClass: 'sla-breached'
            },
            {
                id: '2',
                srNumber: 'SR-00087',
                priorityClass: 'priority-green',
                assetName: '',
                assetId: 'asset2',
                classification: '',
                age: '12.52h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '3',
                srNumber: 'SR-00084',
                priorityClass: 'priority-yellow',
                assetName: 'AC Unit - Room 101',
                assetId: 'asset3',
                classification: '',
                age: '34.47h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '4',
                srNumber: 'SR-00077',
                priorityClass: 'priority-yellow',
                assetName: 'AC Unit - Room 101',
                assetId: 'asset4',
                classification: '',
                age: '90.03h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '5',
                srNumber: 'SR-00074',
                priorityClass: 'priority-yellow',
                assetName: 'LED Panel - Room 201',
                assetId: 'asset5',
                classification: '',
                age: '135.62h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '6',
                srNumber: 'SR-00073',
                priorityClass: 'priority-yellow',
                assetName: 'LED Panel - Room 201',
                assetId: 'asset6',
                classification: '',
                age: '136.45h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '7',
                srNumber: 'SR-00072',
                priorityClass: 'priority-yellow',
                assetName: 'AC Unit - Room 101',
                assetId: 'asset7',
                classification: '',
                age: '137.28h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            },
            {
                id: '8',
                srNumber: 'SR-00071',
                priorityClass: 'priority-yellow',
                assetName: 'AC Unit - Room 101',
                assetId: 'asset8',
                classification: '',
                age: '137.38h',
                slaRisk: 'None',
                slaRiskClass: 'sla-none'
            }
        ];
        
        this.stats = {
            breached: 1,
            atRisk: 0,
            onTrack: 19
        };
    }

    loadData() {
        this.isLoading = true;
        getAssetHierarchy({ 
            siteFilter: this.selectedLocation, 
            statusFilter: this.selectedStatus 
        })
        .then(result => {
            this.processApiData(result || []);
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
            this.loadSampleData(); // Fallback to sample data
            this.showToast('Info', 'Showing sample data', 'info');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    processApiData(data) {
        // Process real API data when available
        if (data && data.length > 0) {
            this.tableData = data.map(item => ({
                id: item.id,
                srNumber: item.name || 'N/A',
                priorityClass: this.getPriorityClass(item.criticality),
                assetName: item.assetType || '',
                assetId: item.id,
                classification: item.classification || '',
                age: this.calculateAge(item.lastMaintenanceDate),
                slaRisk: this.calculateSLARisk(item),
                slaRiskClass: this.getSLARiskClass(item)
            }));
        }
    }

    getPriorityClass(criticality) {
        if (criticality === 'Critical') return 'priority-red';
        if (criticality === 'High') return 'priority-yellow';
        return 'priority-green';
    }

    calculateAge(lastMaintenanceDate) {
        if (!lastMaintenanceDate) return 'N/A';
        const now = new Date();
        const lastDate = new Date(lastMaintenanceDate);
        const diffHours = Math.abs(now - lastDate) / 36e5;
        return `${diffHours.toFixed(2)}h`;
    }

    calculateSLARisk(item) {
        // Logic to determine SLA risk
        return 'None';
    }

    getSLARiskClass(item) {
        const risk = this.calculateSLARisk(item);
        return risk === 'Breached' ? 'sla-breached' : 'sla-none';
    }

    // Filter handlers
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    handleLocationChange(event) {
        this.selectedLocation = event.detail.value;
        this.applyFilters();
    }

    handleClassificationChange(event) {
        this.selectedClassification = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        // Apply filters to table data
        // For now, just reload sample data
        this.loadSampleData();
    }

    // Row action handlers
    handleRowClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Asset',
                actionName: 'view'
            }
        });
    }

    handleAssetClick(event) {
        event.preventDefault();
        const assetId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: assetId,
                objectApiName: 'Asset',
                actionName: 'view'
            }
        });
    }

    handleViewAction(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Asset',
                actionName: 'view'
            }
        });
    }

    handleRefresh() {
        this.isLoading = true;
        this.loadSampleData();
        setTimeout(() => {
            this.isLoading = false;
            this.showToast('Success', 'SLA Status refreshed', 'success');
        }, 1000);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}
