/**
 * Created by Мастер Эш on 12.12.2019.
 */

public without sharing class LoginController {

    private static final Integer SESSION_MINUTES = 15;

    @AuraEnabled
    public static Object setNewName(String name, String token)
    {
        List<Site_User__c> user = [
                SELECT Id, Password__c, Login__c, RecordType.Name, Name
                FROM Site_User__c
                WHERE Last_Token__c = :token
        ];

        try
        {
            user[0].Name = name;
            update user[0];

            return new Map<String, Object>{
                    'success' => true
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'success' => false,
                    'message' => 'error: ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Object sendPasswordEmail(String email)
    {
        List<Site_User__c> user = [SELECT Id, Login__c, Email__c FROM Site_User__c WHERE Email__c = :email];
        Map<String, Object> result;
        if (!user.isEmpty() && user[0].Email__c != null)
        {
            String newPassword = LoginController.createToken();
            user[0].Password__c = newPassword;
            update user[0];

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.toAddresses = new List<String>{email};
            message.subject = 'Change Password';
            message.htmlBody =
                    '<p>Username: ' + user[0].Login__c + '</p>' +
                    '<p>New Password: ' + user[0].Password__c + '</p>';
            Messaging.SingleEmailMessage[] messages =   new List<Messaging.SingleEmailMessage> {message};
            Messaging.sendEmail(messages);
            result = new Map<String, Object>{'success' => true};
        } else {
            result = new Map<String, Object>{'success' => false};
        }

        return result;
    }

    @AuraEnabled
    public static Object checkCredentials(Map<String, String> credentials)
    {
        String login = credentials.get('login');
        String password = credentials.get('password');
        String remember = String.isEmpty(credentials.get('remember')) ? '_0' : '_' + credentials.get('remember');

        List<Site_User__c> user = [
                SELECT Id, Password__c, Login__c, RecordType.Name, Name
                FROM Site_User__c
                WHERE Login__c = :login
        ];


        if (user.isEmpty())
        {
            return new Map<String, Object>{
                    'failed' => true,
                    'message' => 'Invalid Login',
                    'json' => JSON.serialize(user)
            };
        }

        if (user[0].Password__c == password)
        {
            user[0].Token_Start__c = Datetime.now();
            user[0].Last_Token__c = createToken() + remember;

            update user[0];
            return new Map<String, Object>{
                    'failed' => false,
                    'type' => user[0].RecordType.Name,
                    'userName' => user[0].Name,
                    'message' => '',
                    'token' => user[0].Last_Token__c
            };
        } else {
            return new Map<String, Object>{
                    'failed' => true,
                    'message' => 'Invalid Password',
                    'json' => JSON.serialize(credentials)
            };
        }
    }

    @AuraEnabled
    public static void  logOut(String token)
    {
        List<Site_User__c> user = [
                SELECT Id FROM Site_User__c WHERE Last_Token__c = :token
        ];

        if (!user.isEmpty())
        {
            user[0].Last_Token__c = null;
            update user[0];
        }
    }

    @AuraEnabled
    public static Object checkToken(String token)
    {
        String tokenParam = token.substringBefore('_');
        String remember = token.substringAfter('_');
        if (tokenParam == null)
        {
            return new Map<String, Object>{
                    'expired' => true,
                    'params' => tokenParam + '---' + remember
            };
        }

        List<Site_User__c> user = [
                SELECT Id, Token_Start__c, Last_Token__c, RecordType.Name, Name
                FROM Site_User__c
                WHERE Last_Token__c = :token
        ];

        if (user.isEmpty())
        {
            return new Map<String, Object>{
                    'expired' => true,
                    'params' => 'emptyUsers'
            };
        } else {
            Datetime expiredTime = user[0].Token_Start__c.addMinutes(SESSION_MINUTES);

            if (System.now() > expiredTime && remember != '1')
            {
                return new Map<String, Object>{
                        'expired' => true
                };
            } else {
                user[0].Last_Token__c = createToken() + '_1';
                user[0].Token_Start__c = Datetime.now();
                update user[0];

                return new Map<String, Object>{
                        'expired' => false,
                        'type' => user[0].RecordType.Name,
                        'userName' => user[0].Name,
                        'newToken' => user[0].Last_Token__c
                };
            }
        }
    }

    @AuraEnabled
    public static void prolongToken(String token)
    {
        List<Site_User__c> user = [SELECT Id FROM Site_User__c WHERE Last_Token__c = :token];
        if (!user.isEmpty())
        {
            user[0].Token_Start__c = Datetime.now();
            update user[0];
        }
    }

    public static String createToken() {
        String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        String randStr = '';
        while (randStr.length() < 25) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr;
    }

    public static Site_User__c getUserByToken(String token)
    {
        List<Site_User__c> user = [
                SELECT Id
                FROM Site_User__c
                WHERE Last_Token__c = :token
        ];

        if (user.isEmpty())
        {
            return null;
        } else {
            return user[0];
        }
    }

}