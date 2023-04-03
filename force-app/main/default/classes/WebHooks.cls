/**
 * Created by Razer on 28.01.2020.
 */
@RestResource(urlMapping='/webhoks')
global with sharing class WebHooks {


    @HttpPost
    global static String doPost()
    {
        String requestBody = RestContext.request.requestBody.toString();
        CalendyInfo newInfo = (CalendyInfo)JSON.deserialize(requestBody, CalendyInfo.class);
        try {
            insert new Completed_Task__c(
                    Questionnaire_Task__c = newInfo.payload.tracking.salesforce_uuid.substringBefore('_'),
                    Target_Result__c = newInfo.payload.tracking.salesforce_uuid.substringAfter('_'),
                    Meeting_Scheduled__c = true,
                    Meeting_Time__c = newInfo.payload.event.start_time
            );

        } catch (Exception e)
        {
            System.debug(e);
        }
        insert new Log__c(JSON_Data__c = requestBody);
        return '';
    }

    public class CalendyInfo
    {
        public Payload payload;

    }

    public class Payload
    {
        public Event event;
        public Invitee invitee;
        public Tracking tracking;
    }

    public class Event
    {
        public String start_time;
    }

    public class Invitee
    {
        public String email;
    }

    public class Tracking
    {
        public String salesforce_uuid;
    }

}