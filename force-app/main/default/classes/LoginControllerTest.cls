/**
 * Created by Razer on 7/12/2020.
 */

@IsTest
private class LoginControllerTest {
    @TestSetup
    public static void setup()
    {
        TestDataFactory.createTestUser('Inspector');
        TestDataFactory.createTestUser('User');
    }

    @IsTest
    static void testBehavior()
    {
        Site_User__c instructor = [SELECT Id, Last_Token__c FROM Site_User__c WHERE RecordType.DeveloperName = 'Inspector' LIMIT 1];
        Site_User__c user = [SELECT Id, Last_Token__c FROM Site_User__c WHERE RecordType.DeveloperName = 'User' LIMIT 1];
        LoginController.setNewName('test', instructor.Last_Token__c);

        Map<String, String> params = new Map<String, String>{
                'login' => 'test',
                'password' => 'test'
        };

        LoginController.checkCredentials(params);

        params.put('login', 'Inspector');
        LoginController.checkCredentials(params);

        params.put('login', 'Inspector');
        params.put('password', 'Inspector');
        LoginController.checkCredentials(params);

        LoginController.getUserByToken(user.Last_Token__c);
        LoginController.logOut(instructor.Last_Token__c);
        LoginController.checkToken('fake_1');
        LoginController.checkToken('fake_0');
        LoginController.checkToken(user.Last_Token__c);
        LoginController.prolongToken(user.Last_Token__c);

    }
}