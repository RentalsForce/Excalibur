/**
 * Created by Razer on 05.03.2020.
 */

trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert)
{
    ContentVersion version = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :Trigger.new[0].ContentDocumentId];

//    ContentDistribution cd = new ContentDistribution(
//            Name = 'inspector image',
//            ContentVersionId = version.Id,
//            PreferencesAllowViewInBrowser = true,
//            PreferencesAllowOriginalDownload = true,
//            PreferencesAllowPDFDownload = false
//    );
//
//    insert cd;

}