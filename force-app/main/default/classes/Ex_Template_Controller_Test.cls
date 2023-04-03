@isTest
public class Ex_Template_Controller_Test
{
    @testSetup static void dataSetup() {
        DELETE [SELECT Id FROM Ex_Login_History__c];
        
        // Login History
        DateTime dt =  DateTime.now(); 
        Ex_Login_History__c login = new Ex_Login_History__c(Source_IP__c = '192.68.1.1', Session_Expiration__c = dt.addHours(1));
        insert login;
    }
    
    @isTest
    static void itShould()
    {
        PageReference pageRef = Page.Ex_PasswordHomePage;
        Test.setCurrentPage(pageRef);
        
        Ex_Template_Controller ctr = new Ex_Template_Controller();
        
        ctr.checkUserSession();
        ctr.redirectToHomePage();
        
        if(ctr.isSessionOut())
        {
            ctr.password = 'Excalibur123';
            ctr.submitPassword();
        }
    }
    
    @isTest
    static void passwordIncorrect()
    {
        PageReference pageRef = Page.Ex_PasswordHomePage;
        Test.setCurrentPage(pageRef);
        
        Ex_Template_Controller ctr = new Ex_Template_Controller();
        
        ctr.checkUserSession();
        ctr.redirectToHomePage();
        
        if(ctr.isSessionOut())
        {
            ctr.password = 'wrongPassword';
            ctr.submitPassword();
        }
    }
}