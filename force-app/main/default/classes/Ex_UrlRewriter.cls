global with sharing class Ex_UrlRewriter implements Site.UrlRewriter {
    
    // Variables to represent the user-friendly URLs
    String PASSWORD_HOME_PAGE = '/password';
    String BLOG_PAGE = '/blog';
    
    
    //Variables to represent my custom Visualforce pages
    String PASSWORD_HOME_VF_PAGE = '/Ex_PasswordHomePage';
    String BLOG_VF_PAGE = '/Ex_Blog';
    
    
    global PageReference mapRequestUrl(PageReference myFriendlyUrl) {
        String url = myFriendlyUrl.getUrl();
        
        if(url == PASSWORD_HOME_PAGE || url == '/password?sfdcIFrameOrigin=null') {
            return new PageReference(PASSWORD_HOME_VF_PAGE);
        }
        if(url == BLOG_PAGE || url == '/blog?sfdcIFrameOrigin=null') {
            return new PageReference(BLOG_VF_PAGE);
        }
        
        return null;
    }
    
    global List<PageReference> generateUrlFor(List<PageReference> mySalesforceUrls) {
        //A list of pages to return after all the links have been evaluated
        List<PageReference> myFriendlyUrls = new List<PageReference>();
        
        // loop through all the urls once, finding all the valid ids
        for(PageReference mySalesforceUrl : mySalesforceUrls) {
            //Get the URL of the page
            String url = mySalesforceUrl.getUrl();
            
            if(url == PASSWORD_HOME_VF_PAGE) {
                myFriendlyUrls.add(new PageReference(PASSWORD_HOME_PAGE));
            }
            else if(url == BLOG_VF_PAGE) {
                myFriendlyUrls.add(new PageReference(BLOG_PAGE));
            }
        }
        
        //Return the full list of pages
        return myFriendlyUrls;
    }
}