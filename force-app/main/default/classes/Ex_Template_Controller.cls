public with sharing class Ex_Template_Controller {
    
    public String password {get; set;}
    
    public Ex_Login_History__c loginHistory {get; set;}
    
    public Ex_Template_Controller() {
        
        password = '';
    }
    
    public PageReference submitPassword()
    {
        if(password == 'Excalibur123')
        {     
            // captures session
            loginHistory = new Ex_Login_History__c();
            loginHistory.Source_IP__c = ApexPages.currentPage().getHeaders().get('X-Salesforce-SIP');
            loginHistory.Session_Expiration__c = DateTime.Now().addHours(1);
            insert loginHistory;
            
            // redirects
            PageReference fwPage = new PageReference('/');
            return fwPage.setRedirect(true);
        }
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, 'Password is incorrect!'));
        return null;
    }
    
    public PageReference checkUserSession() {
        if (isSessionOut()) {
            PageReference fwPage = new PageReference('/password');
            return fwPage.setRedirect(true);
        }
        return null;
    }
    
    public PageReference redirectToHomePage() {
        if (!isSessionOut()) {
            PageReference fwPage = new PageReference('/');
            return fwPage.setRedirect(true);
        }
        return null;
    }
    
    public Boolean isSessionOut() {

        String sourceIp = ApexPages.currentPage().getHeaders().get('X-Salesforce-SIP');
        DateTime dt =  DateTime.now();

        List<Ex_Login_History__c> loginHis = [SELECT Id FROM Ex_Login_History__c WHERE Source_IP__c = :sourceIp AND Session_Expiration__c > :dt ORDER BY CreatedDate DESC];
                                
        if (loginHis.size() == 0) return true;

        return false;
    }
}