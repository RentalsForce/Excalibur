@isTest
private class Ex_UrlRewriter_Test {
    
    static testMethod void testURLrewriter() { 
        pageReference myPage = new pageReference('/password');
        Test.setCurrentPage(myPage);
        myPage.setRedirect(true);
        
        List<PageReference> res = new List<PageReference>();
        res.add(myPage);
        res.add(new pageReference('/blog'));
        
        Ex_UrlRewriter urlClass = new Ex_UrlRewriter();
        urlClass.mapRequestUrl(myPage);
        urlClass.generateUrlFor(res);
    }
    
    static testMethod void test_mapRequestUrl_UseCase1(){
        PageReference pageRef = Page.Ex_PasswordHomePage;
        Test.setCurrentPage(pageRef);

        Ex_UrlRewriter obj = new Ex_UrlRewriter();
        
        obj.mapRequestUrl(new PageReference('/password'));
    }
    
    static testMethod void test_mapRequestUrl_UseCase2(){
        PageReference pageRef = Page.Ex_Blog;
        Test.setCurrentPage(pageRef);

        Ex_UrlRewriter obj = new Ex_UrlRewriter();
        
        obj.mapRequestUrl(new PageReference('/blog'));
    }
}