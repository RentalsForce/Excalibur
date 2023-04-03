/**
 * Created by Artsiom.Klimanski on 12/17/2019.
 */

trigger AssessmentTargetTrigger on Assessment_Target__c (after insert)
{
    if (Trigger.isAfter && Trigger.isInsert)
    {
//        AssessmentTargetHandler.createQuestionnaires(Trigger.new);
    }

}