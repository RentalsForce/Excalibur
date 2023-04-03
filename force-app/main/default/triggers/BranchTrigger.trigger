/**
 * Created by Razer on 29.01.2020.
 */

trigger BranchTrigger on Branch__c (before insert, before update) {

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate))
    {
        BranchTriggerHandler.handleOrders(Trigger.new);
    }

}