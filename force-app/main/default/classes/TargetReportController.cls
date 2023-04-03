/**
 * Created by Razer on 06.04.2020.
 */

public without sharing class TargetReportController
{
    public TargetResult currentResult {get; set;}

    public TargetReportController()
    {
        String targetId = ApexPages.currentPage().getParameters().get('targetId');
        String libId = ApexPages.currentPage().getParameters().get('libId');

        Assessment_Target__c currentTarget = [
                SELECT Id, Name
                FROM Assessment_Target__c
                WHERE Id = :targetId
        ];

        AssessmentTarget target = new AssessmentTarget(currentTarget);

        for (TargetResult result : target.targetResults)
        {
            if (result.libId == libId)
            {
                currentResult = result;
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
                    FROM Answers__r)
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

            Map<String, List<ContentVersion>> answerImageMap = answerIds.isEmpty() ? new Map<String, List<ContentVersion>>() : UserController.getImages(answerIds, false, true, false);
            Map<String, List<ContentVersion>> questionImageMap = questionIds.isEmpty() ? new Map<String, List<ContentVersion>>() : UserController.getImages(questionIds, true, false, false);

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

    public class TargetResult
    {
        public String resultId {get; set;}
        public String name {get; set;}
        public String libName {get; set;}
        public List<Issue> issues {get; set;}
        public Boolean haveIssues {get; set;}
        public Boolean haveResults {get; set;}
        public Integer questionNumber {get; set;}
        public Integer averagePoints {get; set;}
        public String imageName {get; set;}
        public Decimal maxPoints {get; set;}
        public Decimal issuesPercent {get; set;}
        public String libId {get; set;}
        public Integer answered {get; set;}

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
        public Integer threatPoints {get; set;}
        public String issue {get; set;}
        public String recommendation {get; set;}
        public String answerId {get; set;}


        public String image {get; set;}
        public Boolean haveNote {get; set;}

        public String inspectorNote {get; set;}
        public String estimatedCost {get; set;}
        public String cellStyle {get; set;}

        public Boolean haveIssueImage {get; set;}
        public SiteAttachment issueAttachment {get; set;}

        public Boolean haveNoteImage {get; set;}
        public SiteAttachment noteAttachment {get; set;}

        public Boolean haveRecImage {get; set;}
        public SiteAttachment recAttachment {get; set;}

        public Boolean havePrices {get; set;}
        public List<Price> prices {get; set;}

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
        public String questionId {get; set;}
        public String priceId {get; set;}
        public Integer priceFrom {get; set;}
        public Integer priceTo {get; set;}
        public String message {get; set;}
        public String userMessage {get; set;}
        public String priceText {get; set;}

        public Price(Fix_Price__c price)
        {
            this.questionId = price.Question__c;
            this.priceId = price.Id;
            this.message = price.Price_Message__c;
            this.userMessage = '';
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
        public String title {get; set;}
        public String link {get; set;}
        public Boolean pdf {get; set;}
        public String imageString {get;set;}
        public String versionId {get;set;}

        public SiteAttachment(ContentVersion data)
        {
            this.versionId = data.Id;
            this.title = data.Title;
            this.pdf = data.PathOnClient.contains('pdf');
            this.link = 'https://excaliburusallc--c.visualforce.com/apex/attachmentviewer?version=' + data.Id;
        }
    }

}