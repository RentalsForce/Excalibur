/**
 * Created by Razer on 7/13/2020.
 */

@IsTest
private class WebHooksTest {
    @TestSetup
    static void setup()
    {
        String questionnaireId = TestDataFactory.createQuestionnaire();
        String instructorId = TestDataFactory.createTestUser('Inspector');
        String userId = TestDataFactory.createTestUser('User');
        TestDataFactory.insertCustomSettings();
        TestDataFactory.insertQA();
        TestDataFactory.setAssessmentTarget(questionnaireId, instructorId, userId);
    }
    @IsTest
    static void testBehavior()
    {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.addHeader('httpMethod', 'POST');
        req.requestUri = '/services/apexrest/webhoks';

        Questionnaire_Task__c task = [SELECT Id FROM Questionnaire_Task__c LIMIT 1];
        Target_Result__c result = [SELECT Id FROM Target_Result__c LIMIT 1];

        WebHooks.Tracking tracking = new WebHooks.Tracking();
        tracking.salesforce_uuid = task.Id + '_' + result.Id;

        WebHooks.Invitee invitee = new WebHooks.Invitee();
        invitee.email = 'testEmail@gail.com';

        WebHooks.Event event = new WebHooks.Event();
        event.start_time = String.valueOf(System.now().time());

        WebHooks.Payload payload = new WebHooks.Payload();
        payload.event = event;
        payload.invitee = invitee;
        payload.tracking = tracking;

        WebHooks.CalendyInfo info = new WebHooks.CalendyInfo();
        info.payload = payload;

        String JsonMsg=JSON.serialize(info);
        req.requestBody = Blob.valueOf(JsonMsg);
        RestContext.request = req;
        RestContext.response= res;

        Test.startTest();
        WebHooks.doPost();
        Test.stopTest();
    }
}