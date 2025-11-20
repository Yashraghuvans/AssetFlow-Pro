import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAssetDetails from '@salesforce/apex/AssetVersionController.getAssetDetails';
import createPlannedVersion from '@salesforce/apex/AssetVersionController.createPlannedVersion';
import activatePlannedVersion from '@salesforce/apex/AssetVersionController.activatePlannedVersion';
import supersedeVersion from '@salesforce/apex/AssetVersionController.supersedeVersion';
import findRelatedLiveAsset from '@salesforce/apex/AssetVersionController.findRelatedLiveAsset';

export default class AssetVersionTransition extends LightningElement {
    @api recordId;
    
    // UI State
    isLoading = true;
    currentScreen = 1;
    
    // Data
    assetData;
    transitionType = '';
    isConfirmed = false;
    form = {
        newVersion: '',
        versionNotes: '',
        goLiveDate: null,
        assignedEngineerId: null
    };
    
    error;
    
    @wire(getAssetDetails, { assetId: '$recordId' })
    wiredAsset({ error, data }) {
        if (data) {
            this.assetData = data;
            this.isLoading = false;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.showToast('Error Loading Data', error.body.message, 'error');
            this.isLoading = false;
        }
    }

    
    get isScreen1() { return this.currentScreen === 1; }
    get isScreen2() { return this.currentScreen === 2; }
    get isScreen3() { return this.currentScreen === 3; }
    get isActivating() { return this.transitionType === 'ActivatePlanned'; }
    get isSuperseding() { return this.transitionType === 'Supersede'; }
    get isNextDisabled() { return !this.transitionType; }
    
    get transitionOptions() {
        if (!this.assetData) return [];
        const status = this.assetData.versionStatus;
        let options = [];
        
        if (status === 'Live') {
            options.push({ 
                label: 'Create New Planned Version (from current Live)', 
                value: 'CreatePlanned' 
            });
            options.push({ 
                label: 'Supersede Current Version (mark as superseded without replacement)', 
                value: 'Supersede' 
            });
        } else if (status === 'Planned') {
            options.push({ 
                label: 'Activate Planned Version (Planned → Live, old Live → Superseded)', 
                value: 'ActivatePlanned' 
            });
        }
        
        return options;
    }
    
    get selectedOption() {
        return this.transitionOptions.find(opt => opt.value === this.transitionType) || {};
    }

    
    handleTypeChange(event) {
        this.transitionType = event.detail.value;
    }
    
    handleFormChange(event) {
        const { name, value } = event.target;
        this.form[name] = value;
    }
    
    handleConfirmCheck(event) {
        this.isConfirmed = event.target.checked;
    }
    
    handleNext() {
        if (this.transitionType === 'CreatePlanned') {
            this.currentScreen = 2;
        } else {
            this.currentScreen = 3;
        }
    }
    
    handleBack() {
        if (this.currentScreen === 3) {
            this.currentScreen = (this.transitionType === 'CreatePlanned') ? 2 : 1;
        } else if (this.currentScreen === 2) {
            this.currentScreen = 1;
        }
        this.isConfirmed = false;
    }
    
    handleConfirmDetails() {
        const inputs = this.template.querySelectorAll('lightning-input');
        const allValid = [...inputs].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
        
        if (allValid) {
            this.currentScreen = 3;
        } else {
            this.showToast('Validation Error', 'Please check the fields and try again.', 'error');
        }
    }

    
    async handleFinish() {
        this.isLoading = true;
        
        try {
            switch (this.transitionType) {
                case 'CreatePlanned':
                    await createPlannedVersion({
                        originalAssetId: this.recordId,
                        newVersion: this.form.newVersion,
                        versionNotes: this.form.versionNotes,
                        goLiveDate: this.form.goLiveDate,
                        assignedEngineerId: this.form.assignedEngineerId
                    });
                    this.showToast('Success', 'New planned version has been created.', 'success');
                    break;
                    
                case 'ActivatePlanned':
                    const liveAssetId = await findRelatedLiveAsset({ 
                        assetName: this.assetData.name 
                    });
                    await activatePlannedVersion({ 
                        plannedAssetId: this.recordId, 
                        relatedLiveAssetId: liveAssetId 
                    });
                    this.showToast('Success', 'Asset has been activated.', 'success');
                    break;
                    
                case 'Supersede':
                    await supersedeVersion({ assetId: this.recordId });
                    this.showToast('Success', 'Asset has been superseded.', 'success');
                    break;
                    
                default:
                    throw new Error('Invalid transition type selected.');
            }
            
            this.closeModal(true);
        } catch (error) {
            let errorMessage = 'An unknown error occurred';
            
            if (error.body) {
                if (error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errorMessage = error.body.pageErrors[0].message;
                } else if (error.body.fieldErrors) {
                    errorMessage = JSON.stringify(error.body.fieldErrors);
                }
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    closeModal(refresh = false) {
        this.dispatchEvent(new CloseActionScreenEvent());
        if (refresh) {
            // Use standard navigation to refresh the page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Asset',
                    actionName: 'view'
                }
            });
        }
    }
    
    get isConfirmDisabled() {
        return !this.isConfirmed;
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}