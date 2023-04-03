/**
 * Created by Razer on 7/13/2020.
 */

@IsTest
public class UserControllerTest
{
    @TestSetup
    static void testSetup()
    {
        String questionnaireId = TestDataFactory.createQuestionnaire();
        String instructorId = TestDataFactory.createTestUser('Inspector');
        String userId = TestDataFactory.createTestUser('User');
        TestDataFactory.insertCustomSettings();
        TestDataFactory.insertQA();
        TestDataFactory.setAssessmentTarget(questionnaireId, instructorId, userId);
    }

    @IsTest
    static void testBehaviour()
    {
        Site_User__c testUser = [SELECT Id, Last_Token__c FROM Site_User__c WHERE RecordType.DeveloperName = 'User' LIMIT 1];

        UserController.getTargetResults(testUser.Last_Token__c);
        UserController.getQuestions();

        List<UserController.TargetTask> testTasks = (List<UserController.TargetTask>)UserController.getTasksInfo(testUser.Last_Token__c);

        UserController.uploadTaskPhoto(JSON.serialize(testTasks[0].tasks[0]));

        testTasks[0].tasks[0].currentPhotoString = 'test,test';
        
        UserController.uploadTaskPhoto(JSON.serialize(testTasks[0].tasks[0]));

        System.debug(testTasks);

    }
}