/**
 * Created by Razer on 7/12/2020.
 */

@IsTest
private class TargetReportControllerTest {
    @TestSetup
    public static void setup()
    {
        String questionnaireId = TestDataFactory.createQuestionnaire();
        String userId = TestDataFactory.createTestUser('Inspector');
        TestDataFactory.setAssessmentTarget(questionnaireId, userId, null);
        TestDataFactory.insertCustomSettings();
    }

    @IsTest
    static void testBehavior()
    {
        Assessment_Target__c target = [SELECT Id FROM Assessment_Target__c LIMIT 1];
        Target_Result__c result = [SELECT Id FROM Target_Result__c LIMIT 1];
        List<Question__c> questions = [SELECT Id FROM Question__c];
        List<Answer__c> answers = new List<Answer__c>();

        for (Question__c question : questions)
        {
            Answer__c answer = new Answer__c(
                    Question__c = question.Id,
                    Target_Result__c = result.Id,
                    Answer__c = 'No'
            );
            answers.add(answer);
        }

        answers[0].Answer__c = 'Yes';
        insert answers;

        Questionnaire__c lib = [SELECT Id FROM Questionnaire__c LIMIT 1];
        Test.setCurrentPage(Page.TargetReport);
        ApexPages.currentPage().getParameters().put('targetId', target.Id);
        ApexPages.currentPage().getParameters().put('libId', lib.Id);

        TargetReportController controller = new TargetReportController();
    }
}