/**
 * Created by Razer on 29.01.2020.
 */

public with sharing class BranchTriggerHandler {

    public static void handleOrders(List<Branch__c> newRecords)
    {
        Map<String, List<Branch__c>> libBranchMap = new Map<String, List<Branch__c>>();
        Set<String> branchIds = new Set<String>();

        for (Branch__c branch : newRecords)
        {
            if (libBranchMap.containsKey(branch.Questionnaire__c))
            {
                libBranchMap.get(branch.Questionnaire__c).add(branch);
            } else {
                libBranchMap.put(branch.Questionnaire__c, new List<Branch__c>{branch});
            }

            if (branch.Id != null)
            {
                branchIds.add(branch.Id);
            }
        }

        List<Questionnaire__c> libs = [
            SELECT Id, (SELECT Id, Branch_Order__c FROM Branches__r WHERE Id NOT IN : branchIds)
            FROM Questionnaire__c
            WHERE Id IN : libBranchMap.keySet()
        ];

        for (Questionnaire__c lib : libs)
        {
            Map<Decimal, Branch__c> orderBranchMap = new Map<Decimal, Branch__c>();
            for (Branch__c branch : libBranchMap.get(lib.Id))
            {
                if (orderBranchMap.containsKey(branch.Branch_Order__c))
                {
                    branch.addError('You trying to insert branches with repeating orders');
                } else {
                    orderBranchMap.put(branch.Branch_Order__c, branch);
                }
            }


            for (Branch__c branch : lib.Branches__r)
            {
                if (orderBranchMap.containsKey(branch.Branch_Order__c))
                {
                    orderBranchMap.get(branch.Branch_Order__c).addError('You already have this Branch Order inside current Questionnaire.');
                }
            }
        }

    }

}