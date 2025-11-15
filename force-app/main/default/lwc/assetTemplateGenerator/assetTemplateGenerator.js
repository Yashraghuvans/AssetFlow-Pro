import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getActiveTemplates from '@salesforce/apex/AssetTemplateService.getActiveTemplates';
import generateAssetsFromTemplate from '@salesforce/apex/AssetTemplateService.generateAssetsFromTemplate';

/**
 * Lightning Web Component for generating multiple assets from a template
 */
export default class AssetTemplateGenerator extends NavigationMixin(LightningElement) {
    
    // Public properties for Lightning Page configuration
    @api showDescription;
    @api cardTitle = 'Asset Template Generator';
    @api defaultAssetType = '';
    
    // Form input properties
    selectedTemplateId = '';
    quantity = 1;
    sitePrefix = '';
    startNumber = 1;
    
    // UI state properties
    isGenerating = false;
    successMessage = '';
    
    // Template data
    @track templateOptions = [];
    @track previewNames = [];
    selectedTemplate = null;
    
    /**
     * Wire service to fetch active templates from Apex
     * Automatically populates the template dropdown
     */
    @wire(getActiveTemplates)
    wiredTemplates({ error, data }) {
        if (data) {
            // Transform template records into combobox options
            this.templateOptions = data.map(template => {
                return {
                    label: `${template.Name} - ${template.Asset_Type__c || 'N/A'}`,
                    value: template.Id,
                    assetType: template.Asset_Type__c
                };
            });
        } else if (error) {
            this.showToast('Error', 'Failed to load templates: ' + error.body.message, 'error');
        }
    }
    
    /**
     * Handle template selection change
     */
    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
        
        // Find the selected template to get asset type
        const selectedOption = this.templateOptions.find(opt => opt.value === this.selectedTemplateId);
        if (selectedOption) {
            this.selectedTemplate = selectedOption;
            this.updatePreview();
        }
    }
    
    /**
     * Handle quantity input change
     */
    handleQuantityChange(event) {
        this.quantity = parseInt(event.detail.value, 10);
        this.updatePreview();
    }
    
    /**
     * Handle site prefix input change
     */
    handleSitePrefixChange(event) {
        this.sitePrefix = event.detail.value;
        this.updatePreview();
    }
    
    /**
     * Handle starting number input change
     */
    handleStartNumberChange(event) {
        this.startNumber = parseInt(event.detail.value, 10);
        this.updatePreview();
    }
    
    /**
     * Updates the preview section with first 5 asset names
     * Format: {sitePrefix}-{AssetType}-{number}
     * Example: SITE-A-VEHICLE-0001
     */
    updatePreview() {
        this.previewNames = [];
        
        // Validate required fields before generating preview
        if (!this.selectedTemplate || !this.sitePrefix || !this.quantity || this.startNumber === null) {
            return;
        }
        
        const assetType = this.selectedTemplate.assetType ? this.selectedTemplate.assetType.toUpperCase() : 'ASSET';
        const previewCount = Math.min(5, this.quantity);
        
        // Generate preview names (first 5)
        for (let i = 0; i < previewCount; i++) {
            const num = this.startNumber + i;
            const formattedNum = String(num).padStart(4, '0');
            const assetName = `${this.sitePrefix}-${assetType}-${formattedNum}`;
            this.previewNames.push(assetName);
        }
    }
    
    /**
     * Handle Generate Assets button click
     * Calls Apex method to create assets in bulk
     */
    async handleGenerate() {
        // Validate all required fields
        if (!this.validateInputs()) {
            return;
        }
        
        this.isGenerating = true;
        this.successMessage = '';
        
        try {
            // Call Apex method to generate assets
            const assetIds = await generateAssetsFromTemplate({
                templateId: this.selectedTemplateId,
                quantity: this.quantity,
                sitePrefix: this.sitePrefix,
                startNumber: this.startNumber
            });
            
            // Show success message
            this.successMessage = `Successfully created ${assetIds.length} asset(s)!`;
            this.showToast('Success', this.successMessage, 'success');
            
            // Navigate to Assets list view to see all created assets
            this.navigateToAssetsList();
            
            // Reset form after short delay
            setTimeout(() => {
                this.handleCancel();
            }, 2000);
            
        } catch (error) {
            // Handle and display error
            const errorMessage = error.body ? error.body.message : error.message;
            this.showToast('Error', 'Failed to generate assets: ' + errorMessage, 'error');
        } finally {
            this.isGenerating = false;
        }
    }
    
    /**
     * Handle Cancel button click
     * Resets all form fields to default values
     */
    handleCancel() {
        this.selectedTemplateId = '';
        this.quantity = 1;
        this.sitePrefix = '';
        this.startNumber = 1;
        this.previewNames = [];
        this.selectedTemplate = null;
        this.successMessage = '';
    }
    
    /**
     * Validates all input fields before submission
     * @returns {boolean} true if all validations pass
     */
    validateInputs() {
        if (!this.selectedTemplateId) {
            this.showToast('Validation Error', 'Please select a template', 'error');
            return false;
        }
        
        if (!this.quantity || this.quantity < 1 || this.quantity > 100) {
            this.showToast('Validation Error', 'Quantity must be between 1 and 100', 'error');
            return false;
        }
        
        if (!this.sitePrefix || this.sitePrefix.trim() === '') {
            this.showToast('Validation Error', 'Please enter a site prefix', 'error');
            return false;
        }
        
        if (this.startNumber === null || this.startNumber < 0) {
            this.showToast('Validation Error', 'Starting number must be 0 or greater', 'error');
            return false;
        }
        
        return true;
    }
    
    /**
     * Navigate to Assets list view
     */
    navigateToAssetsList() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Asset',
                actionName: 'list'
            }
        });
    }
    
    /**
     * Helper method to show toast notifications
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     * @param {string} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
    
    // ========== COMPUTED PROPERTIES ==========
    
    /**
     * Determines if the Generate button should be disabled
     */
    get isGenerateDisabled() {
        return this.isGenerating || 
               !this.selectedTemplateId || 
               !this.sitePrefix || 
               !this.quantity ||
               this.startNumber === null;
    }
    
    /**
     * Determines if preview section should be shown
     */
    get showPreview() {
        return this.previewNames.length > 0;
    }
    
    /**
     * Determines if there are more assets than shown in preview
     */
    get hasMoreAssets() {
        return this.quantity > 5;
    }
    
    /**
     * Calculates remaining asset count not shown in preview
     */
    get remainingCount() {
        return this.quantity - 5;
    }
}