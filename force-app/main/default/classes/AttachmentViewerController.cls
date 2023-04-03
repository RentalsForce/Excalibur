/**
 * Created by Razer on 17.04.2020.
 */

public without sharing class AttachmentViewerController
{
    @RemoteAction
    public static Object getAttachment(String versionId)
    {
        ContentVersion version = [
                SELECT Id, PathOnClient, VersionData, Title
                FROM ContentVersion
                WHERE Id = :versionId
        ];

        return new SiteAttachment(version);
    }

    public class SiteAttachment
    {
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String link;
        @AuraEnabled
        public Boolean pdf;
        @AuraEnabled
        public String base64Attachment;
        @AuraEnabled
        public Blob data;
        @AuraEnabled
        public String versionId;

        public SiteAttachment(ContentVersion data) {
            this.versionId = data.Id;
            this.title = data.Title;
            this.pdf = data.PathOnClient.contains('pdf');
            this.link = 'https://excaliburusallc--c.visualforce.com/apex/attachmentviewer?version=' + data.Id;
            this.base64Attachment = data.PathOnClient + ',' + EncodingUtil.base64Encode(data.VersionData);
        }
    }
}