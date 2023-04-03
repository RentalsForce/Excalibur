/**
 * Created by Мастер Эш on 16.12.2019.
 */

public without sharing class InstructorController
{
    @AuraEnabled
    public static Object wipeFromAnswer(Map<String, String> params)
    {
        List<Answer__c> answers = [
                SELECT Id, Question__c,
                (SELECT Id FROM Custom_Doc_Links__r)
                FROM Answer__c
                WHERE Target_Result__c = :params.get('targetResult')
                AND Question__r.Order__c >= :Integer.valueOf(params.get('questionOrder'))
        ];

        List<Custom_Doc_Link__c> linksForDelete = new List<Custom_Doc_Link__c>();
        List<String> wipedQuestion = new List<String>();

        for (Answer__c answer : answers)
        {
            linksForDelete.addAll(answer.Custom_Doc_Links__r);
            wipedQuestion.add(answer.Question__c);
        }

        try
        {
            if (!linksForDelete.isEmpty())
            {
                delete linksForDelete;
            }

            delete answers;

            Target_Result__c result = [
                    SELECT Id,
                    (SELECT Id FROM Answers__r)
                    FROM Target_Result__c
                    WHERE Id = :params.get('targetResult')
            ];

            if (result.Answers__r.isEmpty())
            {
                result.Is_Started__c = false;
                result.Start_Date__c = null;
                update result;
            }

            return new Map<String, Object>{
                    'success' => true,
                    'wipedQuestions' => wipedQuestion
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
    public static Object wipeTargetResult(Map<String, String> params)
    {
        List<Target_Result__c> results = [
                SELECT Id,
                (SELECT Id FROM Answers__r)
                FROM Target_Result__c
                WHERE Id = :params.get('resultId')
        ];

        List<String> answerIds = new List<String>();
        List<SObject> updateList = new List<SObject>();
        List<SObject> deleteList = new List<SObject>();

        for (Target_Result__c result : results)
        {
            result.Completed_Date__c = null;
            result.Start_Date__c = null;
            result.Is_Completed__c = false;
            result.Is_Started__c = false;
            result.Is_Submitted__c = false;

            updateList.add(result);
            deleteList.addAll(result.Answers__r);

            for (Answer__c answer : result.Answers__r)
            {
                answerIds.add(answer.Id);
            }
        }

        List<Custom_Doc_Link__c> links = [SELECT Id FROM Custom_Doc_Link__c WHERE Answer__c IN : answerIds];
        deleteList.addAll(links);

        try
        {
            delete deleteList;
            update updateList;

            return new Map<String, Object> {
                    'success' => true,
                    'result' => getAssessmentTargets(params.get('token')),
                    'params' => params
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'success' => false,
                    'error' => 'error: ' + e.getMessage()
            };
        }
    }
    @AuraEnabled
    public static Object changeAnswer(String jsonAnswer)
    {
        try
        {
            Answer answer = (Answer)JSON.deserialize(jsonAnswer, Answer.class);
            Answer__c answerForUpdate;
            if (answer.haveNote)
            {
                answerForUpdate = new Answer__c(
                        Id = answer.answerId,
                        Recommendation__c = answer.note
                );
                update answerForUpdate;
            }
            if (answer.haveImage)
            {
                Custom_Doc_Link__c link = [
                        SELECT Id, Content_Version_Id__c
                        FROM Custom_Doc_Link__c
                        WHERE Answer__c = :answer.answerId
                ];

                ContentVersion version = new ContentVersion(
                        VersionData = EncodingUtil.base64Decode(answer.imageString.substring(answer.imageString.indexOf(',') + 1)),
                        Title = 'answerImage.png',
                        PathOnClient = 'data:image/png;base64'

                );
                insert version;

                link.Content_Version_Id__c = version.Id;
                update link;
            }

            return new Map<String, Object>{
                    'success' => true
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'success' => false,
                    'error' => 'error: ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Object getAnswerImage(String answerId)
    {
        try
        {
            Custom_Doc_Link__c link = [
                    SELECT Id, Content_Version_Id__c
                    FROM Custom_Doc_Link__c
                    WHERE Answer__c = :answerId
            ];
            ContentVersion version = [
                    SELECT Id, VersionData, Description
                    FROM ContentVersion
                    WHERE Id =: link.Content_Version_Id__c
            ];

            return new Map<String, Object>{
                    'success' => true,
                    'image' => 'data:image/png;base64,' + EncodingUtil.base64Encode(version.VersionData)
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'success' => false,
                    'error' => 'error: ' + e.getMessage()
            };
        }
    }

    @AuraEnabled(Cacheable=false)
    public static Object getAssessmentTargets(String token)
    {
        Site_User__c user = LoginController.getUserByToken(token);

        Map<Id, Assessment_Target__c> targets = new Map<Id, Assessment_Target__c>(
        [
                SELECT Id, Name,
                (SELECT Id, Questionnaire__c, Assessment_Target__c, ResultsJSON__c,
                        Is_Started__c, Is_Completed__c
                FROM Target_Results__r)
                FROM Assessment_Target__c
                WHERE Inspector__c = :user.Id
        ]);

        Map<String, List<Target_Result__c>> results = getAssessmentsResults(targets.keySet());

        List<Questionnaire__c> questionnaires = [
                SELECT Id , Name,
                (SELECT Id, Name, Question__c, Threat_Points__c, Yes_Additions__c, No_Additions__c, Order__c,
                        Branch__c, Branch__r.Branch_Order__c, Branch__r.Skip_Next_Questions_On__c,
                        Yes_Skip_To_Question__c, No_Skip_To_Question__c
                FROM Questions__r
                ORDER BY Branch__r.Branch_Order__c, Order__c ASC)
                FROM Questionnaire__c
        ];

        List<AssessmentTarget> newTargets = new List<AssessmentTarget>();
        List<AssessmentTarget> inProgress = new List<AssessmentTarget>();
        List<AssessmentTarget> completed = new List<AssessmentTarget>();
        List<AssessmentTarget> submitted = new List<AssessmentTarget>();
        List<AssessmentTarget> targetsWrappers = new List<AssessmentTarget>();

        for (Assessment_Target__c target : targets.values())
        {
            AssessmentTarget targetWrapper = new AssessmentTarget(target, results.get(target.Id));
            targetWrapper.setQuestionnaires(questionnaires);
            if (targetWrapper.newQuestionnaires != null)
            {
                newTargets.add(targetWrapper);
            }

            if (targetWrapper.startedQuestionnaires != null)
            {
                inProgress.add(targetWrapper);
            }

            if (targetWrapper.completedQuestionnaires != null)
            {
                completed.add(targetWrapper);
            }

            if (targetWrapper.submittedQuestionnaires != null)
            {
                submitted.add(targetWrapper);
            }

            targetsWrappers.add(targetWrapper);
        }

        return new Map<String, Object>{
                'newTargets' => newTargets,
                'inProgress' => inProgress,
                'completed' => completed,
                'submitted' => submitted,
                'all' => targetsWrappers
        };
    }

    @AuraEnabled
    public static Object submitAssessment(Map<String, String> params)
    {
        try
        {
            update new Target_Result__c(
                    Id = params.get('resultId'),
                    Is_Submitted__c = true,
                    Submitted_Date__c = Date.today()
            );

            sendEmail(params.get('resultId'));

            return new Map<String, Object> {
                    'success' => true,
                    'result' => getAssessmentTargets(params.get('token'))
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'success' => false,
                    'error' => 'error: ' + e.getMessage()
            };
        }
    }

    private static void sendEmail(String targetResultId)
    {

        System.debug('send email');
        Target_Result__c result = [
                SELECT Id, Questionnaire__r.Name, Questionnaire__c,
                        Assessment_Target__r.Main_User__c,
                        Assessment_Target__r.Inspector__c,
                        Assessment_Target__r.Main_User__r.Email__c,
                        Assessment_Target__r.Main_User__r.Name,
                        Assessment_Target__r.Inspector__r.Name,
                        Assessment_Target__c
                FROM Target_Result__c
                WHERE Id = :targetResultId
        ];

        List<String> emails = new List<String>();

        for (User user : [
                SELECT Id, Profile.Name, Email
                FROM User
                WHERE Profile.Name = 'System Administrator'])
        {
            emails.add(user.Email);
        }

        String reportPage = 'https://www.excalibur.biz/targetreport?targetId='
                + result.Assessment_Target__c
                + '&libId=' + result.Questionnaire__c;

        emails.add(result.Assessment_Target__r.Main_User__r.Email__c);

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.toAddresses = emails;
        message.subject = 'Assessment was submitted';
        message.htmlBody =
                '<p>Questionnaire name: ' + result.Questionnaire__r.Name + '</p>' +
                '<p>Submitted by: ' + result.Assessment_Target__r.Inspector__r.Name + '</p>' +
                '<p>Submitted for: ' + result.Assessment_Target__r.Main_User__r.Name + '</p>' +
                '<p>Click <a href="' + reportPage + '" target="_blank">here</a> for redirect to the report pdf</p>' +
                '<p><a href="https://excaliburportal.force.com/s/base2" target="_blank">Link to the portal</a></p>';
        Messaging.SingleEmailMessage[] messages =   new List<Messaging.SingleEmailMessage> {message};
        Messaging.sendEmail(messages);
    }

    private static Map<String, List<Target_Result__c>> getAssessmentsResults(Set<Id> targetsIds)
    {
        Map<String, List<Target_Result__c>> resultsMap = new Map<String, List<Target_Result__c>>();
        List<Target_Result__c> results = [
                SELECT Id, Questionnaire__c, Assessment_Target__c, ResultsJSON__c, Is_Started__c, Is_Completed__c,
                        Start_Date__c, Created_Date__c, Completed_Date__c, Is_Submitted__c, Submitted_Date__c,
                (SELECT Id, Have_Note__c, Have_Photo__c, Question__c, Answer__c, Target_Result__r.Questionnaire__c,
                        Target_Result__r.Assessment_Target__c, Target_Result__c, Question__r.Questionnaire__c,
                        Recommendation__c, Question__r.Question__c
                FROM Answers__r)
                FROM Target_Result__c
                WHERE Assessment_Target__c IN : targetsIds
        ];

        for (Target_Result__c resultIt : results)
        {
            if (resultsMap.containsKey(resultIt.Assessment_Target__c))
            {
                resultsMap.get(resultIt.Assessment_Target__c).add(resultIt);
            } else {
                resultsMap.put(resultIt.Assessment_Target__c, new List<Target_Result__c>{resultIt});
            }
        }

        return resultsMap;
    }

    @AuraEnabled
    public static Object findNotes(String questionId)
    {
        if (questionId == null)
        {
            return null;
        }

        Map<Id, Custom_Note__c> notesMap = new Map<Id, Custom_Note__c>([
                SELECT Id, Note_Body__c, Note_Title__c
                FROM Custom_Note__c
                WHERE Question__c = :questionId
        ]);

        List<Custom_Doc_Link__c> links = [
                SELECT Id, Content_Version_Id__c, Question__c, Answer__c, Custom_Note__c
                FROM Custom_Doc_Link__c
                WHERE Custom_Note__c IN : notesMap.keySet()
        ];

        Map<String, String> noteContentMap = new Map<String, String>();

        for (Custom_Doc_Link__c link : links)
        {
            noteContentMap.put(link.Custom_Note__c, link.Content_Version_Id__c);
        }

        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>([
                SELECT Id, VersionData, Description
                FROM ContentVersion
                WHERE Id IN : noteContentMap.values()
        ]);

        List<CustomNote> notes = new List<CustomNote>();

        for (Custom_Note__c note : notesMap.values())
        {
            System.debug(note);
            if (noteContentMap.get(note.Id) == null)
            {
                notes.add(new CustomNote(note));
            } else {
                notes.add(new CustomNote(note, versionMap.get(noteContentMap.get(note.Id))));
            }
        }

        return notes;
    }

    @AuraEnabled(Cacheable=false)
    public static Object setAnswer(String jsonAnswers, String jsonFile, String note)
    {
        List<Answer> answers = (List<Answer>)JSON.deserialize(jsonAnswers, List<Answer>.class);
        AnswerFile file;

        if (jsonFile != null)
        {
            file = (AnswerFile)JSON.deserialize(jsonFile, AnswerFile.class);
        }

        List<Answer__c> answersRecords = new List<Answer__c>();
        for (Answer answer : answers)
        {
            answersRecords.add(answer.getAnswerRec());
        }

        Answer__c currentAnswer = answersRecords[0];

        insert answersRecords;

        Map<String, Object> result = setTargetResultStatus(answersRecords[0].Target_Result__c);

        if (file != null)
        {
            result = insertPhoto(result, file, currentAnswer);
        }

        return result;
    }

    private static Map<String, Object> setTargetResultStatus(String targetResultId)
    {
        Target_Result__c result = [
                SELECT Id , Is_Completed__c, Is_Started__c, Questionnaire__r.Question_Number__c,
                (SELECT Id FROM Answers__r)
                FROM Target_Result__c
                WHERE Id = :targetResultId
        ];

        if (result.Answers__r.size() > 0)
        {
            result.Is_Started__c = true;
        }

        if (result.Answers__r.size() == 1)
        {
            result.Start_Date__c = Date.today();
        }

        if (result.Questionnaire__r.Question_Number__c == result.Answers__r.size())
        {
            result.Is_Completed__c = true;
            result.Completed_Date__c = Date.today();
        }

        update result;

        return new Map<String, Object>{
                'completed' => result.Is_Completed__c,
                'started' => result.Is_Started__c,
                'success' => true
        };
    }

    private static Map<String, Object> insertPhoto(Map<String, Object> currentResult, AnswerFile file, Answer__c currentAnswer)
    {
        try {
            currentResult.put('203', '203');
            ContentVersion version = new ContentVersion(
                    VersionData = EncodingUtil.base64Decode(file.base64body.substring(file.base64body.indexOf(',') + 1)),
                    Title = file.fileName,
                    PathOnClient = file.image ? 'data:image/png;base64' : 'data:application/pdf;base64'

            );
            insert version;

            currentResult.put('212', '212');
            Custom_Doc_Link__c newLink = new Custom_Doc_Link__c(
                    Answer__c = currentAnswer.Id,
                    Content_Version_Id__c = version.Id
            );
//            ContentDocumentLink newLink = new ContentDocumentLink(
//                    ContentDocumentId = createdVersion.ContentDocumentId,
//                    LinkedEntityId = currentAnswer.Id,
//                    ShareType = 'V'
//            );
            insert newLink;
            currentResult.put('220', 220);
            currentResult.put('version', version.Id);
            currentResult.put('contentLink', newLink.Id);
            currentResult.put('success', true);
        } catch (Exception e)
        {
            currentResult.put('exception', e.getLineNumber() + '--' + e.getMessage());
            currentResult.put('success', false);
            return currentResult;
        }

        currentAnswer.Have_Photo__c = true;
        update currentAnswer;

        return currentResult;
    }

    public class AssessmentTarget
    {
        @AuraEnabled public String name;
        @AuraEnabled public String targetId;
        @AuraEnabled public List<Questionnaire> newQuestionnaires;
        @AuraEnabled public List<Questionnaire> startedQuestionnaires;
        @AuraEnabled public List<Questionnaire> completedQuestionnaires;
        @AuraEnabled public List<Questionnaire> submittedQuestionnaires;
        @AuraEnabled public List<Questionnaire> questionnaires;
        @AuraEnabled public Boolean notStarted;
        public Map<String, Target_Result__c> resultRecords;

        public AssessmentTarget(Assessment_Target__c target, List<Target_Result__c> results)
        {
            this.name = target.Name;
            this.targetId = target.Id;
            this.questionnaires = new List<Questionnaire>();
            this.notStarted = target.Target_Results__r.isEmpty();

            if (!this.notStarted)
            {
                this.resultRecords = new Map<String, Target_Result__c>();

                for (Target_Result__c result : results)
                {
                    this.resultRecords.put(result.Questionnaire__c, result);
                }
            }
        }

        public void setQuestionnaires(List<Questionnaire__c> questionnaires)
        {
            for (Questionnaire__c questionnaire : questionnaires)
            {
                if (resultRecords != null && resultRecords.get(questionnaire.Id) != null)
                {
                    Questionnaire lib = new Questionnaire(questionnaire, resultRecords.get(questionnaire.Id));
                    if (!lib.started && !lib.completed)
                    {
                        if (newQuestionnaires == null)
                        {
                            newQuestionnaires = new List<Questionnaire>();
                        }

                        newQuestionnaires.add(lib);
                    }

                    if (lib.started && !lib.completed)
                    {
                        if (startedQuestionnaires == null)
                        {
                            startedQuestionnaires = new List<Questionnaire>();
                        }

                        startedQuestionnaires.add(lib);
                    }

                    if (lib.completed == true && !lib.submitted)
                    {
                        if (completedQuestionnaires == null)
                        {
                            completedQuestionnaires = new List<Questionnaire>();
                        }

                        completedQuestionnaires.add(lib);
                    }

                    if (lib.submitted)
                    {
                        if (submittedQuestionnaires == null)
                        {
                            submittedQuestionnaires = new List<Questionnaire>();
                        }

                        submittedQuestionnaires.add(lib);
                    }
                    this.questionnaires.add(new Questionnaire(questionnaire, resultRecords.get(questionnaire.Id)));
                }
            }
        }
    }

    public class Questionnaire
    {
        @AuraEnabled public String name;
        @AuraEnabled public List<Question> questions;
        @AuraEnabled public List<Question> answeredQuestions;
        @AuraEnabled public String libId;
        @AuraEnabled public Boolean haveStarted;
        @AuraEnabled public List<Answer> results;
        @AuraEnabled public String targetResult;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public Boolean started;
        @AuraEnabled public Integer lowestBranchOrder = 100;
        @AuraEnabled public Integer lowestOrder = 100;
        @AuraEnabled public Date startedDate;
        @AuraEnabled public Date createdDate;
        @AuraEnabled public Date completedDate;
        @AuraEnabled public String stylePercent;
        @AuraEnabled public Boolean submitted;
        @AuraEnabled public Date submittedDate;


        public Questionnaire(Questionnaire__c questionnaire, Target_Result__c result)
        {
            this.name = questionnaire.Name;
            this.libId = questionnaire.Id;
            this.questions = new List<Question>();
            this.answeredQuestions = new List<Question>();
            this.haveStarted = result.Answers__r != null;
            this.results = new List<Answer>();
            this.targetResult = result.Id;
            this.startedDate = result.Start_Date__c;
            this.createdDate = result.Created_Date__c;
            this.completedDate = result.Completed_Date__c;
            this.completed = result.Is_Completed__c;
            this.submitted = result.Is_Submitted__c;
            this.started = result.Is_Started__c;
            this.submittedDate = result.Submitted_Date__c;

            Set<String> answered = new Set<String>();

            if (this.haveStarted)
            {
                for (Answer__c answer : result.Answers__r)
                {
                    this.results.add(new Answer(answer));
                    answered.add(answer.Question__c);
                }
            }
            System.debug(questionnaire.Questions__r);
            for (Question__c question : questionnaire.Questions__r)
            {
                if (answered.contains(question.Id))
                {
                    this.answeredQuestions.add(new Question(question, answered.contains(question.Id)));
                } else {
                    Question itQuestion = new Question(question, answered.contains(question.Id));
                    if (itQuestion.branchOrder < this.lowestBranchOrder)
                    {
                        this.lowestBranchOrder = itQuestion.branchOrder;
                        if (itQuestion.questionOrder < this.lowestOrder)
                        {
                            this.lowestOrder = itQuestion.questionOrder;
                        }
                    }
                    this.questions.add(itQuestion);
                }
            }
            this.status = this.answeredQuestions.size() + ' / ' + (this.answeredQuestions.size() + this.questions.size());
            if (!this.answeredQuestions.isEmpty())
            {
                Double initial = (Double)(questionnaire.Questions__r.size() - this.answeredQuestions.size()) / questionnaire.Questions__r.size();
                this.stylePercent = 'width:' + (Integer)(100 - (initial * 100)) + '%';
            }
        }
    }

    public class Question
    {
        @AuraEnabled public String name;
        @AuraEnabled public String questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public Integer threatLevel;

        @AuraEnabled public Boolean haveAfterYes;
        @AuraEnabled public Boolean haveAfterNo;

        @AuraEnabled public String afterYes;
        @AuraEnabled public String afterNo;

        @AuraEnabled public Boolean answered;
        @AuraEnabled public String branchId;
        @AuraEnabled public Integer branchOrder;
        @AuraEnabled public Integer questionOrder;
        @AuraEnabled public String yesSkipTo;
        @AuraEnabled public String noSkipTo;
        @AuraEnabled public Boolean yesEnd = false;
        @AuraEnabled public Boolean noEnd = false;

        public Question(Question__c question, Boolean answered)
        {
            this.name = String.valueOf(question.Order__c);
            this.questionId = question.Id;
            this.questionText = question.Question__c;
            this.threatLevel = (Integer)question.Threat_Points__c;
            this.haveAfterYes = question.Yes_Additions__c != null;
            this.haveAfterNo = question.No_Additions__c != null;
            this.afterNo = question.No_Additions__c;
            this.afterYes = question.Yes_Additions__c;
            this.branchId = question.Branch__c;
            this.branchOrder = (Integer)question.Branch__r.Branch_Order__c;
            this.questionOrder = (Integer)question.Order__c;
            this.yesSkipTo = question.Yes_Skip_To_Question__c;
            this.noSkipTo = question.No_Skip_To_Question__c;
            this.answered = answered;

            if (question.Yes_Additions__c != null && question.Yes_Additions__c.contains('End Questionnaire'))
            {
                this.yesEnd = true;
            }

            if (question.No_Additions__c != null && question.No_Additions__c.contains('End Questionnaire'))
            {
                this.noEnd = true;
            }
        }
    }

    public class Answer
    {
        @AuraEnabled public String libId;
        @AuraEnabled public String resultLib;
        @AuraEnabled public String questionId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String result;
        @AuraEnabled public String targetId;
        @AuraEnabled public String answerId;
        @AuraEnabled public String note;
        @AuraEnabled public Boolean canChange = false;
        @AuraEnabled public Boolean haveNote;
        @AuraEnabled public Boolean haveImage;
        @AuraEnabled public String imageString;

        public Answer(Answer__c answer)
        {
            this.questionId = answer.Question__c;
            this.libId = answer.Question__r.Questionnaire__c;
            this.result = answer.Answer__c;
            this.targetId = answer.Target_Result__r.Assessment_Target__c;
            this.answerId = answer.Id;
            this.resultLib = answer.Target_Result__c;
            this.questionText = answer.Question__r.Question__c;
            this.note = answer.Recommendation__c;
            this.canChange = answer.Have_Note__c || answer.Have_Photo__c;
            this.haveNote = answer.Have_Note__c;
            this.haveImage = answer.Have_Photo__c;
        }

        public Answer()
        {

        }

        public Answer__c getAnswerRec()
        {
            Answer__c answerRec = new Answer__c(
                    Question__c = this.questionId,
                    Answer__c = this.result,
                    Target_Result__c = this.resultLib,
                    Recommendation__c = this.note,
                    Have_Note__c = this.note != null && this.note != ''
            );

            return answerRec;
        }
    }

    public class CustomNote
    {
        @AuraEnabled public String description;
        @AuraEnabled public String image;
        @AuraEnabled public Boolean haveImage;
        @AuraEnabled public String title;
        @AuraEnabled public String richBody;

        public CustomNote(ContentVersion cutomNote)
        {
            this.image = 'data:image/png;base64,' + EncodingUtil.base64Encode(cutomNote.VersionData);
            this.description = cutomNote.Description.replace('note-', '');
            this.haveImage = true;
        }

        public CustomNote(Custom_Note__c note)
        {
            this.haveImage = false;
            this.description = note.Note_Title__c;
            this.richBody = note.Note_Body__c;
        }

        public CustomNote(Custom_Note__c note, ContentVersion image)
        {
            this.haveImage = false;
            this.description = note.Note_Title__c;
            this.richBody = note.Note_Body__c;

            if (image != null)
            {
                this.image = 'data:image/png;base64,' + EncodingUtil.base64Encode(image.VersionData);
                this.description = image.Description.replace('note-', '');
                this.haveImage = true;
            }
        }
    }

    public class AnswerFile
    {
        @AuraEnabled
        public String base64body;
        @AuraEnabled
        public String fileName;
        @AuraEnabled
        public Boolean pdf;
        @AuraEnabled
        public Boolean image;

        public AnswerFile()
        {

        }
    }

}