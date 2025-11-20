import { LightningElement, track } from 'lwc';
import getAssetHierarchy from '@salesforce/apex/AssetHierarchyReportController.getAssetHierarchy';
import getHierarchyStats from '@salesforce/apex/AssetHierarchyReportController.getHierarchyStats';
import exportHierarchyToCSV from '@salesforce/apex/AssetHierarchyReportController.exportHierarchyToCSV';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class AssetHierarchyReport extends NavigationMixin(LightningElement) {
    @track hierarchyData = [];
    @track stats = {
        totalParents: 0,
        totalChildren: 0,
        avgChildrenPerParent: 0,
        totalValue: 0,
        assetsRequiringAttention: 0
    };
    @track isLoading = true;
    @track error;
    @track siteFilter = '';
    @track statusFilter = '';
    @track expandedRows = new Set();

    columns = [
        { 
            label: 'Asset Name', 
            fieldName: 'assetUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'name' },
                target: '_blank'
            },
            cellAttributes: {
                class: { fieldName: 'rowClass' }
            }
        },
        { label: 'Serial Number', fieldName: 'serialNumber' },
        { label: 'Asset Type', fieldName: 'assetType' },
        { 
            label: 'Criticality', 
            fieldName: 'criticality',
            cellAttributes: {
                class: { fieldName: 'criticalityClass' }
            }
        },
        { 
            label: 'Condition', 
            fieldName: 'condition',
            cellAttributes: {
                class: { fieldName: 'conditionClass' }
            }
        },
        { label: 'Version', fieldName: 'version' },
        { label: 'Version Status', fieldName: 'versionStatus' },
        { 
            label: 'Purchase Cost', 
            fieldName: 'purchaseCost',
            type: 'currency'
        },
        { 
            label: 'Last Maintenance', 
            fieldName: 'lastMaintenanceDate',
            type: 'date'
        },
        { label: 'Site', fieldName: 'siteName' }
    ];

    connectedCallback() {
        this.loadData();
        this.loadStats();
    }

    loadData() {
        this.isLoading = true;
        getAssetHierarchy({ 
            siteFilter: this.siteFilter, 
            statusFilter: this.statusFilter 
        })
        .then(result => {
            this.hierarchyData = this.processHierarchyData(result || []);
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
            this.hierarchyData = [];
            this.showToast('Error', 'Error loading hierarchy data', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    loadStats() {
        getHierarchyStats()
        .then(result => {
            if (result) {
                this.stats = {
                    totalParents: result.totalParents || 0,
                    totalChildren: result.totalChildren || 0,
                    avgChildrenPerParent: result.avgChildrenPerParent || 0,
                    totalValue: result.totalValue || 0,
                    assetsRequiringAttention: result.assetsRequiringAttention || 0
                };
            }
        })
        .catch(error => {
            this.stats = {
                totalParents: 0,
                totalChildren: 0,
                avgChildrenPerParent: 0,
                totalValue: 0,
                assetsRequiringAttention: 0
            };
        });
    }

    processHierarchyData(data) {
        let flatData = [];
        
        if (!data || !Array.isArray(data)) {
            return flatData;
        }
        
        data.forEach(parent => {
            if (!parent) return;
            
            // Add parent row
            flatData.push({
                id: parent.id,
                name: parent.name,
                assetUrl: `/lightning/r/Asset/${parent.id}/view`,
                serialNumber: parent.serialNumber,
                assetType: parent.assetType,
                criticality: parent.criticality,
                condition: parent.condition,
                purchaseCost: parent.purchaseCost,
                lastMaintenanceDate: parent.lastMaintenanceDate,
                version: parent.version,
                versionStatus: parent.versionStatus,
                siteName: parent.siteName,
                level: 0,
                hasChildren: parent.children && parent.children.length > 0,
                isExpanded: this.expandedRows.has(parent.id),
                rowClass: 'parent-row',
                criticalityClass: this.getCriticalityClass(parent.criticality),
                conditionClass: this.getConditionClass(parent.condition)
            });

            // Add children if expanded
            if (parent.children && parent.children.length > 0 && this.expandedRows.has(parent.id)) {
                parent.children.forEach(child => {
                    if (!child) return;
                    
                    flatData.push({
                        id: child.id,
                        name: '  └─ ' + child.name,
                        assetUrl: `/lightning/r/Asset/${child.id}/view`,
                        serialNumber: child.serialNumber,
                        assetType: child.assetType,
                        criticality: child.criticality,
                        condition: child.condition,
                        purchaseCost: child.purchaseCost,
                        lastMaintenanceDate: child.lastMaintenanceDate,
                        version: child.version,
                        versionStatus: child.versionStatus,
                        siteName: child.siteName,
                        level: 1,
                        hasChildren: false,
                        isExpanded: false,
                        rowClass: 'child-row',
                        criticalityClass: this.getCriticalityClass(child.criticality),
                        conditionClass: this.getConditionClass(child.condition)
                    });
                });
            }
        });

        return flatData;
    }

    getCriticalityClass(criticality) {
        if (criticality === 'Critical') return 'slds-text-color_error slds-text-title_bold';
        if (criticality === 'High') return 'slds-text-color_warning';
        return '';
    }

    getConditionClass(condition) {
        if (condition === 'Poor' || condition === 'Critical') {
            return 'slds-theme_warning';
        }
        return '';
    }

    handleRowAction(event) {
        const row = event.detail.row;
        if (row && row.hasChildren) {
            if (this.expandedRows.has(row.id)) {
                this.expandedRows.delete(row.id);
            } else {
                this.expandedRows.add(row.id);
            }
            this.loadData();
        }
    }

    handleExport() {
        this.isLoading = true;
        exportHierarchyToCSV()
        .then(csvData => {
            const blob = new Blob([csvData], { type: 'text/csv' });
            const url = window.URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = `Asset_Hierarchy_${new Date().toISOString().split('T')[0]}.csv`;
            link.click();
            window.URL.revokeObjectURL(url);
            this.showToast('Success', 'Report exported successfully', 'success');
        })
        .catch(error => {
            this.showToast('Error', 'Error exporting report', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleRefresh() {
        this.loadData();
        this.loadStats();
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

    get formattedStats() {
        const result = {
            totalParents: 0,
            totalChildren: 0,
            avgChildren: '0.0',
            totalValue: '$0',
            assetsRequiringAttention: 0
        };

        try {
            // Total Parents
            result.totalParents = parseInt(this.stats.totalParents) || 0;
            
            // Total Children
            result.totalChildren = parseInt(this.stats.totalChildren) || 0;
            
            // Average Children - SAFE CONVERSION
            const avgValue = this.stats.avgChildrenPerParent;
            if (avgValue !== null && avgValue !== undefined && avgValue !== '') {
                const numericAvg = parseFloat(avgValue);
                if (!isNaN(numericAvg) && isFinite(numericAvg)) {
                    result.avgChildren = numericAvg.toFixed(1);
                }
            }
            
            // Total Value - SAFE FORMATTING
            const valueAmount = this.stats.totalValue;
            if (valueAmount !== null && valueAmount !== undefined && valueAmount !== '') {
                const numericValue = parseFloat(valueAmount);
                if (!isNaN(numericValue) && isFinite(numericValue)) {
                    result.totalValue = new Intl.NumberFormat('en-US', { 
                        style: 'currency', 
                        currency: 'USD' 
                    }).format(numericValue);
                }
            }
            
            // Assets Requiring Attention
            result.assetsRequiringAttention = parseInt(this.stats.assetsRequiringAttention) || 0;
            
        } catch (error) {
            // Error formatting stats - use defaults
        }

        return result;
    }
}
