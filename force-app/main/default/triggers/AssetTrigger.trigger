/**
 * @description Unified trigger on Asset object - handles all Asset trigger logic
 * @author Salesforce Technical Architect
 * @date 2025-11-17
 */
trigger AssetTrigger on Asset (before insert, before update, after insert, after update, after delete, after undelete) {
    
    // Prevent recursion
    if (AssetTriggerHandler.isExecuting) {
        return;
    }
    
    AssetTriggerHandler.isExecuting = true;
    
    try {
        // BEFORE INSERT
        if (Trigger.isBefore && Trigger.isInsert) {
            AssetHierarchyService.calculateHierarchyLevel(Trigger.new);
            AssetTriggerHandler.validateHierarchy(Trigger.new, null);
        }
        
        // BEFORE UPDATE
        if (Trigger.isBefore && Trigger.isUpdate) {
            AssetHierarchyService.calculateHierarchyLevel(Trigger.new);
            AssetTriggerHandler.validateHierarchy(Trigger.new, Trigger.oldMap);
        }
        
        // AFTER INSERT
        if (Trigger.isAfter && Trigger.isInsert) {
            // Handle approval submission
            AssetApprovalHandler.handleApprovalSubmission(
                Trigger.new,
                null,
                true,
                false
            );
            
            // Update template counts
            AssetTriggerHandler.updateTemplateCounts(Trigger.new, null, false);
            
            // Update parent child counts
            Set<Id> parentIds = AssetChildCountService.getAffectedParentIds(Trigger.new, null, false);
            if (!parentIds.isEmpty()) {
                AssetChildCountService.updateParentChildCounts(parentIds);
            }
        }
        
        // AFTER UPDATE
        if (Trigger.isAfter && Trigger.isUpdate) {
            // Handle approval submission
            AssetApprovalHandler.handleApprovalSubmission(
                Trigger.new,
                Trigger.oldMap,
                false,
                true
            );
            
            // Send overdue maintenance emails
            AssetTriggerHandler.handleOverdueMaintenanceAlerts(Trigger.new, Trigger.oldMap);
            
            // Update template counts
            AssetTriggerHandler.updateTemplateCounts(Trigger.new, Trigger.old, false);
            
            // Update parent child counts
            Set<Id> parentIds = AssetChildCountService.getAffectedParentIds(Trigger.new, Trigger.old, false);
            if (!parentIds.isEmpty()) {
                AssetChildCountService.updateParentChildCounts(parentIds);
            }
        }
        
        // AFTER DELETE
        if (Trigger.isAfter && Trigger.isDelete) {
            // Update template counts
            AssetTriggerHandler.updateTemplateCounts(null, Trigger.old, true);
            
            // Update parent child counts
            Set<Id> parentIds = AssetChildCountService.getAffectedParentIds(null, Trigger.old, true);
            if (!parentIds.isEmpty()) {
                AssetChildCountService.updateParentChildCounts(parentIds);
            }
        }
        
        // AFTER UNDELETE
        if (Trigger.isAfter && Trigger.isUndelete) {
            // Update template counts
            AssetTriggerHandler.updateTemplateCounts(Trigger.new, null, false);
            
            // Update parent child counts
            Set<Id> parentIds = AssetChildCountService.getAffectedParentIds(Trigger.new, null, false);
            if (!parentIds.isEmpty()) {
                AssetChildCountService.updateParentChildCounts(parentIds);
            }
        }
        
    } finally {
        AssetTriggerHandler.isExecuting = false;
    }
}
