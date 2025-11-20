@isTest
private class AssetChildCountServiceTest {
    
    @testSetup
    static void setup() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create parent asset
        Asset parent = new Asset(
            Name = 'Test Parent Asset',
            SerialNumber = 'PARENT001234',
            Status = 'Purchased',
            AccountId = testAccount.Id
        );
        insert parent;
        
        // Create child assets
        List<Asset> children = new List<Asset>();
        for (Integer i = 1; i <= 3; i++) {
            children.add(new Asset(
                Name = 'Test Child Asset ' + i,
                SerialNumber = 'CHILD00' + i + '5678',
                ParentId = parent.Id,
                Status = 'Purchased',
                AccountId = testAccount.Id
            ));
        }
        insert children;
    }
    
    @isTest
    static void testChildCountOnInsert() {
        Asset parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE ParentId = null LIMIT 1];
        
        // Verify count is 3
        System.assertEquals(3, parent.Child_Assets_Count__c, 'Parent should have 3 children');
    }
    
    @isTest
    static void testChildCountOnDelete() {
        Asset parent = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Asset childToDelete = [SELECT Id FROM Asset WHERE ParentId = :parent.Id LIMIT 1];
        
        Test.startTest();
        delete childToDelete;
        Test.stopTest();
        
        parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent.Id];
        System.assertEquals(2, parent.Child_Assets_Count__c, 'Parent should have 2 children after delete');
    }
    
    @isTest
    static void testChildCountOnStatusChange() {
        Asset parent = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Asset childToRetire = [SELECT Id, Status FROM Asset WHERE ParentId = :parent.Id LIMIT 1];
        
        Test.startTest();
        childToRetire.Status = 'Retired';
        update childToRetire;
        Test.stopTest();
        
        parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent.Id];
        System.assertEquals(2, parent.Child_Assets_Count__c, 'Parent should have 2 active children (excluding retired)');
    }
    
    @isTest
    static void testChildCountOnParentChange() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Create second parent
        Asset parent2 = new Asset(
            Name = 'Test Parent Asset 2',
            SerialNumber = 'PARENT002345',
            Status = 'Purchased',
            AccountId = testAccount.Id
        );
        insert parent2;
        
        Asset parent1 = [SELECT Id FROM Asset WHERE ParentId = null AND Name = 'Test Parent Asset' LIMIT 1];
        Asset childToMove = [SELECT Id, ParentId FROM Asset WHERE ParentId = :parent1.Id LIMIT 1];
        
        Test.startTest();
        childToMove.ParentId = parent2.Id;
        update childToMove;
        Test.stopTest();
        
        parent1 = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent1.Id];
        parent2 = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent2.Id];
        
        System.assertEquals(2, parent1.Child_Assets_Count__c, 'Parent 1 should have 2 children');
        System.assertEquals(1, parent2.Child_Assets_Count__c, 'Parent 2 should have 1 child');
    }
    
    @isTest
    static void testHasChildAssetsFormula() {
        Asset parent = [SELECT Id, Has_Child_Assets__c FROM Asset WHERE ParentId = null LIMIT 1];
        Asset child = [SELECT Id, Has_Child_Assets__c FROM Asset WHERE ParentId != null LIMIT 1];
        
        System.assertEquals(true, parent.Has_Child_Assets__c, 'Parent should have Has_Child_Assets__c = true');
        System.assertEquals(false, child.Has_Child_Assets__c, 'Child should have Has_Child_Assets__c = false');
    }
    
    @isTest
    static void testHierarchyIndicatorFormula() {
        Asset parent = [SELECT Id, Hierarchy_Indicator__c FROM Asset WHERE ParentId = null LIMIT 1];
        Asset child = [SELECT Id, Hierarchy_Indicator__c, Parent.Name FROM Asset WHERE ParentId != null LIMIT 1];
        
        System.assert(parent.Hierarchy_Indicator__c.contains('Parent'), 'Parent indicator should contain "Parent"');
        System.assert(parent.Hierarchy_Indicator__c.contains('3'), 'Parent indicator should show 3 children');
        System.assert(child.Hierarchy_Indicator__c.contains('Child of'), 'Child indicator should contain "Child of"');
    }
    
    @isTest
    static void testRecalculateAllCounts() {
        // Manually set wrong count
        Asset parent = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        parent.Child_Assets_Count__c = 999;
        update parent;
        
        Test.startTest();
        AssetChildCountService.recalculateAllCounts();
        Test.stopTest();
        
        parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent.Id];
        System.assertEquals(3, parent.Child_Assets_Count__c, 'Count should be recalculated to 3');
    }
    
    @isTest
    static void testUndeleteChild() {
        Asset parent = [SELECT Id FROM Asset WHERE ParentId = null LIMIT 1];
        Asset childToUndelete = [SELECT Id FROM Asset WHERE ParentId = :parent.Id LIMIT 1];
        
        delete childToUndelete;
        
        parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent.Id];
        System.assertEquals(2, parent.Child_Assets_Count__c, 'Parent should have 2 children after delete');
        
        Test.startTest();
        undelete childToUndelete;
        Test.stopTest();
        
        parent = [SELECT Id, Child_Assets_Count__c FROM Asset WHERE Id = :parent.Id];
        System.assertEquals(3, parent.Child_Assets_Count__c, 'Parent should have 3 children after undelete');
    }
}
