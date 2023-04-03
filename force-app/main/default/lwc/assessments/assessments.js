/**
 * Created by Мастер Эш on 16.12.2019.
 */

import {LightningElement, track} from 'lwc';
import getAssessments from '@salesforce/apex/InstructorController.getAssessmentTargets';
import getNotes from '@salesforce/apex/InstructorController.findNotes';
import setAnswer from '@salesforce/apex/InstructorController.setAnswer';
import submitAssessment from '@salesforce/apex/InstructorController.submitAssessment';
import changeAnswer from '@salesforce/apex/InstructorController.changeAnswer'
import getAnswerImage from '@salesforce/apex/InstructorController.getAnswerImage';
import wipeTargetResult from '@salesforce/apex/InstructorController.wipeTargetResult';
import wipeFromAnswer from '@salesforce/apex/InstructorController.wipeFromAnswer';

export default class Assessments extends LightningElement {

    @track currentQuestion;
    @track questionModal;
    @track currentNotes;
    @track notesOpened = true;
    @track additions;
    @track currentAnswer;
    @track havePhoto;
    @track haveNote;
    @track sendDisabled = false;
    @track waitQuestion = false;
    @track allAssessments;
    @track newAssessments;
    @track inProgressAssessments;
    @track completedAssessments;
    @track submittedAssessments;
    @track currentAssessment;

    @track currentLib = null;

    @track currentNewAssessment = null;
    @track currentNewLib = null;

    @track currentInprogressAssessment = null;
    @track currentInprogressAssessmentLib = null;

    @track currentCompletedAssessment = null;
    @track currentCompletedLib = null;

    @track currentSubmittedAssessment = null;
    @track currentSubmittedLib = null;
    @track mainSpinner = false;

    @track openedAssessment = null;

    @track changeAttachmentsModal = false;
    @track activeLib;
    @track openedAnswer;
    @track changeDisabled = true;

    @track messageModal = {
        header: null,
        body: null,
        mode: null,
        open: false,
        params: null
    };

    @track formats = ['font', 'size', 'bold', 'italic', 'underline',
        'strike', 'list', 'indent', 'align', 'link', 'clean', 'table', 'header', 'color'];

    currentActive = 'newTargets';
    answer;
    @track answerFile;
    @track uploadedPhoto;
    pdfUploaded = false;
    imageUploaded = false;
    @track fileName = null;

    issueNote;
    somethingChanges = false;

    connectedCallback()
    {
        this.waitQuestion = true;
        this.mainSpinner = true;
        getAssessments({token: localStorage.getItem('exToken')})
            .then(result => this.getAssessmentProcessor(result));
    }

    getAssessmentProcessor(result)
    {
        this.allAssessments = result;
        this.newAssessments = this.allAssessments.newTargets;
        this.inProgressAssessments = this.allAssessments.inProgress;
        this.completedAssessments = this.allAssessments.completed;
        this.submittedAssessments = this.allAssessments.submitted;

        this.currentNewAssessment = null;
        this.currentNewLib = null;
        this.currentInprogressAssessment = null;
        this.currentInprogressAssessmentLib = null;
        this.currentSubmittedAssessment = null;
        this.openedAssessment = null;
        this.currentSubmittedLib = null;
        this.currentCompletedAssessment = null;
        this.currentCompletedLib = null;
        this.somethingChanges = false;

        this.template.querySelectorAll('.assessment.' + this.currentActive).forEach(node => {
            node.classList.remove('slds-hide');
        });

        this.mainSpinner = false;
        this.waitQuestion = false;
        this.closeMessageModal();
    }

    openAssessment(event)
    {
        const assessmentId = event.target.closest('.assessmentItem').dataset.assid;
        const assessmentType = event.target.closest('.assessmentItem').dataset.type;
        let currentAssessments;
        let currentAssessment;

        switch (assessmentType) {
            case 'newTargets':
                currentAssessments = this.newAssessments;
                currentAssessment = this.currentNewAssessment;
                break;
            case 'inProgress':
                currentAssessments = this.inProgressAssessments;
                currentAssessment = this.currentInprogressAssessment;
                break;
            case 'completed':
                currentAssessments = this.completedAssessments;
                currentAssessment = this.currentCompletedAssessment;
                break;
            case 'submitted':
                currentAssessment = this.currentSubmittedAssessment;
                currentAssessments = this.submittedAssessments;
        }

        if (currentAssessment === null)
        {
            currentAssessment = currentAssessments.find(ass => ass.targetId === assessmentId);
            currentAssessment.currentAssessment = true;
            this.template.querySelectorAll('.assessment.' + assessmentType).forEach(node => {
                if (node.dataset.assid !== assessmentId)
                {
                    node.classList.add('slds-hide');
                }
            });
        } else {
            currentAssessments.find(ass => ass.targetId === assessmentId).currentAssessment = false;

            this.currentNewAssessment = null;
            this.currentInprogressAssessment = null;
            this.currentCompletedAssessment = null;
            this.currentSubmittedAssessment = null;

            this.template.querySelectorAll('.assessment.' + assessmentType).forEach(node => {
                node.classList.remove('slds-hide');
            });

            this.activeLib.open = false;
            this.template.querySelectorAll('div.lib[data-libid]').forEach(libNode => {
                libNode.classList.remove('slds-hide');
            });
            setTimeout(() => {this.activeLib = null}, 0);

        }

        switch (assessmentType) {
            case 'newTargets':
                this.currentNewAssessment = currentAssessment;

                break;
            case 'inProgress':
                this.currentInprogressAssessment = currentAssessment;
                break;
            case 'completed':
                this.currentCompletedAssessment = currentAssessment;
                break;
            case 'submitted':
                this.currentSubmittedAssessment = currentAssessment;

        }

        this.currentAssessment = currentAssessment;
    }

    openLib(event)
    {
        const libId = event.target.closest('.libItem').dataset.libid;
        const assessmentType = event.target.closest('.libItem').dataset.type;
        let currentAssessment;

        switch (assessmentType) {
            case 'newTargets':
                currentAssessment = this.currentNewAssessment;
                break;
            case 'inProgress':
                currentAssessment = this.currentInprogressAssessment;
                break;
            case 'completed':
                currentAssessment = this.currentCompletedAssessment;

        }

        this.currentLib = currentAssessment.questionnaires.find(lib => lib.libId === libId);

        if (this.currentLib !== null)
        {
            let currentQuestion = this.currentLib.questions
                .find(question =>
                    question.questionOrder === this.currentLib.lowestOrder
                    && question.branchOrder === this.currentLib.lowestBranchOrder);
            currentQuestion.first = true;
            this.openQuestion(currentQuestion);
        } else {
            this.template.querySelectorAll('.lib').forEach(node => {
                node.classList.remove('slds-hide');
            });
            this.currentLib = null;
        }
    }

    nextQuestion(previousAnswer)
    {
        this.additions = null;
        this.haveNote = null;
        this.issueNote = null;
        this.removeFile();

        let minOrder = 1000;
        this.currentLib.questions.forEach(question => question.questionOrder < minOrder ? minOrder = question.questionOrder : '');
        const nextQuestion = this.currentLib.questions.find(question => question.questionOrder === minOrder);

        if (nextQuestion !== undefined)
        {
            this.openQuestion(nextQuestion);
        } else {
            this.closeModal();
        }
    }

    openQuestion(question)
    {
        this.currentNotes = null;
        getNotes({questionId: question.questionId}).then(result => this.notesProcessor(result));
        this.currentQuestion = question;
        this.questionModal = true;
        this.waitQuestion = false;
    }

    notesProcessor(result)
    {
        if (result !== undefined && result.length > 0)
        {
            this.currentNotes = result;
        }
    }

    closeModal()
    {
        this.currentQuestion = null;
        this.questionModal = false;
        this.currentNotes = null;
        this.additions = null;
        this.removeFile();

        if (this.somethingChanges)
        {
            this.connectedCallback();
        }

    }

    handleOpenSection() {
        const accordion = this.template.querySelector('.example-accordion');
        this.notesOpened = !this.notesOpened;
        accordion.activeSectionName = this.notesOpened ? 'C' : 'B';
    }

    setQuestionResult(event)
    {
        const result = event.target.dataset.answer;
        this.waitQuestion = true;
        let answer = {
            libId: this.currentLib.libId,
            questionId: this.currentQuestion.questionId,
            result: result,
            targetId: this.currentAssessment.targetId,
            resultLib: this.currentLib.targetResult,
        };

        const answerModifiers = {
            haveAfter: result === 'no' ? 'haveAfterNo' : 'haveAfterYes',
            afters: result === 'no' ? 'afterNo' : 'afterYes'
        };

        this.currentQuestion.answer = answer;

        if (!this.currentQuestion[answerModifiers.haveAfter])
        {
            let answers = this.findOther(answer);
            setAnswer({jsonAnswers: JSON.stringify(answers), photoBlob: null, note: null})
                .then(result => this.answerProcessor(result, answers));
        } else {
            if (!this.currentQuestion[answerModifiers.afters].includes('Attachment')
                && !this.currentQuestion[answerModifiers.afters].includes('Issue'))
            {
                this.somethingChanges = true;
                let answers = this.findOther(answer);
                setAnswer({jsonAnswers: JSON.stringify(answers), photoBlob: null, note: null})
                    .then(result => this.answerProcessor(result, answers));
            } else {
                this.additions = {
                    photo: this.currentQuestion[answerModifiers.afters].includes('Attachment'),
                    note: this.currentQuestion[answerModifiers.afters].includes('Issue')
                };
                this.validateAttachments();
            }
            this.answer = answer;
            this.waitQuestion = false;
        }
    }

    findOther(answer)
    {
        let afterAnswers = this.currentLib.questions
            .filter(question => question.branchOrder === this.currentQuestion.branchOrder
                && question.questionOrder >= this.currentQuestion.questionOrder);

        let stopId = null;

        if (this.currentQuestion.yesSkipTo !== null && answer.result === 'yes')
        {
            if (!this.currentQuestion.yesEnd)
            {
                stopId = this.currentQuestion.yesSkipTo;
            }
        }

        if (this.currentQuestion.noSkipTo !== null && answer.result === 'no')
        {
            if (!this.currentQuestion.noEnd)
            {
                stopId = this.currentQuestion.noSkipTo;
            }
        }

        let wrappers = [];
        if (afterAnswers.length !== 0 && stopId !== undefined && stopId !== null)
        {
            let targetQuestion = afterAnswers.find(question => question.questionId === stopId);

            afterAnswers.forEach(question => {
                if (question.questionOrder >= this.currentQuestion.questionOrder &&
                    question.questionOrder < targetQuestion.questionOrder)
                {
                    let wrapper = {
                        libId: this.currentLib.libId,
                        questionId: question.questionId,
                        result: answer.result,
                        targetId: this.currentAssessment.targetId,
                        resultLib: this.currentLib.targetResult
                    };
                    wrappers.push(wrapper);
                }
            });
        } else {
            wrappers = [answer];
        }

        return wrappers;
    }

    handleFiles(event)
    {
        this.getBase64(event.target.files[0]);
        this.havePhoto = true;
        this.validateAttachments();

        // this.template.querySelector('.uploadedPhoto').src = URL.createObjectURL(event.target.files[0]);
    }

    handleNote(event)
    {
        this.issueNote = event.target.value;
        this.haveNote = this.issueNote.length !== 0;

        this.validateAttachments();
    }

    validateAttachments()
    {
        // this.sendDisabled = this.additions.photo && !this.havePhoto;

        // let needHave = 0;
        // let needCount = 0;
        // if (this.additions.photo)
        // {
        //     needCount++;
        //     if (this.havePhoto)
        //     {
        //         needHave++;
        //     }
        // }
        //
        // if (this.additions.note)
        // {
        //     needCount++;
        //     if (this.haveNote)
        //     {
        //         needHave++;
        //     }
        // }
        //
        // this.sendDisabled = needHave !== needCount;
    }

    removeFile(event)
    {
        this.answerFile = null;
        this.havePhoto = false;
        // this.sendDisabled = true;

        // let photoContainer = this.template.querySelector('.uploadedPhoto');
        // if (photoContainer !== null)
        // {
        //     photoContainer.src = '';
        // }
    }

    sendAnswer()
    {
        this.waitQuestion = true;

        let answers = this.findOther(this.answer);

        let currentAnswer = answers.find(answer => answer.questionId === this.answer.questionId);
        this.currentQuestion.answer = currentAnswer;

        if (this.haveNote)
        {
            currentAnswer.note = this.issueNote;
        }

        setAnswer({
            jsonAnswers: JSON.stringify(answers),
            jsonFile: this.answerFile !== undefined ? JSON.stringify(this.answerFile) : null,
            note: null})
            .then(result => this.answerProcessor(result, answers));
    }

    answerProcessor(result, answers)
    {

        this.waitQuestion = false;
        this.currentLib.lastQuestionId = null;

        if (result.success)
        {
            answers.forEach(answer => {
                // this.currentQuestion.answered = true;
                let question = this.currentLib.questions.find(question => question.questionId === answer.questionId);
                const questionIndex = this.currentLib.questions
                    .findIndex(question => question.questionId === answer.questionId);
                this.currentLib.answeredQuestions.push(question);
                this.currentLib.questions.splice(questionIndex, 1);
                this.currentLib.status = this.currentLib.answeredQuestions.length + ' / '
                    + (this.currentLib.answeredQuestions.length + this.currentLib.questions.length);
                this.currentLib.completed = this.currentLib.questions.length === 0;
            });

            this.nextQuestion(answers[0].result);
            this.somethingChanges = true;
        } else {
            console.log(result);
        }
    }

    submitAssessment(event)
    {
        this.messageModal.header = 'Submit Assessment';
        this.messageModal.body = 'Are you sure you have completed the assessment and wish to submit?';
        this.messageModal.mode = 'submit';
        this.messageModal.params = {
            resultId: event.target.dataset.targetresult,
            token: localStorage.getItem('exToken')};
        this.messageModal.open = true;
    }

    retakeAssessment(event)
    {
        this.messageModal.header = 'ReTake Assessment';
        this.messageModal.body = 'All your results for this assessment will be cleared. After continue you can find it in the New tab. Do you want to continue?';
        this.messageModal.mode = 'retake';
        this.messageModal.params = {
            resultId: event.target.dataset.targetresult,
            token: localStorage.getItem('exToken')
        };
        this.messageModal.open = true;
    }

    openMessageModal(event)
    {
        if (event.target.dataset.mode === 'answer_change')
        {
            this.messageModal.header = 'Change Answer';
            this.messageModal.body = 'This and all answers after will be wiped. Do you want to continue?';
            this.messageModal.mode = 'answer_change';
            this.messageModal.params = {
                targetResult: this.currentLib.targetResult,
                questionOrder: this.currentQuestion.questionOrder
            }
        }

        this.messageModal.open = true;
    }

    openCompleted(event)
    {
        const libId = event.target.closest('div.open_assessment').dataset.libid;
        const lib = this.currentCompletedAssessment.completedQuestionnaires.find(lib => lib.libId === libId);

        lib.open = !lib.open;

        if (lib.open)
        {
            this.activeLib = lib;
            this.template.querySelectorAll('div.lib[data-libid]').forEach(libNode => {
                libNode.classList.add('slds-hide');
            });

            this.template.querySelector('div.lib[data-libid="' + libId + '"]').classList.remove('slds-hide');
        } else {
            this.activeLib = null;
            this.template.querySelectorAll('div.lib[data-libid]').forEach(libNode => {
                libNode.classList.remove('slds-hide');
            });
        }
    }

    openChangeModal(event)
    {
        const answerId = event.target.dataset.answerid;
        this.openedAnswer = this.activeLib.results.find(answer => answer.answerId === answerId);
        this.waitQuestion = true;
        if (this.openedAnswer.haveImage)
        {
            getAnswerImage({answerId: this.openedAnswer.answerId}).then(result => {
                if (result.success)
                {
                    this.openedAnswer.imageString = result.image;
                } else {
                    console.log(result.error);
                }

                this.waitQuestion = false;
            });
        } else {
            this.waitQuestion = false;
        }
        // this.waitQuestion = true;
        this.changeAttachmentsModal = true;
    }

    closeChangeModal()
    {
        this.openedAnswer = null;
        this.changeAttachmentsModal = false;
    }

    changeAnswerNote(event)
    {
        this.openedAnswer.note = event.target.value;
        this.checkAnswerAttachments();
    }

    checkAnswerAttachments()
    {
        const noteDis = this.openedAnswer.haveNote && this.openedAnswer.note === '';
        const imageDis = this.openedAnswer.haveImage && this.openedAnswer.imageString === null;
        this.changeDisabled = noteDis || imageDis;
    }

    changeAnswer(event)
    {
        this.waitQuestion = true;
        changeAnswer({jsonAnswer: JSON.stringify(this.openedAnswer)}).then(result => {
            if (result.success)
            {
                this.waitQuestion = false;
                this.closeChangeModal();
            } else {
                console.log(result.error);
            }
        })
    }

    removeAnswerImage()
    {
        this.openedAnswer.imageString = null;
        this.checkAnswerAttachments();
    }

    handleAnswerFiles(event)
    {
        this.getBase64(event.target.files[0], true);
    }

    continueFromMessage()
    {
        this.waitQuestion = true;
        switch (this.messageModal.mode)
        {
            case 'submit':
                submitAssessment({params: this.messageModal.params}).then(result =>
                {
                    if (result.success)
                    {
                        this.getAssessmentProcessor(result.result);
                    } else {
                        console.log(result.error);
                        this.connectedCallback();
                    }
                });
                return;
            case 'retake':
                wipeTargetResult({params: this.messageModal.params}).then(result =>
                {
                    if (result.success)
                    {
                        this.getAssessmentProcessor(result.result);
                    } else {
                        this.connectedCallback();
                    }
                });
                return;
            case 'answer_change':
                wipeFromAnswer({params: this.messageModal.params}).then(result =>
                {
                    if (result.success)
                    {
                        this.wipeFromAnswerProcessor(result);
                    }
                })
        }
    }

    wipeFromAnswerProcessor(result)
    {
        result.wipedQuestions.forEach(questionId => {
            let index = this.currentLib.answeredQuestions.findIndex(question => question.questionId === questionId);
            this.currentLib.answeredQuestions[index].answer = null;
            this.currentLib.questions.push(this.currentLib.answeredQuestions[index]);
            this.currentLib.answeredQuestions.splice(index, 1);
        });

        this.currentQuestion.answer = null;
        this.currentLib.haveNext = false;
        this.currentLib.lastQuestionId = null;
        this.mainSpinner = false;
        this.waitQuestion = false;
        this.closeMessageModal();
    }

    closeMessageModal()
    {
        this.messageModal = {
            header: null,
            body: null,
            mode: null,
            open: false,
            params: null
        }
    }

    getBase64(file, answer) {
        let reader = new FileReader();
        reader.readAsDataURL(file);

        reader.onload = () => {
            if (answer)
            {
                this.openedAnswer.imageString = reader.result;
                this.checkAnswerAttachments();
            } else {
                // this.uploadedPhoto = reader.result;
                // this.pdfUploaded = file.type.includes('pdf');
                // this.imageUploaded = file.type.includes('image');
                // this.fileName = file.name;

                this.answerFile = {
                    pdf: file.type.includes('pdf'),
                    image: file.type.includes('image'),
                    base64body: reader.result,
                    fileName: file.name
                }
                // this.pdfUploaded = reader.result
            }
        };
    }

    questionBack(event)
    {
        this.currentLib.haveNext = true;
        if (this.currentLib.lastQuestionId === undefined ||  this.currentLib.lastQuestionId === null)
        {
            this.currentLib.lastQuestionId = this.currentQuestion.questionId;
        }

        if (this.currentLib.answeredQuestions.length === 1)
        {
            this.currentQuestion = this.currentLib.answeredQuestions[0];
        } else {
            for (let i = this.currentLib.answeredQuestions.length - 1; i !== 0; i--)
            {
                if (this.currentLib.answeredQuestions[i].questionOrder < this.currentQuestion.questionOrder &&
                    this.currentLib.answeredQuestions[i].answer !== undefined){
                    this.currentQuestion = this.currentLib.answeredQuestions[i];
                    break;
                }
            }
        }
    }

    questionNext(event)
    {
        let nextQuestion = this.currentLib.answeredQuestions
            .find(question => question.questionOrder > this.currentQuestion.questionOrder &&
                question.answer !== undefined && question.answer !== null);

        if (nextQuestion === undefined)
        {
            nextQuestion = this.currentLib.questions.find(question => question.questionId === this.currentLib.lastQuestionId);
        }

        this.currentQuestion = nextQuestion;
    }

    tabClick(event)
    {
        const tab = event.target.closest('li').dataset.tab;

        this.template.querySelectorAll('li.tab').forEach(node => {
            node.classList.remove('slds-is-active');
        });
        event.target.closest('li').classList.add('slds-is-active');

        this.template.querySelectorAll('.assessments').forEach(node => node.classList.add('slds-hide'));
        this.template.querySelector('.' + tab).classList.remove('slds-hide');
        this.currentActive = tab;
    }
}