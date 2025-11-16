/**
 * @description Trigger on Asset object to handle approval submission logic
 * @author Salesforce Technical Architect
 * @date 2025-11-16
 */
trigger AssetTrigger on Asset (after insert, after update) {
    // Delegate all logic to the handler class
    AssetApprovalHandler.handleApprovalSubmission(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
}
