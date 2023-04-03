/**
 * Created by Razer on 7/12/2020.
 */

@IsTest
private class InstructorControllerTest {
    @TestSetup
    static void testSetup()
    {
        String questionnaireId = TestDataFactory.createQuestionnaire();
        String userId = TestDataFactory.createTestUser('Inspector');
        TestDataFactory.setAssessmentTarget(questionnaireId, userId, null);
    }
    @IsTest
    static void testBehavior()
    {
        Site_User__c testUser = [SELECT Id, Last_Token__c FROM Site_User__c WHERE RecordType.DeveloperName = 'Inspector'];

        InstructorController.getAssessmentTargets(testUser.Last_Token__c);

        Answer__c testAnswer =[SELECT Id, Have_Note__c, Have_Photo__c, Question__c, Answer__c, Target_Result__r.Questionnaire__c,
                Target_Result__r.Assessment_Target__c, Target_Result__c, Question__r.Questionnaire__c,
                Recommendation__c, Question__r.Question__c FROM Answer__c LIMIT 1];

        InstructorController.Answer newAnswer = new InstructorController.Answer(testAnswer);
        InstructorController.AnswerFile newFile = new InstructorController.AnswerFile();
        newFile.base64body = 'testbody,testBody';
        newFile.fileName = 'testFle';
        newFile.image = true;

        InstructorController.setAnswer(JSON.serialize(new List<InstructorController.Answer>{newAnswer}), JSON.serialize(newFile), null);

        Custom_Doc_Link__c link = new Custom_Doc_Link__c(
                Answer__c = testAnswer.Id
        );

        insert link;

        newAnswer.haveNote = true;
        newAnswer.note = 'testNote';
        newAnswer.haveImage = true;
        newAnswer.imageString = 'test,test';

        InstructorController.changeAnswer(JSON.serialize(newAnswer));

        InstructorController.getAnswerImage(testAnswer.Id);

        Target_Result__c result = [SELECT Id FROM Target_Result__c lIMIT 1];

        Map<String, String> params = new Map<String, String>{
                'resultId' => result.Id,
                'token' => testUser.Last_Token__c
        };

        InstructorController.submitAssessment(params);

        Question__c testQuestion = [SELECT Id FROM Question__c WHERE Name = 'test1' LIMIT 1];

        InstructorController.findNotes(testQuestion.Id);

        params.put('questionOrder', '0');
        InstructorController.wipeFromAnswer(params);

        InstructorController.wipeTargetResult(params);
    }
}