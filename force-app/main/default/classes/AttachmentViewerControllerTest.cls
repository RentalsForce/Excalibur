/**
 * Created by Razer on 7/12/2020.
 */

@IsTest
private class AttachmentViewerControllerTest {
    @IsTest
    static void testBehavior()
    {
        ContentVersion testVersion = new ContentVersion(
                Title = 'Test',
                PathOnClient = 'SomeUrlTest',
                VersionData = Blob.valueOf('testdata')
        );
        insert testVersion;

        AttachmentViewerController.getAttachment(testVersion.Id);
    }
}