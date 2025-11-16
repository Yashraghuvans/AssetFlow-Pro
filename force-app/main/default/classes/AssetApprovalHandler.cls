/**
 * @description Handler class for Asset trigger to manage approval process submission
 * @author Salesforce Technical Architect
 * @date 2025-11-16
 */
public without sharing class AssetApprovalHandler {
    
    // Threshold for high-value assets
    private static final Decimal HIGH_VALUE_THRESHOLD = 10000;
    
    // Approval process API name
    private static final String APPROVAL_PROCESS_NAME = 'High_Value_Asset_Approval';
    
    /**
     * @description Handles approval submission for Asset records based on complex criteria
     * @param newAssets List of new/updated Asset records from Trigger.new
     * @param oldAssetMap Map of old Asset records from Trigger.oldMap
     * @param isInsert True if this is an insert operation
     * @param isUpdate True if this is an update operation
     */
    public static void handleApprovalSubmission(
        List<Asset> newAssets,
        Map<Id, Asset> oldAssetMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        // List to hold approval submission requests
        List<Approval.ProcessSubmitRequest> requestList = new List<Approval.ProcessSubmitRequest>();
        
        // Iterate through all Asset records in the trigger context
        for (Asset newAsset : newAssets) {
            // Get the old version of the record (null for insert operations)
            Asset oldAsset = oldAssetMap != null ? oldAssetMap.get(newAsset.Id) : null;
            
            // Evaluate if this asset should be submitted for approval
            if (shouldSubmitForApproval(newAsset, oldAsset, isInsert, isUpdate)) {
                // Create approval submission request
                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(newAsset.Id);
                req.setProcessDefinitionNameOrId(APPROVAL_PROCESS_NAME);
                req.setComments('Submitting high-value asset for approval.');
                
                requestList.add(req);
            }
        }
        
        // Submit all qualifying records for approval (bulk-safe)
        if (!requestList.isEmpty()) {
            try {
                Approval.process(requestList);
            } catch (Exception e) {
                // Log error for troubleshooting
                System.debug(LoggingLevel.ERROR, 'Error submitting asset for approval: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            }
        }
    }
    
    /**
     * @description Evaluates whether an Asset record meets the criteria for approval submission
     * @param newAsset The new/updated Asset record
     * @param oldAsset The old version of the Asset record (null for inserts)
     * @param isInsert True if this is an insert operation
     * @param isUpdate True if this is an update operation
     * @return Boolean True if the asset should be submitted for approval
     */
    private static Boolean shouldSubmitForApproval(
        Asset newAsset,
        Asset oldAsset,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        // Condition A: Asset must be high-value (Purchase Cost > 10,000)
        if (newAsset.Purchase_Cost__c == null || newAsset.Purchase_Cost__c <= HIGH_VALUE_THRESHOLD) {
            return false;
        }
        
        // Condition C: Prevent re-submission if already pending approval
        // This prevents infinite loops if the approval process changes the Status field
        if (newAsset.Status == 'Pending Approval') {
            return false;
        }
        
        // Condition B: Check if this is a new record OR if relevant fields have changed
        Boolean isRelevantChange = false;
        
        if (isInsert) {
            // New records always qualify if they meet value and status criteria
            isRelevantChange = true;
        } else if (isUpdate && oldAsset != null) {
            // Check if any of the critical fields have changed
            Boolean purchaseCostChanged = newAsset.Purchase_Cost__c != oldAsset.Purchase_Cost__c;
            Boolean glAccountChanged = newAsset.GL_Account__c != oldAsset.GL_Account__c;
            Boolean costCenterChanged = newAsset.Cost_Center__c != oldAsset.Cost_Center__c;
            
            isRelevantChange = purchaseCostChanged || glAccountChanged || costCenterChanged;
        }
        
        return isRelevantChange;
    }
}
