/**
 * Created by Razer on 25.12.2019.
 */

public without sharing class UserController
{
    @AuraEnabled
    public static Object getTargetResults(String token)
    {
        return new AssessmentTarget(getCurrentTarget(token));
    }

    @AuraEnabled
    public static Object getQuestions()
    {
        List<Q_A_Type__c> questionTypes = [
                SELECT Id, Name,
                (SELECT Id, Name, Question__c, Answer__c FROM Q_A_Items__r)
                FROM Q_A_Type__c
        ];

        List<QAType> types = new List<QAType>();

        for (Q_A_Type__c type : questionTypes)
        {
            types.add(new QAType(type));
        }

        return types;
    }

    @AuraEnabled
    public static Object getTasksInfo(String token)
    {
        Assessment_Target__c currentTarget = getCurrentTarget(token);
        List<String> targetResultsIds = new List<String>();

        for (Target_Result__c result : currentTarget.Target_Results__r)
        {
            targetResultsIds.add(result.Id);
        }

        List<Target_Result__c> results = [
                SELECT Id, Questionnaire__r.Name, Questionnaire__c, Questionnaire__r.Question_Number__c,
                        Assessment_Target__r.Main_User__r.Email__c, Is_Submitted__c,
                    (SELECT Id, Question__c FROM Answers__r),
                    (SELECT Id, Questionnaire_Task__c, Meeting_Scheduled__c, Meeting_Time__c,
                            Target_Result__r.Assessment_Target__r.Main_User__r.Email__c
                    FROM Completed_Tasks__r)
                FROM Target_Result__c
                WHERE Id IN : targetResultsIds
        ];

        List<String> libIds = new List<String>();

        for (Target_Result__c result : results)
        {
            libIds.add(result.Questionnaire__c);
        }

        Map<Id, Questionnaire__c> libs = new Map<Id, Questionnaire__c>([
                SELECT Id,
                (SELECT Id, Question__c FROM Questions__r),
                (SELECT Id, Task_Title__c, Task_Type__c, Task_Description__c FROM Questionnaire_Tasks__r)
                FROM Questionnaire__c
                WHERE Id IN : libIds
        ]);

        List<TargetTask> tasks = new List<TargetTask>();

        for (Target_Result__c result : results)
        {
            if (!libs.get(result.Questionnaire__c).Questionnaire_Tasks__r.isEmpty())
            {
                tasks.add(new TargetTask(result, libs.get(result.Questionnaire__c)));
            }
        }

        return tasks;

    }

    @AuraEnabled
    public static Object uploadTaskPhoto(String jsonTask)
    {
        AssessmentTask uploadTask = (AssessmentTask)JSON.deserialize(jsonTask, AssessmentTask.class);
        Completed_Task__c newCompleted = new Completed_Task__c(
                Questionnaire_Task__c = uploadTask.taskId,
                Target_Result__c = uploadTask.targetResultId
        );

        insert newCompleted;
        Map<String, Object> result = insertPhoto(uploadTask.currentPhotoString, newCompleted.Id);
        return result;
    }

    private static Map<String, Object> insertPhoto(String photo, String taskId)
    {
        Map<String, Object> results = new Map<String, Object>();
        try {
            results.put('134', '134');
            ContentVersion version = new ContentVersion(
                    VersionData = EncodingUtil.base64Decode(photo.substring(photo.indexOf(',') + 1)),
                    Title = 'test1.png',
                    PathOnClient = 'data:image/png;base64'

            );
            insert version;

            Custom_Doc_Link__c newDocLink = new Custom_Doc_Link__c(
                    Content_Version_Id__c = version.Id,
                    Completed_Task__c = taskId

            );
            insert newDocLink;
            results.put('version', version.Id);
            results.put('contentLink', newDocLink.Id);
            results.put('success', true);
        } catch (Exception e)
        {
            results.put('exception', e.getMessage());
            results.put('success', false);
            return results;
        }
        return results;
    }

    private static Assessment_Target__c getCurrentTarget(String token)
    {
        Site_User__c user = LoginController.getUserByToken(token);
        Assessment_Target__c currentTarget = [
                SELECT Id, Name,
                (SELECT Id, Is_Submitted__c FROM Target_Results__r)
                FROM Assessment_Target__c
                WHERE Main_User__c = :user.Id LIMIT 1
        ];

        return currentTarget;
    }

    public class QAType
    {
        @AuraEnabled public String typeName;
        @AuraEnabled public List<QA> items;
        @AuraEnabled public String typeId;

        public QAType(Q_A_Type__c type)
        {
            this.typeId = type.Id;
            this.typeName = type.Name;
            this.items = new List<QA>();

            for (Q_A_Item__c item : type.Q_A_Items__r)
            {
                this.items.add(new QA(item));
            }
        }
    }

    public class QA
    {
        @AuraEnabled public String itemId;
        @AuraEnabled public String name;
        @AuraEnabled public String question;
        @AuraEnabled public String answer;

        public QA(Q_A_Item__c item)
        {
            this.itemId = item.Id;
            this.name = item.Name;
            this.question = item.Question__c.abbreviate(50);
            this.answer = item.Answer__c;
        }
    }

    public class TargetTask
    {
        @AuraEnabled public String targetId;
        @AuraEnabled public String name;
        @AuraEnabled public List<AssessmentTask> tasks;
        @AuraEnabled public List<AssessmentTask> test;
        @AuraEnabled public Integer tasksCount;
        @AuraEnabled public Integer tasksCompleted = 0;
        @AuraEnabled public Integer percent;
        @AuraEnabled public Object message;
        @AuraEnabled public Boolean ready;
        @AuraEnabled public Boolean haveTasks;
        @AuraEnabled public String activeTaskId;
        @AuraEnabled public Date startDate = System.today();
        @AuraEnabled public Boolean haveCurrentPhoto = false;
        @AuraEnabled public String currentPhotoBlob;
        @AuraEnabled public Boolean showAction = false;
        @AuraEnabled public Boolean showPhoto = false;
        @AuraEnabled public Boolean showSchedule = false;
        @AuraEnabled public Boolean currentCompleted = false;
        @AuraEnabled public String calendyLink;
        @AuraEnabled public String info = '';
        @AuraEnabled public Boolean haveTime;
        @AuraEnabled public String meetingTime;
        @AuraEnabled public Boolean redirected = false;

        public TargetTask(Target_Result__c assessmentTarget, Questionnaire__c lib)
        {
            this.targetId = assessmentTarget.Id;
            this.name = assessmentTarget.Questionnaire__r.Name;
            this.tasks = new List<AssessmentTask>();
            this.test = new List<AssessmentTask>();
            this.tasksCount = lib.Questionnaire_Tasks__r.size();

            List<String> completedTask = new List<String>();
            List<String> targetTasks = new List<String>();
            Map<String, Completed_Task__c> completeTargetMap = new Map<String, Completed_Task__c>();

            for (Completed_Task__c task : assessmentTarget.Completed_Tasks__r)
            {
                completedTask.add(task.Id);
                targetTasks.add(task.Questionnaire_Task__c);
                completeTargetMap.put(task.Questionnaire_Task__c, task);
            }

            Map<String, List<ContentVersion>> imagesMap;
            if (!completedTask.isEmpty())
            {
                imagesMap = getImages(completedTask, false, false, true);
            }

            for (Questionnaire_Task__c task : lib.Questionnaire_Tasks__r)
            {
                this.info += task.Id + '----';
                Boolean haveResult = completeTargetMap.containsKey(task.Id);
                AssessmentTask taskWrap = new AssessmentTask(
                        task,
                        this.targetId,
                        completeTargetMap.get(task.Id),
                        haveResult ? imagesMap.get(completeTargetMap.get(task.Id).Id) : null,
                        assessmentTarget.Assessment_Target__r.Main_User__r.Email__c);
                this.tasks.add(taskWrap);
                if (taskWrap.completed)
                {
                    this.tasksCompleted++;
                }
            }

            if (this.tasksCount != 0)
            {
                this.message = '224';
                Double initial = (Double)(this.tasksCompleted) / this.tasksCount;
                this.percent = (Integer)(initial * 100);
                this.ready = false;
            } else {
                this.message = '104';
                this.percent = 100;
                this.ready = true;
            }
        }
    }

    public class AssessmentTask
    {
        @AuraEnabled public String questionId;
        @AuraEnabled public String question;

        @AuraEnabled public String taskId;
        @AuraEnabled public String targetResultId;
        @AuraEnabled public String title;
        @AuraEnabled public String description;
        @AuraEnabled public Boolean photo;
        @AuraEnabled public Boolean meeting;
        @AuraEnabled public Boolean haveTime;
        @AuraEnabled public String meetingTime;
        @AuraEnabled public String meetingDate;
        @AuraEnabled public String meetingTimeFrom;
        @AuraEnabled public String meetingTimeTo;
        @AuraEnabled public String currentPhotoBlob;
        @AuraEnabled public String currentPhotoString;
        @AuraEnabled public Boolean haveCurrentPhoto = false;
        @AuraEnabled public Boolean completed;
        @AuraEnabled public String calendyLink;
        @AuraEnabled public Boolean redirected = false;

        public AssessmentTask(Questionnaire_Task__c task, String targetResultId, Completed_Task__c targetTask, List<ContentVersion> images, String userEmail)
        {
            this.taskId = task.Id;
            this.targetResultId = targetResultId;
            this.title = task.Task_Title__c;
            this.description = task.Task_Description__c;
            this.photo = task.Task_Type__c.containsIgnoreCase('photo');
            this.meeting = !this.photo;
            this.completed = targetTask != null;
            this.calendyLink = 'https://calendly.com/xcalibut?sfid=' + this.taskId + '_' + this.targetResultId;

            if (images != null && !images.isEmpty())
            {
                this.currentPhotoString = 'data:image/png;base64,' + EncodingUtil.base64Encode(images[0].VersionData);
                this.haveCurrentPhoto = true;
            }

            if (targetTask != null)
            {
                this.haveTime = targetTask.Meeting_Scheduled__c;
                this.meetingTime = targetTask.Meeting_Time__c;
                if (this.meetingTime != null)
                {
                    this.meetingDate = this.meetingTime.substringBefore('T');
                    this.meetingTimeFrom = this.meetingTime.substringBetween('T', '-');
                    this.meetingTimeTo = this.meetingTime.substringAfterLast('-');
                }
            }

        }
    }



    public class AssessmentTarget
    {
        @AuraEnabled public String targetId;
        @AuraEnabled public String name;
        @AuraEnabled public List<TargetResult> targetResults;

        public AssessmentTarget(Assessment_Target__c assessmentTarget)
        {
            this.targetId = assessmentTarget.Id;
            this.name = assessmentTarget.Name;
            this.targetResults = new List<TargetResult>();

            this.setResults();
        }

        public void setResults()
        {
            List<Target_Result__c> results = [
                    SELECT Id, Name, Questionnaire__r.Id, Questionnaire__r.Name, Questionnaire__r.Question_Number__c,
                            Questionnaire__r.Max_Points__c, Is_Submitted__c,
                    (SELECT Id, Question__r.Threat_Points__c, Answer__c, Question__r.Yes_Issue__c,
                            Question__r.No_Issue__c, Question__r.Recomendation__c, Recommendation__c,
                            Question__r.Question__c
                    FROM Answers__r ORDER BY Question__r.Order__c)
                    FROM Target_Result__c
                    WHERE Assessment_Target__c = :targetId
            ];


            Map<String, List<Decimal>> diagramValues = this.getDiagramColorValues();

            List<String> answerIds = new List<String>();
            List<String> questionIds = new List<String>();

            for (Target_Result__c result : results)
            {
                for (Answer__c answer : result.Answers__r)
                {
                    answerIds.add(answer.Id);
                    questionIds.add(answer.Question__c);
                }
            }

            Map<String, List<ContentVersion>> answerImageMap = answerIds.isEmpty() ? new Map<String, List<ContentVersion>>() : getImages(answerIds, false, true, false);
            Map<String, List<ContentVersion>> questionImageMap = questionIds.isEmpty() ? new Map<String, List<ContentVersion>>() : getImages(questionIds, true, false, false);

            Map<Id, Question__c> questionsWithPrices = new Map<Id, Question__c>([
                    SELECT Id,
                            (SELECT Id, Price_From__c, Price_To__c, Price_Message__c, Question__c, Price_Text__c FROM Fix_Prices__r ORDER BY Price_From__c)
                    FROM Question__c
                    WHERE Id IN : questionIds
            ]);

            for (Target_Result__c result : results)
            {
                this.targetResults.add(new TargetResult(result, answerImageMap, questionImageMap, diagramValues, questionsWithPrices));
            }
        }

        private Map<String, List<Decimal>> getDiagramColorValues()
        {
            Diagram_Values__c diagramValues = [
                    SELECT Id, Green__c, Blue__c, Orange__c, Yellow__c, Red__c FROM Diagram_Values__c LIMIT 1
            ];

            Map<String, List<Decimal>> values = new Map<String, List<Decimal>>();
            List<String> colorValues = diagramValues.Green__c.split('-');
            values.put('green', new List<Decimal>{Decimal.valueOf(colorValues[0]), Decimal.valueOf(colorValues[1])});

            colorValues = diagramValues.Blue__c.split('-');
            values.put('blue', new List<Decimal>{Decimal.valueOf(colorValues[0]), Decimal.valueOf(colorValues[1])});

            colorValues = diagramValues.Orange__c.split('-');
            values.put('orange', new List<Decimal>{Decimal.valueOf(colorValues[0]), Decimal.valueOf(colorValues[1])});

            colorValues = diagramValues.Red__c .split('-');
            values.put('red', new List<Decimal>{Decimal.valueOf(colorValues[0]), Decimal.valueOf(colorValues[1])});

            colorValues = diagramValues.Yellow__c.split('-');
            values.put('yellow', new List<Decimal>{Decimal.valueOf(colorValues[0]), Decimal.valueOf(colorValues[1])});

            return values;
        }
    }

    public static Map<String, List<ContentVersion>> getImages(List<String> ids, Boolean questions, Boolean answers, Boolean tasks)
    {
        List<Custom_Doc_Link__c> links;

        if (answers)
        {
            links = [
                    SELECT Id, Content_Version_Id__c, Answer__c, Question__c, Questionnaire_Task__c, Completed_Task__c
                    FROM Custom_Doc_Link__c
                    WHERE Answer__c IN : ids
            ];
        }
        if (questions)
        {
            links = [
                    SELECT Id, Content_Version_Id__c, Answer__c, Question__c, Questionnaire_Task__c, Completed_Task__c
                    FROM Custom_Doc_Link__c
                    WHERE Question__c IN : ids
            ];
        }
        if (tasks)
        {
            links = [
                    SELECT Id, Content_Version_Id__c, Answer__c, Question__c, Questionnaire_Task__c, Completed_Task__c
                    FROM Custom_Doc_Link__c
                    WHERE Completed_Task__c IN : ids
            ];
        }

        Map<String, String> linkEntityMap = new Map<String, String>();

        for (Custom_Doc_Link__c link : links)
        {
            if (answers)
            {
                linkEntityMap.put(link.Content_Version_Id__c, link.Answer__c);
            }
            if (questions)
            {
                linkEntityMap.put(link.Content_Version_Id__c, link.Question__c);
            }
            if (tasks)
            {
                linkEntityMap.put(link.Content_Version_Id__c, link.Completed_Task__c);
            }
        }

        List<ContentVersion> versions = [
                SELECT Id, VersionData, Description, ContentDocumentId, PathOnClient, Title
                FROM ContentVersion
                WHERE Id IN : linkEntityMap.keySet()
        ];

        Map<String, List<ContentVersion>> answerImageMap = new Map<String, List<ContentVersion>>();

        for (ContentVersion version : versions)
        {
            if (answerImageMap.containsKey(linkEntityMap.get(version.Id)))
            {
                answerImageMap.get(linkEntityMap.get(version.Id)).add(version);
            } else {
                answerImageMap.put(linkEntityMap.get(version.Id), new List<ContentVersion>{version});
            }
        }

        return answerImageMap;
    }

    public class TargetResult
    {
        @AuraEnabled public String resultId;
        @AuraEnabled public String name;
        @AuraEnabled public String libName;
        @AuraEnabled public List<Issue> issues;
        @AuraEnabled public Boolean haveIssues;
        @AuraEnabled public Boolean haveResults;
        @AuraEnabled public Integer questionNumber;
        @AuraEnabled public Integer averagePoints;
        @AuraEnabled public String imageName;
        @AuraEnabled public Decimal maxPoints;
        @AuraEnabled public Decimal issuesPercent;
        @AuraEnabled public String libId;
        public Integer answered;

        public TargetResult(Target_Result__c targetResult, Map<String, List<ContentVersion>> answerImageMap, Map<String, List<ContentVersion>> questionImageMap, Map<String, List<Decimal>> diagramValues, Map<Id, Question__c> questionsWithPrices)
        {
            this.libName = targetResult.Questionnaire__r.Name;
            this.resultId = targetResult.Id;
            this.name = targetResult.Name;
            this.issues = new List<Issue>();
            this.questionNumber = (Integer)targetResult.Questionnaire__r.Question_Number__c;
            this.averagePoints = 0;
            this.maxPoints = targetResult.Questionnaire__r.Max_Points__c;
            this.libId = targetResult.Questionnaire__r.Id;

            for (Answer__c answer : targetResult.Answers__r)
            {
                if (answer.Question__r.Threat_Points__c == 0)
                {
                    continue;
                }
                if (answer.Answer__c == 'Yes' && answer.Question__r.Yes_Issue__c != null)
                {
                    this.issues.add(new Issue(answer, answerImageMap.get(answer.Id), questionImageMap.get(answer.Question__c), null, questionsWithPrices));
                    this.averagePoints = this.averagePoints + (Integer)answer.Question__r.Threat_Points__c;
                }

                if (answer.Answer__c == 'No' && answer.Question__r.No_Issue__c != null)
                {
                    this.issues.add(new Issue(answer, answerImageMap.get(answer.Id), questionImageMap.get(answer.Question__c), null, questionsWithPrices));
                    this.averagePoints = this.averagePoints + (Integer)answer.Question__r.Threat_Points__c;
                }
            }
            this.haveResults = targetResult.Answers__r.size() == this.questionNumber && targetResult.Is_Submitted__c;
            this.issuesPercent = (this.averagePoints / this.maxPoints * 100).setScale(2);
            this.imageName = this.getImageName(this.issuesPercent, diagramValues);
            this.haveIssues = !this.issues.isEmpty();
        }

        private String getImageName(Decimal percent, Map<String, List<Decimal>> diagramValues)
        {
            String imageName;
            for (String key : diagramValues.keySet())
            {
                Decimal startPoint = diagramValues.get(key)[0];
                Decimal endPoint = diagramValues.get(key)[1];

                if (percent >= startPoint && percent <= endPoint)
                {
                    imageName = key;
                    break;
                }
            }

            return imageName;
        }
    }

    public class Issue
    {
        @AuraEnabled public Integer threatPoints;
        @AuraEnabled public String issue;
        @AuraEnabled public String recommendation;
        @AuraEnabled public String answerId;

        @AuraEnabled public String image;
        @AuraEnabled public Boolean imagePdf = false;
        @AuraEnabled public Boolean haveNote;

        @AuraEnabled public String inspectorNote;
        @AuraEnabled public String estimatedCost = '------';
        @AuraEnabled public String cellStyle;

        @AuraEnabled public Boolean haveIssueImage = false;
        @AuraEnabled public SiteAttachment issueAttachment;


        @AuraEnabled public Boolean haveNoteImage = false;
        @AuraEnabled public SiteAttachment noteAttachment;

        @AuraEnabled public Boolean haveRecImage = false;
        @AuraEnabled public SiteAttachment recAttachment;

        @AuraEnabled public Boolean havePrices;
        @AuraEnabled public List<Price> prices;

        public Issue(Answer__c answer, List<ContentVersion> answerImages, List<ContentVersion> questionImages, ContentVersion taskImage, Map<Id, Question__c> questionsWithPrices)
        {
            this.issue = answer.Question__r.No_Issue__c == null ? answer.Question__r.Yes_Issue__c : answer.Question__r.No_Issue__c;
//            this.issue = answer.Question__r.No_Issue__c == null ? answer.Question__r.Yes_Issue__c : answer.Question__r.No_Issue__c;
            this.threatPoints = (Integer)answer.Question__r.Threat_Points__c;
            this.recommendation = answer.Question__r.Recomendation__c;
            this.answerId = answer.Id;
            this.inspectorNote = answer.Recommendation__c;
            this.haveNote = this.inspectorNote != null;
            this.havePrices = !questionsWithPrices.get(answer.Question__c).Fix_Prices__r.isEmpty();
            this.prices = new List<Price>();


            if (answerImages != null && !answerImages.isEmpty())
            {
                this.haveNoteImage = true;
                this.noteAttachment = new SiteAttachment(answerImages[0]);

//                this.noteImage = answerImages[0].PathOnClient + ',' + EncodingUtil.base64Encode(answerImages[0].VersionData);
//                this.notePdf = answerImages[0].PathOnClient.contains('pdf');
            }

            if (questionImages != null && !questionImages.isEmpty())
            {
                for (ContentVersion version : questionImages)
                {
                    if (version.Description.contains('issue'))
                    {
                        this.haveIssueImage = true;
                        this.issueAttachment = new SiteAttachment(version);

//                        this.issueImage = version.PathOnClient + ',' + EncodingUtil.base64Encode(version.VersionData);
//                        this.issuePdf = version.PathOnClient.contains('pdf');
                    }
                    if (version.Description.contains('rec'))
                    {
                        this.haveRecImage = true;
                        this.recAttachment = new SiteAttachment(version);


//                        this.recImage = version.PathOnClient + ',' + EncodingUtil.base64Encode(version.VersionData);
//                        this.recPdf = version.PathOnClient.contains('pdf');
                    }
                }
            }

            if (taskImage != null)
            {
                this.image = taskImage.PathOnClient + ',' + EncodingUtil.base64Encode(taskImage.VersionData);
                this.imagePdf = taskImage.PathOnClient.contains('pdf');
            }
            if (this.havePrices)
            {
                for (Fix_Price__c price : questionsWithPrices.get(answer.Question__c).Fix_Prices__r)
                {
                    this.prices.add(new Price(price));
                }
            }

            this.getCellColor();
        }

        private void getCellColor()
        {
            String color;

            if (this.threatPoints == 1)
            {
                color = '#42BF00';
            }
            if (this.threatPoints == 2)
            {
                color = '#0093F0';
            }
            if (this.threatPoints == 3)
            {
                color = '#FFE400';
            }
            if (this.threatPoints == 4)
            {
                color = '#FFC000';
            }
            if (this.threatPoints > 4)
            {
                color = '#FF2A00';
            }

            this.cellStyle = 'background-color: ' + color;
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
        public String message;
        @AuraEnabled
        public String userMessage = '';
        @AuraEnabled
        public String priceText;

        public Price(Fix_Price__c price)
        {
            this.questionId = price.Question__c;
            this.priceId = price.Id;
            this.message = price.Price_Message__c;
            this.priceText = price.Price_Text__c;
            this.setUserMessage();
        }

        private void setUserMessage()
        {
            if (this.priceFrom == 0)
            {
                this.userMessage = 'under ' + this.priceTo + '$ ';
                if (this.message != null)
                {
                    this.userMessage += this.message;
                }
            } else {
                this.userMessage = this.priceFrom + '$ - ' + this.priceTo + '$ ' + this.message;
            }
        }
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
        public String imageString;
        @AuraEnabled
        public String versionId;

        public SiteAttachment(ContentVersion data)
        {
            this.versionId = data.Id;
            this.title = data.Title;
            this.pdf = data.PathOnClient.contains('pdf');
            this.link = 'https://excaliburusallc--c.visualforce.com/apex/attachmentviewer?version=' + data.Id;

        }
    }


}