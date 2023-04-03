/**
 * Created by Artsiom.Klimanski on 12/17/2019.
 */

public with sharing class AssessmentTargetHandler
{
    public static void createQuestionnaires(List<Assessment_Target__c> targets)
    {
        List<Questionnaire__c> libs = [
                SELECT Id FROM Questionnaire__c
        ];
        List<Target_Result__c> results = new List<Target_Result__c>();

        for (Assessment_Target__c target : targets)
        {
            for (Questionnaire__c questionnaire : libs)
            {
                Target_Result__c result = new Target_Result__c(
                        Assessment_Target__c = target.Id,
                        Questionnaire__c = questionnaire.Id,
                        Is_Completed__c = false,
                        Is_Started__c = false,
                        Created_Date__c = Date.today()
                );

                results.add(result);
            }
        }

        if (!results.isEmpty())
        {
            insert results;
        }
    }

}