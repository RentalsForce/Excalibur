/**
 * Created by Razer on 29.01.2020.
 */

public with sharing class QuestionTriggerHandler {

    public static void handleOrders(List<Question__c> newRecords)
    {
        Map<String, List<Question__c>> branchQuestionMap = new Map<String, List<Question__c>>();
        Set<String> questionsIds = new Set<String>();

        for (Question__c question : newRecords)
        {
            if (branchQuestionMap.containsKey(question.Branch__c))
            {
                branchQuestionMap.get(question.Branch__c).add(question);
            } else {
                branchQuestionMap.put(question.Branch__c, new List<Question__c>{question});
            }

            if (question.Id != null)
            {
                questionsIds.add(question.Id);
            }
        }

        List<Branch__c> branches = [
                SELECT Id, (SELECT Id, Order__c FROM Questions__r WHERE Id NOT IN : questionsIds)
                FROM Branch__c
                WHERE Id IN : branchQuestionMap.keySet()
        ];

        for (Branch__c branch : branches)
        {
            Map<Decimal, Question__c> orderQuestionMap = new Map<Decimal, Question__c>();
            for (Question__c question : branchQuestionMap.get(branch.Id))
            {
                if (orderQuestionMap.containsKey(question.Order__c))
                {
                    question.addError('You trying to insert questions with repeating orders');
                } else {
                    orderQuestionMap.put(question.Order__c, question);
                }
            }


            for (Question__c question : branch.Questions__r)
            {
                if (orderQuestionMap.containsKey(question.Order__c))
                {
                    orderQuestionMap.get(question.Order__c).addError('You already have this Question Order inside current Branch.');
                }
            }
        }
    }

}