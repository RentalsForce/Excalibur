/**
 * Created by Razer on 14.02.2020.
 */

public with sharing class QuestionnarieWizardController
{
    @AuraEnabled
    public static Map<String, Object> deleteTarget(Map<String, String> params)
    {
        System.debug(params);
        Target_Result__c result = [
                SELECT Id
                FROM Target_Result__c
                WHERE Assessment_Target__c = :params.get('targetId')
                AND Questionnaire__c = :params.get('libId')
                LIMIT 1
        ];

        List<Answer__c> answers = [
                SELECT Id FROM Answer__c WHERE Target_Result__c = :result.Id
        ];

        try
        {
            delete answers;
            delete result;

            return new Map<String, Object>{
                    'success' => ''
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Map<String, Object> deleteTask(String taskId)
    {
        try
        {
            delete new Questionnaire_Task__c(Id = taskId);
            return new Map<String, Object>{
                    'success' => ''
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Map<String, Object> createTask(Map<String, String> params)
    {
        Questionnaire_Task__c task = new Questionnaire_Task__c(
                Questionnaire__c = params.get('libId'),
                Task_Type__c = params.get('type'),
                Task_Title__c = params.get('title'),
                Task_Description__c = params.get('description'),
                Id = params.get('taskId'),
                Name = params.get('title').abbreviate(79)
        );

        try
        {
            upsert task;
            return new Map<String, Object>{
                    'success' => '',
                    'newTask' => new LibTask(task)
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static Map<String, Object> newAssessmentTarget(Map<String, String> params)
    {
        try
        {
            Target_Result__c result = new Target_Result__c(
                    Assessment_Target__c = params.get('targetId'),
                    Questionnaire__c = params.get('libId'),
                    Is_Completed__c = false,
                    Is_Started__c = false,
                    Created_Date__c = Date.today()
            );

            insert result;
            return new Map<String, Object>{
                'success' => ''
            };
        } catch (Exception e)
        {
            return new Map<String, Object>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }

    @AuraEnabled
    public static List<Target> getExistingTargets(List<String> currentTargetIds)
    {
        List<Assessment_Target__c> targets = [
                SELECT Id, Name
                FROM Assessment_Target__c
                WHERE Id NOT IN :currentTargetIds
        ];

        List<Target> targetWrappers = new List<Target>();

        for (Assessment_Target__c target : targets)
        {
            targetWrappers.add(new Target(target));
        }

        return targetWrappers;
    }

    @AuraEnabled
    public static Map<String, String> deleteQuestionnaire(String questionnaireId)
    {
        List<Question__c> questions = [SELECT Id FROM Question__c WHERE Questionnaire__c =: questionnaireId];
        List<Branch__c> branches = [SELECT Id FROM Branch__c WHERE Questionnaire__c =: questionnaireId];
        List<Target_Result__c> results = [SELECT Id FROM Target_Result__c WHERE Questionnaire__c =: questionnaireId];
        List<Answer__c> answers = [SELECT Id FROM Answer__c WHERE Question__r.Questionnaire__c =: questionnaireId];

        Savepoint sp = Database.setSavepoint();
        try
        {
            delete answers;
            delete results;
            delete branches;
            delete questions;
            delete new Questionnaire__c(Id = questionnaireId);

            return new Map<String, String>{
                    'success' => ''
            };
        } catch (Exception e)
        {
            Database.rollback(sp);
            return new Map<String, String>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }
    @AuraEnabled
    public static Map<String, Object> saveQuestionnaire(String libJson)
    {
        Questionnaire lib = (Questionnaire)JSON.deserialize(libJson, Questionnaire.class);
        System.debug(lib);
        System.debug('some new debug');
        try
        {
            Map<String, Object> result = new Map<String, Object>();
            if (lib.libId != 'new')
            {
                update lib.getQuestionsWithOrders();
            } else {
                Questionnaire__c newLib = lib.getNewQuestionnaire();
                insert newLib;
                Branch__c defaultBranch = lib.getNewBranch(newLib.Id);
                insert defaultBranch;
                Question questionWrapper = lib.allQuestions[0];
                questionWrapper.branchId = defaultBranch.Id;
                questionWrapper.questionnaireId = newLib.Id;
                Map<String, String> saveResult = saveQuestion(JSON.serialize(questionWrapper));

                System.debug(saveResult);

                result.put('questionId', saveResult.get('questionId'));
                result.put('shortText', saveResult.get('shortText'));
                result.put('questionOrder', saveResult.get('questionOrder'));
                result.put('newLibId', newLib.Id);
            }

            result.put('success', '');
            return result;

        } catch (Exception e)
        {
            return new Map<String, String>{
                    'error' => 'Error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }
    @AuraEnabled
    public static Map<String, String> saveQuestion(String question)
    {
        Question questionInfo = (Question)JSON.deserialize(question, Question.class);

        Question__c questionRecord = questionInfo.getQuestionSObject();
        Savepoint sp = Database.setSavepoint();
        try
        {
            if (questionRecord.Id != null)
            {
                update questionRecord;
                List<SObject> objectsToDelete = new List<SObject>();
                objectsToDelete.addAll([SELECT Id FROM Custom_Note__c WHERE Question__c = :questionRecord.Id]);
                objectsToDelete.addAll([SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :questionRecord.Id]);
                objectsToDelete.addAll([SELECT Id FROM Fix_Price__c WHERE Question__c = :questionRecord.Id]);
                delete objectsToDelete;
            } else {
                insert questionRecord;
            }


            List<Custom_Note__c> notes = new List<Custom_Note__c>();
            Map<String, ContentVersion> noteTitleImageMap = new Map<String, ContentVersion>();

            for (CustomNote note : questionInfo.questionRichNotes)
            {
                System.debug(note);
                System.debug(questionRecord);
                notes.add(note.getNoteSObject(questionRecord.Id));
                if (note.image != null)
                {
                    noteTitleImageMap.put(note.richNoteTitle, new ContentVersion(
                            VersionData = EncodingUtil.base64Decode(note.image.substring(note.image.indexOf(',') + 1)),
                            Title = 'noteAttachment.png',
                            PathOnClient = 'data:image/png;base64',
                            Description = 'note'
                    ));
                }
            }

            List<Fix_Price__c> prices = new List<Fix_Price__c>();

            System.debug(questionInfo);
            System.debug(questionInfo.prices);

            if (questionInfo.prices != null)
            {
                for (Price price : questionInfo.prices)
                {
                    if (price.questionId == null)
                    {
                        price.questionId = questionRecord.Id;
                    }
                    prices.add(price.getSObject());
                }

            } else {
                prices.add(new Fix_Price__c(Question__c = questionRecord.Id));
            }

            System.debug(noteTitleImageMap);

            if (!notes.isEmpty())
            {
                insert notes;
            }
            if (!prices.isEmpty())
            {
                insert prices;
            }

            if (!noteTitleImageMap.isEmpty())
            {
                for (Custom_Note__c note : notes)
                {
                    if (noteTitleImageMap.containsKey(note.Note_Title__c))
                    {
                        insertAttachments(new List<ContentVersion>{noteTitleImageMap.get(note.Note_Title__c)}, null, note.Id);
                    }
                }
            }

            ContentVersion rec = questionInfo.getAttachment(true, false, false);
            ContentVersion issue = questionInfo.getAttachment(false, true, false);
            ContentVersion note = questionInfo.getAttachment(false, false, true);

            List<ContentVersion> images = new List<ContentVersion>();
            if (rec != null && rec.VersionData != null)
            {
                images.add(rec);
                System.debug(rec);
            }
            if (note != null && note.VersionData != null)
            {
                images.add(note);
                System.debug(note);
            }
            if (issue != null && issue.VersionData != null)
            {
                images.add(issue);
                System.debug('have issue image');
            }

            if (!images.isEmpty())
            {
                insertAttachments(images, questionRecord.Id, null);
            }

            return new Map<String, String>{
                    'questionId' => questionRecord.Id,
                    'shortText' => questionRecord.Question__c.replaceAll('<[^>]+>',' ').abbreviate(50).unescapeHtml3(),
                    'questionOrder' => String.valueOf(questionRecord.Order__c),
                    'success' => ''
            };
        }catch (Exception e)
        {
            Database.rollback(sp);
            System.debug(e);
            System.debug(e.getLineNumber());
            System.debug(e.getCause());
            return new Map<String, String>{
                'error' => 'error: ' + e.getLineNumber() + ' - ' + e.getMessage()
            };
        }
    }

    private static void insertAttachments(List<ContentVersion> versions, String questionId, String noteId)
    {
        Set<String> versionsIds = new Set<String>();
        List<Custom_Doc_Link__c> linksForInsert = new List<Custom_Doc_Link__c>();

        if (versions != null && !versions.isEmpty())
        {
            for (ContentVersion version : versions)
            {
                version.Id = null;
            }
            insert versions;
        }
        for (ContentVersion version : versions)
        {
            versionsIds.add(version.Id);
        }

        for (ContentVersion version : versions)
        {
            Custom_Doc_Link__c docLink = new Custom_Doc_Link__c(Content_Version_Id__c = version.Id);
            if (questionId != null)
            {
                docLink.Question__c = questionId;
            }
            if (noteId != null)
            {
                docLink.Custom_Note__c = noteId;
            }

            linksForInsert.add(docLink);
        }
        insert linksForInsert;
    }

    @AuraEnabled
    public static void deleteCustomNote(String noteId)
    {
        if (noteId != null)
        {
            delete new Custom_Note__c(Id = noteId);
        }
    }
    @AuraEnabled
    public static String deleteQuestion(String questionId)
    {
        List<Question__c> question = [
                SELECT Id,
                (SELECT Id FROM Answers__r)
                FROM Question__c
                WHERE Id =: questionId
        ];

        List<Question__c> chainedQuestions = [
                SELECT Id, Yes_Skip_To_Question__c, No_Skip_To_Question__c
                FROM Question__c
                WHERE Yes_Skip_To_Question__c = :questionId
                OR No_Skip_To_Question__c = :questionId
        ];

        try
        {
            if (!question.isEmpty())
            {
                if (!question[0].Answers__r.isEmpty())
                {
                    delete question[0].Answers__r;
                }

                delete question[0];

                for (Question__c itQuestion : chainedQuestions)
                {
                    if (itQuestion.Yes_Skip_To_Question__c == questionId)
                    {
                        itQuestion.Yes_Skip_To_Question__c = null;
                    } else {
                        itQuestion.No_Skip_To_Question__c = null;
                    }
                }

                update chainedQuestions;

                return 'success';
            } else {
                return 'Problem: Can\'t find this question in DB';
            }
        } catch (Exception e)
        {
            return 'Problem: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static List<String> getQuestionAdditions()
    {
        return getAdditionsValues();
    }

    @AuraEnabled
    public static List<Questionnaire> getQuestionnaires()
    {
        List<Question__c> questions = [
                SELECT Id, Question__c, Branch__r.Id, Order__c, Yes_Additions__c, No_Additions__c,
                        Yes_Issue__c, No_Issue__c,
                        Yes_Skip_To_Question__r.Id,
                        Yes_Skip_To_Question__r.Question__c,
                        Yes_Skip_To_Question__r.Order__c,
                        No_Skip_To_Question__r.Id,
                        No_Skip_To_Question__r.Question__c,
                        No_Skip_To_Question__r.Order__c,
                        Branch__r.Name, Questionnaire__r.Id, Questionnaire__r.Name,
                        Threat_Points__c, Recomendation__c,
                (SELECT Id, Question__c, Price_From__c, Price_To__c, Price_Text__c FROM Fix_Prices__r),
                (SELECT Id, Note_Title__c, Note_Body__c FROM Custom_Notes__r)
                FROM Question__c
                ORDER BY Order__c, Questionnaire__r.Name ASC
        ];

        Map<String, Custom_Note__c> notesMap = new Map<String, Custom_Note__c>();

        for (Question__c question : questions)
        {
            for (Custom_Note__c note : question.Custom_Notes__r)
            {
                notesMap.put(note.Id, note);
            }
        }

        Map<String, String> noteImages = getCustomNoteImages(notesMap.keySet());

        Map<Id, Question__c> questionsMap = new Map<Id, Question__c>(questions);

        Map<String, List<CustomNote>> imageNotesMap = getImageNotes(questionsMap.keySet());

        List<Questionnaire> libs = new List<Questionnaire>();
        Set<String> libIds = new Set<String>();
        Map<String, List<Question__c>> libQuestionMap = new Map<String, List<Question__c>>();
        List<String> questionAdditions = getAdditionsValues();

        for (Question__c question : questions)
        {
            if (libQuestionMap.containsKey(question.Questionnaire__r.Id))
            {
                libQuestionMap.get(question.Questionnaire__r.Id).add(question);
            } else {
                libQuestionMap.put(question.Questionnaire__r.Id, new List<Question__c>{question});
            }

            libIds.add(question.Questionnaire__r.Id);
        }

        Map<Id, Questionnaire__c> libMap = new Map<Id, Questionnaire__c>([
                SELECT Id,
                (SELECT Id, Assessment_Target__r.Name, Assessment_Target__r.Id FROM Target_Results__r),
                (SELECT Id, Name, Questionnaire__c, Task_Title__c, Task_Description__c, Task_Type__c FROM Questionnaire_Tasks__r)
                FROM Questionnaire__c
                WHERE Id IN : libIds
        ]);

        for(String key : libQuestionMap.keySet())
        {
            libs.add(new Questionnaire(libQuestionMap.get(key), libMap.get(key), questionAdditions, imageNotesMap, noteImages));
        }

        return libs;
    }

    private static Map<String, String> getCustomNoteImages(Set<String> customNotesIds)
    {
        List<Custom_Doc_Link__c> links = [
                SELECT Id, Question__c, Content_Version_Id__c, Custom_Note__c
                FROM Custom_Doc_Link__c
                WHERE Custom_Note__c IN : customNotesIds
        ];

        Map<String, String> linkNoteMap = new Map<String, String>();
        Map<String, String> versionLinksMap = new Map<String, String>();

        for (Custom_Doc_Link__c link : links)
        {
            versionLinksMap.put(link.Content_Version_Id__c, link.Id);
            linkNoteMap.put(link.Id, link.Custom_Note__c);
        }

        List<ContentVersion> versions = [
                SELECT Id, VersionData, Description, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN : versionLinksMap.keySet()
        ];
        Map<String, String> imagesMap = new Map<String, String>();
        for (ContentVersion version : versions)
        {
            imagesMap.put(linkNoteMap.get(versionLinksMap.get(version.Id)), 'data:image/png;base64,' + EncodingUtil.base64Encode(version.VersionData));
        }

        return imagesMap;
    }

    private static Map<String, List<CustomNote>> getImageNotes(Set<Id> questionIds)
    {
        List<Custom_Doc_Link__c> links = [
                SELECT Id, Question__c, Content_Version_Id__c
                FROM Custom_Doc_Link__c
                WHERE Question__c IN : questionIds
        ];

        List<String> versionIds = new List<String>();
        Map<String, String> contentQuestion = new Map<String, String>();
        Map<String, List<CustomNote>> questionNoteMap = new Map<String, List<CustomNote>>();

        for (Custom_Doc_Link__c link : links)
        {
            versionIds.add(link.Content_Version_Id__c);
            contentQuestion.put(link.Content_Version_Id__c, link.Question__c);
            System.debug(link);
        }

        List<ContentVersion> versions = [
                SELECT Id, VersionData, Description, ContentDocumentId
                FROM ContentVersion
                WHERE Id IN : versionIds
        ];

        for (ContentVersion version : versions)
        {
            CustomNote note = new CustomNote(version);
            String questionId = contentQuestion.get(version.Id);
            if (questionNoteMap.containsKey(questionId))
            {
                questionNoteMap.get(questionId).add(note);
            } else {
                questionNoteMap.put(questionId, new List<CustomNote>{note});
            }
        }

        System.debug(questionNoteMap);
        return questionNoteMap;
    }

    public class Questionnaire
    {
        @AuraEnabled
        public String libId;
        @AuraEnabled
        public String libName;
        @AuraEnabled
        public String defaultBranchId;
        @AuraEnabled
        public List<Branch> branches;
        @AuraEnabled
        public List<Question> allQuestions;
        @AuraEnabled
        public List<Question> searchResults;
        @AuraEnabled
        public List<Target> targets;
        @AuraEnabled
        public Boolean newTargetDisabled = false;
        @AuraEnabled
        public Boolean newQuestionDisabled = false;
        @AuraEnabled
        public Boolean haveChanges = false;
        @AuraEnabled
        public Boolean saveQuestionDisabled = false;
        @AuraEnabled
        public List<LibTask> tasks;

        public Questionnaire(String libId)
        {

        }

        public Questionnaire(List<Question__c> questions, Questionnaire__c libsWithTargets, List<String> additions, Map<String, List<CustomNote>> imageNotesMap, Map<String, String> imageNotes)
        {
            this.libId = questions[0].Questionnaire__r.Id;
            this.libName = questions[0].Questionnaire__r.Name;
            this.branches = new List<Branch>();
            this.allQuestions = new List<Question>();
            this.targets = new List<Target>();

            Map<String, List<Question__c>> branchQuestionMap = new Map<String, List<Question__c>>();

            for (Question__c question : questions)
            {
                if (branchQuestionMap.containsKey(question.Branch__r.Id))
                {
                    branchQuestionMap.get(question.Branch__r.Id).add(question);
                } else {
                    branchQuestionMap.put(question.Branch__r.Id, new List<Question__c>{question});
                }

                if (question.Branch__r.Name == 'default branch')
                {
                    this.defaultBranchId = question.Branch__r.Id;
                }

                allQuestions.add(new Question(question, additions, imageNotesMap.get(question.Id), imageNotes));
            }

            this.searchResults = this.allQuestions;

            for (String key : branchQuestionMap.keySet())
            {
                branches.add(new Branch(branchQuestionMap.get(key), additions, imageNotesMap, imageNotes));
            }

            for (Target_Result__c result : libsWithTargets.Target_Results__r)
            {
                this.targets.add(new Target(result));
            }

            for (Questionnaire_Task__c task : libsWithTargets.Questionnaire_Tasks__r)
            {
                if (this.tasks == null)
                {
                    this.tasks = new List<LibTask>();
                }
                this.tasks.add(new LibTask(task));
            }
        }

        public List<Question__c> getQuestionsWithOrders()
        {
            List<Question__c> questions = new List<Question__c>();

            for (Question question : this.allQuestions)
            {
                questions.add(new Question__c(Id = question.questionId, Order__c = question.questionOrder));
            }

            return questions;
        }

        public Questionnaire__c getNewQuestionnaire()
        {
            return new Questionnaire__c(
                    Name = this.libName
            );
        }

        public Branch__c getNewBranch(String libId)
        {
            return new Branch__c(
                    Name = this.branches[0].branchName,
                    Branch_Order__c = 1,
                    Questionnaire__c = libId
            );
        }
    }

    public class LibTask
    {
        @AuraEnabled
        public String taskId;
        @AuraEnabled
        public String libId;
        @AuraEnabled
        public String taskTitle;
        @AuraEnabled
        public String taskDescription;
        @AuraEnabled
        public String taskType;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Boolean meeting;
        @AuraEnabled
        public Boolean photo;

        public LibTask(Questionnaire_Task__c task)
        {
            this.taskId = task.Id;
            this.name = task.Name;
            this.libId = task.Questionnaire__c;
            this.taskTitle = task.Task_Title__c;
            this.taskDescription = task.Task_Description__c;
            this.taskType = task.Task_Type__c;
            this.meeting = task.Task_Type__c == 'Schedule a Meeting';
            this.photo = task.Task_Type__c == 'Upload Photo';
        }
    }

    public class Branch
    {
        @AuraEnabled
        public String branchId;
        @AuraEnabled
        public String branchName;
        @AuraEnabled
        public List<Question> questions;

        public Branch(List<Question__c> questions, List<String> additions, Map<String, List<CustomNote>> imageNotesMap, Map<String, String> imageNotes)
        {
            this.branchId = questions[0].Branch__r.Id;
            this.branchName = questions[0].Branch__r.Name;
            this.questions = new List<Question>();

            for (Question__c question : questions)
            {
                this.questions.add(new Question(question, additions, imageNotesMap.get(question.Id), imageNotes));
            }
        }
    }

    public class Question
    {
        @AuraEnabled
        public String questionId;
        @AuraEnabled
        public String questionText;
        @AuraEnabled
        public Integer questionOrder;
        @AuraEnabled
        public String questionnaireId;
        @AuraEnabled
        public List<String> yesAdditions;
        @AuraEnabled
        public List<String> haveYes;
        @AuraEnabled
        public List<String> noAdditions;
        @AuraEnabled
        public List<String> haveNo;
        @AuraEnabled
        public String yesIssue;
        @AuraEnabled
        public String noIssue;
        @AuraEnabled
        public Boolean haveYesIssue = false;
        @AuraEnabled
        public Boolean haveNoIssue = false;
        @AuraEnabled
        public Boolean haveIssue = false;
        @AuraEnabled
        public String issueImage;
        @AuraEnabled
        public Boolean haveIssueImage = false;

        @AuraEnabled
        public Boolean haveRecommendation = false;
        @AuraEnabled
        public String recommendation;
        @AuraEnabled
        public Boolean haveRecImage = false;
        @AuraEnabled
        public String recImage;


        @AuraEnabled
        public Boolean haveNoteImage = false;
        @AuraEnabled
        public String imageNoteDescription;
        @AuraEnabled
        public String noteImage;
        @AuraEnabled
        public String currentIssue;
        @AuraEnabled
        public String shortName;
        @AuraEnabled
        public String yesSkipToText = '';
        @AuraEnabled
        public String yesSkipToId;
        @AuraEnabled
        public String noSkipToText = '';
        @AuraEnabled
        public String noSkipToId;
        @AuraEnabled
        public Integer threatPoints;
        @AuraEnabled
        public String branchId;
        @AuraEnabled
        public String tempText;
        @AuraEnabled
        public Boolean opened = false;
        @AuraEnabled
        public Boolean haveChange = false;
        @AuraEnabled
        public Boolean textEdit = false;
        @AuraEnabled
        public Boolean searchShow = true;
        @AuraEnabled
        public List<CustomNote> questionRichNotes;
        @AuraEnabled
        public Boolean haveRichNotes;
        @AuraEnabled
        public Boolean havePrices = false;
        @AuraEnabled
        public List<Price> prices;

        public Question__c getQuestionSObject()
        {
            System.debug(this.questionnaireId);
            return new Question__c(
                    Id = this.questionId,
                    Order__c = this.questionOrder,
                    Question__c = this.questionText,
                    Questionnaire__c = this.questionnaireId,
                    Yes_Additions__c = this.haveYes != null ? String.join(this.haveYes, ';') : null,
                    No_Additions__c = this.haveNo != null ? String.join(this.haveNo, ';') : null,
                    Yes_Issue__c = this.haveYesIssue ? this.yesIssue : null,
                    No_Issue__c = this.haveNoIssue ? this.noIssue : null,

                    No_Skip_To_Question__c = this.noSkipToId,
                    Yes_Skip_To_Question__c = this.yesSkipToId,
                    Threat_Points__c = this.threatPoints,
                    Branch__c = this.branchId,
                    Recomendation__c = this.recommendation
            );
        }

        public List<Custom_Note__c> getNoteSObjects(String newQuestionId)
        {
            List<Custom_Note__c> notes = new List<Custom_Note__c>();

            for (CustomNote note : this.questionRichNotes)
            {
                notes.add(note.getNoteSObject(newQuestionId));
            }

            return notes;
        }

        public ContentVersion getAttachment(Boolean rec, Boolean issue, Boolean note)
        {
            if (rec && String.isEmpty(this.recImage))
            {
                return null;
            }
            if (note && String.isEmpty(this.noteImage))
            {
                return null;
            }
            if (issue && String.isEmpty(this.issueImage))
            {
                return null;
            }

            if (rec)
            {
                return new ContentVersion(
                        VersionData = EncodingUtil.base64Decode(this.recImage.substring(this.recImage.indexOf(',') + 1)),
                        Title = 'recommendation.png',
                        PathOnClient = 'data:image/png;base64',
                        Description = 'rec-'
                );
            }

            if (issue)
            {
                return new ContentVersion(
                        VersionData = EncodingUtil.base64Decode(this.issueImage.substring(this.issueImage.indexOf(',') + 1)),
                        Title = 'issue.png',
                        PathOnClient = 'data:image/png;base64',
                        Description = 'issue-'
                );
            }

            if (note)
            {
                return new ContentVersion(
                        VersionData = EncodingUtil.base64Decode(this.noteImage.substring(this.noteImage.indexOf(',') + 1)),
                        Title = 'note.png',
                        PathOnClient = 'data:image/png;base64',
                        Description = 'note-' + this.imageNoteDescription
                );
            }

            return null;
        }

        public Question(Question__c question, List<String> additions, List<CustomNote> imageNotes, Map<String, String> imageRichNotes)
        {
            this.questionId = question.Id;
            this.questionText = question.Question__c;
            this.questionOrder = Integer.valueOf(question.Order__c);
            this.questionnaireId = question.Questionnaire__c;
            this.haveYes = question.Yes_Additions__c != null ? question.Yes_Additions__c.split(';') : null;
            this.yesAdditions = new List<String>();
            this.haveNo = question.No_Additions__c != null ? question.No_Additions__c.split(';') : null;
            this.noAdditions = new List<String>();
            this.shortName = this.questionOrder + ' - ' + question.Question__c.replaceAll('<[^>]+>',' ').abbreviate(50).unescapeHtml3();
            this.threatPoints = question.Threat_Points__c == null ? 0 : (Integer)question.Threat_Points__c;

            this.yesIssue = question.Yes_Issue__c == null ? '' : question.Yes_Issue__c;
            this.noIssue = question.No_Issue__c == null ? '' : question.No_Issue__c;
            this.haveYesIssue = this.yesIssue != '' && this.yesIssue != null;
            this.haveNoIssue = this.noIssue != '' && this.noIssue != null;
            this.haveIssue = this.haveNoIssue || this.haveNoIssue;
            this.currentIssue = this.haveYesIssue ? this.yesIssue : this.noIssue;
            this.questionRichNotes = new List<CustomNote>();
            this.haveRichNotes = question.Custom_Notes__r.size() != 0;
            this.branchId = question.Branch__r.Id;
            this.haveRecommendation = question.Recomendation__c != null;
            this.recommendation = question.Recomendation__c;
            this.havePrices = !question.Fix_Prices__r.isEmpty();
            this.prices = new List<Price>();

            for (String addition : additions)
            {
                if (haveNo != null && !haveNo.contains(addition))
                {
                    noAdditions.add(addition);
                }

                if (haveYes != null && !haveYes.contains(addition))
                {
                    yesAdditions.add(addition);
                }
            }

            if (haveNo == null)
            {
                noAdditions = additions;
            }

            if (haveYes == null)
            {
                yesAdditions = additions;
            }

            if (question.Yes_Skip_To_Question__r != null)
            {
                this.yesSkipToId = question.Yes_Skip_To_Question__r.Id;
                this.yesSkipToText = question.Yes_Skip_To_Question__r.Order__c + ' - ' +  question.Yes_Skip_To_Question__r.Question__c.replaceAll('<[^>]+>',' ').abbreviate(50).unescapeHtml3();
            }

            if (question.No_Skip_To_Question__r != null)
            {
                this.noSkipToId = question.No_Skip_To_Question__r.Id;
                this.noSkipToText = question.No_Skip_To_Question__r.Order__c + ' - ' +   question.No_Skip_To_Question__r.Question__c.replaceAll('<[^>]+>',' ').abbreviate(50).unescapeHtml3();
            }

            for (Custom_Note__c note : question.Custom_Notes__r)
            {
                this.questionRichNotes.add(new CustomNote(note, this.questionRichNotes.size(), imageRichNotes.get(note.Id)));
            }

            if (this.havePrices)
            {
                for (Integer i = 0; i < question.Fix_Prices__r.size(); i++)
                {
                    this.prices.add(new Price(question.Fix_Prices__r[i], i));
                }
            }

            if (imageNotes != null)
            {
                for (CustomNote note : imageNotes)
                {
                    if (note.issue)
                    {
                        this.haveIssueImage = true;
                        this.issueImage = note.image;
                    }

                    if (note.rec)
                    {
                        this.haveRecImage = true;
                        this.recImage = note.image;
                    }

                    if (note.note)
                    {
                        this.haveNoteImage = true;
                        this.noteImage = note.image;
                        this.imageNoteDescription = note.description;
                    }
                }
            }

        }
    }

    public class Price
    {
        @AuraEnabled
        public String questionId;
        @AuraEnabled
        public String priceId;
        @AuraEnabled
        public Integer priceFrom;
        @AuraEnabled
        public Integer priceTo;
        @AuraEnabled
        public Integer priceOrder;
        @AuraEnabled
        public String priceText;

        public Price(Fix_Price__c price, Integer priceOrder)
        {
            this.questionId = price.Question__c;
            this.priceId = price.Id;
            this.priceOrder = priceOrder;
            this.priceText = price.Price_Text__c;
        }

        public Fix_Price__c getSObject()
        {
            return new Fix_Price__c(
                    Question__c = this.questionId,
                    Price_From__c = this.priceFrom,
                    Price_To__c = this.priceTo,
                    Price_Text__c = this.priceText
            );
        }
    }

    public class Target
    {
        @AuraEnabled
        public String targetId;
        @AuraEnabled
        public String targetName;

        public Target(Target_Result__c result)
        {
            this.targetId = result.Assessment_Target__r.Id;
            this.targetName = result.Assessment_Target__r.Name;
        }

        public Target(Assessment_Target__c target)
        {
            this.targetId = target.Id;
            this.targetName = target.Name;
        }
    }

    public class CustomNote
    {
        @AuraEnabled public String description;
        @AuraEnabled public String image;
        @AuraEnabled public String versionId;
        @AuraEnabled public Boolean rec = false;
        @AuraEnabled public Boolean note = false;
        @AuraEnabled public Boolean issue = false;

        @AuraEnabled public Boolean richNote = false;
        @AuraEnabled public String richNoteId;
        @AuraEnabled public String richNoteTitle;
        @AuraEnabled public String richNoteBody;
        @AuraEnabled public Integer order;

        public Custom_Note__c getNoteSObject(String questionId)
        {
            return new Custom_Note__c(
                    Question__c = questionId,
                    Note_Title__c = this.richNoteTitle,
                    Note_Body__c = this.richNoteBody
            );
        }

        public CustomNote(ContentVersion customNote)
        {
            this.image = 'data:image/png;base64,' + EncodingUtil.base64Encode(customNote.VersionData);
            this.versionId = customNote.Id;

            if (customNote.Description.contains('rec-'))
            {
                this.rec = true;
                this.description = customNote.Description.replace('rec-', '');
            }

            if (customNote.Description.contains('note-'))
            {
                this.note = true;
                this.description = customNote.Description.replace('note-', '');
            }

            if (customNote.Description.contains('issue-'))
            {
                this.issue = true;
                this.description = customNote.Description.replace('issue-', '');
            }
        }

        public CustomNote(Custom_Note__c note, Integer order, String image)
        {
            this.richNoteId = note.Id;
            this.richNote = true;
            this.richNoteTitle = note.Note_Title__c;
            this.richNoteBody = note.Note_Body__c;
            this.order = order;
            this.image = image;
        }
    }

    private static List<String> getAdditionsValues()
    {
        List<String> returnList = new List<String>();
        List<PicklistEntry> values = Question__c.Yes_Additions__c.getDescribe().getPicklistValues();

        for (PicklistEntry value : values)
        {
            returnList.add(value.getValue());
        }

        return returnList;

    }
}