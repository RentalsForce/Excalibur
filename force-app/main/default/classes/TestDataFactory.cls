/**
 * Created by Razer on 7/12/2020.
 */

public with sharing class TestDataFactory
{
    public static void insertQA()
    {
        Q_A_Type__c testType = new Q_A_Type__c(
                Name = 'test'
        );

        insert testType;

        Q_A_Item__c testItem = new Q_A_Item__c(
                Name = 'testItem',
                Question__c = 'testQuestion',
                Answer__c = 'testAnswer',
                Q_A_Type__c = testType.Id
        );

        insert testItem;
    }
    public static String createTestUser(String recordTypeDevName)
    {
        System.debug([SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'Site_User__c' AND DeveloperName = :recordTypeDevName]);
        RecordType recType = [SELECT Id FROM RecordType WHERE SobjectType = 'Site_User__c' AND DeveloperName = :recordTypeDevName LIMIT 1];

        Site_User__c testUser = new Site_User__c(
                Password__c = recordTypeDevName,
                Login__c = recordTypeDevName,
                RecordTypeId = recType.Id,
                Token_Start__c = System.now(),
                Last_Token__c = LoginController.createToken(),
                Email__c = recordTypeDevName + '@gmail.com'
        );

        insert testUser;

        return testUser.Id;
    }
    public static String setAssessmentTarget(String questionnaireId, String instructorId, String userId)
    {
        Assessment_Target__c newTarget = new Assessment_Target__c(
                Name = 'testTarget',
                Inspector__c = instructorId,
                Main_User__c = userId
        );
        insert newTarget;

        Target_Result__c result = new Target_Result__c(
                Assessment_Target__c = newTarget.Id,
                Questionnaire__c = questionnaireId,
                Completed_Date__c = System.now().date(),
                Is_Completed__c = true
        );
        insert result;

        Questionnaire__c testQuestionnaire = [SELECT Id, (SELECT Id FROM Questions__r LIMIT 2) FROM Questionnaire__c WHERE Id = :questionnaireId];

        Answer__c testAnswer1 = new Answer__c(
                Question__c = testQuestionnaire.Questions__r[0].Id,
                Target_Result__c = result.Id,
                Answer__c = 'Yes'
        );
        insert testAnswer1;

        Answer__c testAnswer2 = new Answer__c(
                Question__c = testQuestionnaire.Questions__r[1].Id,
                Target_Result__c = result.Id,
                Answer__c = 'No'
        );
        insert testAnswer2;

        return newTarget.Id;
    }

    public static String createQuestionnaire()
    {
        Questionnaire__c questionnaire = new Questionnaire__c(
                Name = 'ADA (Website)'

        );

        insert questionnaire;

        Questionnaire_Task__c testTask = new Questionnaire_Task__c(
                Task_Title__c = 'test',
                Task_Type__c = 'Upload Photo',
                Task_Description__c = 'Test Description',
                Questionnaire__c = questionnaire.Id
        );

        insert testTask;

        Branch__c branch = new Branch__c(
                Questionnaire__c = questionnaire.Id,
                Branch_Order__c = 1,
                Skip_Next_Questions_On__c = 'No'
        );

        insert branch;

        Question__c testQuestion1 = new Question__c(
                Branch__c = branch.Id,
                Name = 'test1',
                Order__c = 1,
                Threat_Points__c = 15,
                Yes_Issue__c = 'true',
                Questionnaire__c = questionnaire.Id,
                No_Additions__c = 'Attachment',
                Question__c = 'Test question1'
        );

        insert testQuestion1;

        Question__c testQuestion2 = new Question__c(
                Branch__c = branch.Id,
                Name = 'test2',
                No_Additions__c = 'Issue;Attachment',
                Yes_Additions__c = 'Issue;Attachment',
                No_Issue__c = 'true',
                Order__c = 2,
                Threat_Points__c = 15,
                Questionnaire__c = questionnaire.Id,
                Question__c = 'Test question2'
        );

        insert testQuestion2;

        Custom_Note__c note = new Custom_Note__c(
                Note_Body__c = 'testBody',
                Note_Title__c = 'Test title',
                Question__c = testQuestion1.Id
        );

        insert note;

        ContentVersion version = new ContentVersion(
                VersionData = Blob.valueOf('test,test'),
                Description = 'note-',
                Title = 'test',
                PathOnClient = 'data:image/png;base64'
        );
        insert version;

        Custom_Doc_Link__c link = new Custom_Doc_Link__c(
                Custom_Note__c = note.Id,
                Content_Version_Id__c = version.Id
        );
        insert link;


//        testQuestion1.No_Skip_To_Question__c = testQuestion1.Id;
//        update testQuestion1;

        Fix_Price__c testPrice = new Fix_Price__c(
                Price_Text__c = 'Test text',
                Question__c = testQuestion1.Id
        );

        insert testPrice;

        return questionnaire.Id;
    }

    public static void insertCustomSettings()
    {
        Diagram_Values__c newValues = new Diagram_Values__c(
                Green__c = '0-10',
                Blue__c = '10-20',
                Orange__c = '20-30',
                Yellow__c = '30-40',
                Red__c = '40-100'
        );

        insert newValues;
    }
}