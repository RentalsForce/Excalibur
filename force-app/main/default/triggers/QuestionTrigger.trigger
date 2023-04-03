/**
 * Created by Razer on 29.01.2020.
 */

trigger QuestionTrigger on Question__c (before insert, before update)
{

    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate))
    {
//        QuestionTriggerHandler.handleOrders(Trigger.new);
    }

}