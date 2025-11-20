/**
 * Utility class for namespace-aware field and object name resolution
 * Ensures managed package compatibility
 */
public with sharing class NamespaceUtil {
    
    private static String cachedNamespace;
    private static Boolean namespaceChecked = false;
    
    /**
     * Get the current namespace prefix (if any)
     * @return String - namespace prefix with trailing __ or empty string
     */
    public static String getNamespacePrefix() {
        if (!namespaceChecked) {
            // Check if we're in a namespaced org
            String className = NamespaceUtil.class.getName();
            if (className.contains('.')) {
                cachedNamespace = className.substringBefore('.') + '__';
            } else {
                cachedNamespace = '';
            }
            namespaceChecked = true;
        }
        return cachedNamespace;
    }
    
    /**
     * Get namespace-aware field API name
     * @param fieldName - field name without namespace (e.g., 'Criticality__c')
     * @return String - field name with namespace if applicable
     */
    public static String getFieldName(String fieldName) {
        if (String.isBlank(fieldName)) {
            return fieldName;
        }
        
        // If field already has namespace or is standard field, return as-is
        if (fieldName.contains('__') && !fieldName.endsWith('__c')) {
            return fieldName;
        }
        
        // For custom fields, prepend namespace if exists
        if (fieldName.endsWith('__c') || fieldName.endsWith('__r')) {
            String prefix = getNamespacePrefix();
            if (String.isNotBlank(prefix) && !fieldName.startsWith(prefix)) {
                return prefix + fieldName;
            }
        }
        
        return fieldName;
    }
    
    /**
     * Get namespace-aware field API name using Schema describe
     * This is the most reliable method for managed packages
     * Throws exception if field does not exist to prevent SOQL injection
     */
    public static String getAssetFieldName(String fieldName) {
        if (String.isBlank(fieldName)) {
            throw new AuraHandledException('Invalid Field: Field name cannot be blank');
        }
        
        try {
            Schema.SObjectType assetType = Schema.getGlobalDescribe().get('Asset');
            if (assetType == null) {
                throw new AuraHandledException('Invalid Object: Asset object not found');
            }
            
            Map<String, Schema.SObjectField> fieldMap = assetType.getDescribe().fields.getMap();
            
            // Try with namespace prefix first
            String namespacedField = getFieldName(fieldName);
            if (fieldMap.containsKey(namespacedField)) {
                return namespacedField;
            }
            
            // Try without namespace (for standard fields or already namespaced)
            if (fieldMap.containsKey(fieldName)) {
                return fieldName;
            }
            
            // Try lowercase (field map keys are case-insensitive but let's be explicit)
            String lowerFieldName = fieldName.toLowerCase();
            if (fieldMap.containsKey(lowerFieldName)) {
                return lowerFieldName;
            }
            
            // Field not found - throw exception to prevent injection
            throw new AuraHandledException('Invalid Field: ' + fieldName + ' does not exist on Asset object');
            
        } catch (AuraHandledException e) {
            // Re-throw AuraHandledException as-is
            throw e;
        } catch (Exception e) {
            // Wrap other exceptions
            throw new AuraHandledException('Error validating field ' + fieldName + ': ' + e.getMessage());
        }
    }
}
