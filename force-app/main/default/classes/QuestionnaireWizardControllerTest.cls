/**
 * Created by Razer on 7/12/2020.
 */

@IsTest
public with sharing class QuestionnaireWizardControllerTest
{
    @TestSetup
    public static void setup()
    {
        String questionnaireId = TestDataFactory.createQuestionnaire();
        String userId = TestDataFactory.createTestUser('Inspector');
        TestDataFactory.setAssessmentTarget(questionnaireId, userId, null);
    }

    @IsTest
    public static void superTest()
    {
        List<QuestionnarieWizardController.Questionnaire> libs = QuestionnarieWizardController.getQuestionnaires();

        QuestionnarieWizardController.saveQuestion(JSON.serialize(libs[0].allQuestions[0]));

        QuestionnarieWizardController.saveQuestionnaire(JSON.serialize(libs[0]));

        libs[0].libId = 'new';

        QuestionnarieWizardController.saveQuestionnaire(JSON.serialize(libs[0]));

        libs = QuestionnarieWizardController.getQuestionnaires();

        Assessment_Target__c target = [SELECT Id FROM Assessment_Target__c LIMIT 1];

        QuestionnarieWizardController.getExistingTargets(new List<String>{target.Id});

        Map<String, String> params = new Map<String, String>{
                'targetId' => target.Id,
                'libId' => libs[0].libId
        };

        QuestionnarieWizardController.newAssessmentTarget(params);

        params = new Map<String, String>{
                'targetId' => target.Id,
                'libId' => libs[0].libId,
                'type' => 'Schedule a Meeting',
                'title' => 'test',
                'description' => 'test'
        };

        QuestionnarieWizardController.createTask(params);

        Question__c question = [SELECT Id FROM Question__c WHERE Name = 'test2'];

        String result = QuestionnarieWizardController.deleteQuestion(question.Id);

        System.debug(result);

        Questionnaire_Task__c task = [SELECT Id FROM Questionnaire_Task__c LIMIT 1];
        QuestionnarieWizardController.deleteTask(task.Id);

        QuestionnarieWizardController.deleteTarget(params);

        Custom_Note__c note = [SELECT Id FROM Custom_Note__c LIMIT 1];

        QuestionnarieWizardController.deleteCustomNote(note.Id);

        QuestionnarieWizardController.deleteQuestionnaire(libs[0].libId);
    }
}