/**
 * Created by Razer on 14.02.2020.
 */

import {LightningElement, track} from 'lwc';
import getLibs from '@salesforce/apex/QuestionnarieWizardController.getQuestionnaires';
import deleteQuestion from '@salesforce/apex/QuestionnarieWizardController.deleteQuestion';
import deleteNote from '@salesforce/apex/QuestionnarieWizardController.deleteCustomNote';
import getAdditions from '@salesforce/apex/QuestionnarieWizardController.getQuestionAdditions';
import saveQuestion from '@salesforce/apex/QuestionnarieWizardController.saveQuestion';
import saveLib from '@salesforce/apex/QuestionnarieWizardController.saveQuestionnaire';
import deleteLib from '@salesforce/apex/QuestionnarieWizardController.deleteQuestionnaire';
import getTargets from '@salesforce/apex/QuestionnarieWizardController.getExistingTargets';
import newTarget from '@salesforce/apex/QuestionnarieWizardController.newAssessmentTarget';
import deleteTarget from '@salesforce/apex/QuestionnarieWizardController.deleteTarget';
import newTask from '@salesforce/apex/QuestionnarieWizardController.createTask';
import deleteTask from '@salesforce/apex/QuestionnarieWizardController.deleteTask';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class QuestionnaireWizard extends LightningElement {

    @track libs;
    @track newLibMode;
    @track newLibObject;
    @track newQuestions;
    @track newDisabled = false;
    @track haveLibName;
    @track showSpinner = true;

    @track modalProperties = {
        modalName: 'testName',
        modalTitle: null,
        showModal: false,
        question: null,
        modalBody: {
            recommendation: false,
            note: false,
            noteImage: false
        }
    };

    @track newAssessmentTarget = false;
    @track availableTargets;
    @track targetIdForAdd;
    @track targetSaveDisabled = true;
    @track deleteSpinner = false;

    @track newLibTask;
    @track newTaskProps;
    @track taskSaveDisabled = true;

    deleteInfo = {header: null, body: null};
    openDeleteModal = false;

    additions = null;

    initialKey = 0;

    formats = ['font', 'size', 'bold', 'italic', 'underline',
        'strike', 'list', 'indent', 'align', 'link', 'clean', 'table', 'header', 'color'];

    connectedCallback()
    {
        getLibs().then(result => this.getLibsProcessor(result));
    }

    get getKey()
    {
        this.initialKey++;
        return this.initialKey;
    }

    getLibsProcessor(result)
    {
        this.libs = Object.assign([], result);
        this.openLib(null, this.libs[0]);
        setTimeout(() =>
        {
            this.template.querySelector('.lib_item[data-libid="'+ this.libs[0].libId +'"]').classList.add('lib_item_current');
        }, 0);
        this.showSpinner = false;
    }

    newTarget()
    {
        this.showSpinner = true;
        this.newAssessmentTarget = true;
        let currentTargets = [];
        this.newLibObject.targets.forEach(target => {
            currentTargets.push(target.targetId);
        });

        getTargets({currentTargetIds: currentTargets}).then(result => {
            if (result.length !== 0)
            {
                this.availableTargets = result;
            } else {
                this.newLibObject.newTargetDisabled = true;
                this.showNotification('Nothing To Show', 'There is no availaible targets', 'warning');
                this.closeTargetModal();
            }

            this.showSpinner = false;
        });
    }

    chooseTarget(event)
    {
        const targetId = event.target.dataset.targetid;
        this.template.querySelectorAll('p.modal_target_item').forEach(node => {
            node.classList.remove('item_active');
        });
        this.template.querySelector('p.modal_target_item[data-targetid="' + targetId + '"]').classList.add('item_active');
        this.targetIdForAdd = targetId;
        this.targetSaveDisabled = false;
    }

    saveTarget()
    {
        this.showSpinner = true;
        const params = {
            libId: this.newLibObject.libId,
            targetId: this.targetIdForAdd
        };

        newTarget({params: params}).then(result => {
            if (Object.keys(result).includes('success'))
            {
                const targetIndex = this.availableTargets.findIndex(target => target.targetId === this.targetIdForAdd);
                this.newLibObject.targets.push(this.availableTargets[targetIndex]);
                this.availableTargets = null;
                this.closeTargetModal();
                this.showNotification('Success', 'Successfully added', 'success');
            } else {
                this.showNotification('Error', result.error, 'error');
            }

            this.showSpinner = false;
        })
    }

    deleteTarget(event)
    {
        const dataset = event.target.closest('.remove_target').dataset;
        const targetId = dataset.targetid;
        const targetName = dataset.targetname;

        this.showSpinner = true;

        const params = {
            targetId: targetId,
            libId: this.newLibObject.libId
        };

        this.deleteInfo = {
            mode: 'target',
            params: params,
            header: 'Delete Target',
            body: 'Do you want to Delete ' + targetName + ' from this Questionnaire?'
        };
        this.openDeleteModal = true;
    }

    closeTargetModal()
    {
        this.availableTargets = false;
        this.newAssessmentTarget = false;
    }

    newLib()
    {
        this.showSpinner = true;
        this.newLibObject =
            {
                libId: 'new',
                libName: 'New Questionnaire',
                branches: [{
                    branchId: null,
                    branchName: 'default branch',
                    questions: []
                }],
                allQuestions: [],
                searchResults: [],
                targets: [],
                saveQuestionDisabled: true,
                newTargetDisabled: true,
                newQuestionDisabled: true
            };
        if (this.additions !== null)
        {
            this.newQuestion();
            this.newLibHelper();
        } else {
            getAdditions().then(result => {
                this.additions = result;
                this.newQuestion();
                this.newLibHelper();
            })
        }
    }

    deleteLib(event)
    {
        this.showSpinner = true;
        this.deleteInfo = {
            mode: 'lib',
            header: 'Delete Questionnaire',
            body: 'Do you want to Delete ' + this.newLibObject.libName + '?'
        };
        this.openDeleteModal = true;

    }

    newLibHelper()
    {
        this.newLibObject.allQuestions[0].questionText = 'Default Question';
        this.newLibObject.branches[0].questions.push(this.newLibObject.allQuestions[0]);
        this.libs.unshift(this.newLibObject);
        this.newLibMode = true;
        this.newDisabled = true;
        this.showSpinner = false;
        setTimeout(() =>
        {
            this.template.querySelectorAll('.lib_item').forEach(node =>
            {
                node.classList.remove('lib_item_current');
            });

            this.template.querySelector('.lib_item').classList.add('lib_item_current');
        }, 0);
    }

    setNewLibName(event)
    {
        if (this.newLibObject === null)
        {
            this.newLibObject = {};
        }

        this.newLibObject.libName = event.target.value;
        this.newLibObject.haveChanges = true;
        this.haveLibName = this.newLibObject.libName !== undefined && this.newLibObject.libName !== '';
    }

    openLib(event, lib)
    {
        if (lib === undefined)
        {
            const libId = event.target.dataset.libid;
            this.newLibObject = this.libs.find(lib => lib.libId === libId);
            this.template.querySelectorAll('.lib_item').forEach(node => {node.classList.remove('lib_item_current')});
            this.template.querySelector('.lib_item[data-libid="'+ libId +'"]').classList.add('lib_item_current');
        } else {
            this.newLibObject = lib;
        }
        this.haveLibName = true;
        this.newLibMode = true;
    }

    openQuestion(event)
    {
        const order = Number(event.target.closest('.question_item').dataset.order);
        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);
        question.opened = !question.opened;
    }

    addAddition(event)
    {
        const questionId = event.target.dataset.questionid;
        const addition = event.target.value;
        const mode = event.target.dataset.mode;
        const order = Number(event.target.dataset.order);

        const haveProp = mode === 'yes' ? 'haveYes' : 'haveNo';
        const additionsProp = mode === 'yes' ? 'yesAdditions' : 'noAdditions';

        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);

        let additionIndex = question[additionsProp].findIndex(prop => prop === addition);

        question[additionsProp].splice(additionIndex, 1);
        if (question[haveProp] !== undefined)
        {
            question[haveProp].push(addition);
        } else {
            question[haveProp] = [addition];
        }

        question.haveChange = true;
    }

    removeAddition(event)
    {
        const dataset = event.target.closest('.slds-pill__remove').dataset;
        const questionId = dataset.questionid;
        const addition = dataset.addition;
        const mode = dataset.mode;
        const order = Number(dataset.order);

        const haveProp = mode === 'yes' ? 'haveYes' : 'haveNo';
        const additionsProp = mode === 'yes' ? 'yesAdditions' : 'noAdditions';

        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);

        let additionIndex = question[haveProp].findIndex(prop => prop === addition);

        question[haveProp].splice(additionIndex, 1);

        if (question[additionsProp] !== undefined)
        {
            question[additionsProp].push(addition);
        } else {
            question[additionsProp] = [addition];
        }

        question.haveChange = true;
    }

    deleteQuestion(event)
    {
        const questionId = event.target.dataset.questionid;
        const questionOrder = event.target.dataset.order;
        this.deleteInfo = {
            mode: 'question',
            params: questionId,
            header: 'Delete Question',
            body: 'Do you want to Delete ' + questionOrder + ' from ' + this.newLibObject.libName + '?'};
        this.openDeleteModal = true;
    }

    newQuestion()
    {
        if (this.additions === null)
        {
            getAdditions().then(result => {
                this.additions = result;
                this.newQuestionHelper();
            });
        } else {
            this.newQuestionHelper();
        }
    }

    newQuestionHelper()
    {
        const newQuestion = this.buildEmptyQuestion();
        if (this.newLibObject.allQuestions.length !== 0)
        {
            this.newLibObject.allQuestions.unshift(newQuestion);
        } else {
            this.newLibObject.allQuestions.push(newQuestion);
        }
    }

    buildEmptyQuestion()
    {
        return {
                questionId: null,
                questionOrder: this.newLibObject.allQuestions.length + 1,
                questionnaireId: this.newLibObject.libId,
                yesAdditions: Object.assign([], this.additions),
                haveYes: [],
                noAdditions: Object.assign([], this.additions),
                haveNo: [],
                opened: true,
                textEdit: true,
                yesSkipToId: null,
                yesSkipToText: null,
                noSkipToId: null,
                noSkipToText: null,
                haveYesIssue: false,
                haveNoIssue: false,
                questionRichNotes: [],
                havePrices: true,
                prices: [{}]
            };
    }

    changeQuestionText(event)
    {
        const dataset = event.target.dataset;
        const newText = event.target.value;
        let currentQuestion;

        const order = Number(dataset.order);
        currentQuestion = this.newLibObject.allQuestions.find(question => question.questionOrder === order);

        currentQuestion.tempText = newText;

        if (currentQuestion.questionText !== currentQuestion.tempText )
        {
            currentQuestion.questionText = currentQuestion.tempText;
            currentQuestion.haveChange = true;
        }
    }

    showNotification(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    searchQuestions(event)
    {
        const string = event.target.value.toLowerCase();
        const order = Number(event.target.dataset.order);
        this.newLibObject.yesSkipToText = string;
        this.newLibObject.searchResults = this.newLibObject
            .allQuestions
            .filter(question => question.questionText.toLowerCase().includes(string) && question.questionOrder > order);
    }

    setSearchInputValue(event)
    {
        const dataset = event.target.closest('li').dataset;
        let questionFrom;

        if (dataset.orderfrom === 'none')
        {
            questionFrom = null;
        } else {
            questionFrom = this.newLibObject.allQuestions.find(question => question.questionOrder === Number(dataset.orderfrom));
        }
        let questionTo = this.newLibObject.allQuestions.find(question => question.questionOrder === Number(dataset.orderto));

        let shortName = questionFrom !== null ? questionFrom.shortName : null;
        let questionId = questionFrom !== null ? questionFrom.questionId : null;

        if (dataset.mode === 'no')
        {
            questionTo.noSkipToText = shortName;
            questionTo.noSkipToId = questionId;
        } else {
            questionTo.yesSkipToText = shortName;
            questionTo.yesSkipToId = questionId;
        }
        questionTo.haveChange = true;
        this.hideLIst(event);
    }

    setListVisible(event)
    {
        const order = Number(event.target.dataset.order);
        this.newLibObject.searchResults = this.newLibObject
            .allQuestions
            .filter(question => question.questionOrder > order && question.questionId !== null);
        let controlNode = event.target.closest('.slds-dropdown-trigger_click');
        this.template.querySelectorAll('.slds-dropdown-trigger_click').forEach(node => {
            node.classList.remove('slds-is-open');
            node.setAttribute('aria-expanded', 'true');
        });
        controlNode.classList.add('slds-is-open');
        controlNode.setAttribute('aria-expanded', 'true');
    }

    hideLIst(event)
    {
        let controlNode = event.target.closest('.slds-dropdown-trigger_click');
        controlNode.classList.remove('slds-is-open');
        controlNode.setAttribute('aria-expanded', 'false');
    }

    openModal(event)
    {
        const dataset = event.target.dataset;
        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === Number(dataset.order));

        this.modalProperties.showModal = true;
        this.modalProperties.modalBody[dataset.mode] = true;
        this.modalProperties.question = question;

        if (this.modalProperties.modalBody.prices)
        {
            this.modalProperties.modalName = 'Prices';
            this.modalProperties.modalTitle = 'Will be shown in Estimated Costs Section on dashboards';
        }
        if (this.modalProperties.modalBody.note)
        {
            this.modalProperties.modalName = 'Note';
            this.modalProperties.modalTitle = null;

            if (this.modalProperties.question.questionRichNotes.length === 0)
            {
                this.addNote(event);
            }

        }
        if (this.modalProperties.modalBody.noteImage)
        {
            this.modalProperties.modalName = 'Note With Image';
            this.modalProperties.modalTitle = null;
        }
        if (this.modalProperties.modalBody.recommendation)
        {
            this.modalProperties.modalName = 'Recommendation';
            this.modalProperties.modalTitle = 'Will be shown on dashboards';
        }
        if (this.modalProperties.modalBody.issue)
        {
            this.modalProperties.modalName = 'Question Issue';
            this.modalProperties.modalTitle = 'Will be shown on dashboards';

            if (!this.modalProperties.question.haveYesIssue && !this.modalProperties.question.haveNoIssue)
            {
                this.modalProperties.question.haveNoIssue = true;
            }
        }
    }

    closeModal(event, remove)
    {
        if (this.modalProperties.modalBody.note && !remove)
        {
            if (this.modalProperties.question.questionRichNotes[0].richNoteTitle === '')
            {
                this.showNotification('Erorr', 'You Should fill title or Remove note before Back', 'error');
                return;
            }
            if (this.modalProperties.question.questionRichNotes[0].richNoteBody === '' &&
                (this.modalProperties.question.questionRichNotes[0].image === undefined ||
                    this.modalProperties.question.questionRichNotes[0].image === null))
            {
                this.showNotification('Erorr', 'You Should fill Note Body/upload an Attachment or remove note before Back', 'error');
                return;
            }

        }
        this.modalProperties.showModal = false;
        let keys = Object.keys(this.modalProperties.modalBody);

        keys.forEach(key => {this.modalProperties.modalBody[key] = false});
    }

    changeIssue(event)
    {
        const mode = event.target.dataset.mode;
        if (mode === 'yes')
        {
            this.modalProperties.question.haveYesIssue = !this.modalProperties.question.haveYesIssue;
            this.modalProperties.question.haveNoIssue = false;
        } else {
            this.modalProperties.question.haveNoIssue = !this.modalProperties.question.haveNoIssue;
            this.modalProperties.question.haveYesIssue = false;
        }

        if (!this.modalProperties.question.haveYesIssue && !this.modalProperties.question.haveNoIssue)
        {
            this.modalProperties.question.haveNoIssue = true;
        }

        this.modalProperties.question.currentIssue = this.modalProperties.question.haveYesIssue ?
            this.modalProperties.question.yesIssue : this.modalProperties.question.noIssue;

        this.modalProperties.question.haveChange = true;
    }

    setIssueText(event)
    {
        if (this.modalProperties.question.haveYesIssue)
        {
            this.modalProperties.question.yesIssue = event.target.value;
        } else {
            this.modalProperties.question.noIssue = event.target.value;
        }
        this.modalProperties.question.currentIssue = event.target.value;
        this.modalProperties.question.haveIssue = true;
        this.modalProperties.question.haveChange = true;
    }

    setRecText(event)
    {
        this.modalProperties.question.recommendation = event.target.value;
        if (this.modalProperties.question.recommendation !== undefined && this.modalProperties.question.recommendation !== '')
        {
            this.modalProperties.question.haveChange = true;
            this.modalProperties.question.haveRecommendation = true;
        }
    }

    removeIssueImage(event)
    {
        const mode = event.target.dataset.mode;

        if (mode === 'issue')
        {
            this.modalProperties.question.issueImage = '';
            this.modalProperties.question.haveIssueImage = false;
        }

        if (mode === 'rec')
        {
            this.modalProperties.question.recImage = '';
            this.modalProperties.question.haveRecImage = false;
        }

        if (mode === 'imageNote')
        {
            this.modalProperties.question.noteImage = '';
            this.modalProperties.question.haveNoteImage = false;
        }
        this.modalProperties.question.haveChange = true;
        this.template.querySelector('.uploadedPhoto').src = '';
    }

    changeImageNoteDescription(event)
    {
        this.modalProperties.question.imageNoteDescription = event.target.value;
        this.modalProperties.question.haveIssue = true;
        this.modalProperties.question.haveChange = true;
    }

    handleFiles(event)
    {
        const mode = event.target.dataset.mode;

        let note;

        if (mode === 'richNoteImage')
        {
            note = this.modalProperties.question.questionRichNotes.find(note => note.order === Number(event.target.dataset.order));
        }

        this.getBase64(event.target.files[0], mode, note);

        if (this.template.querySelector('.uploadedPhoto') !== null)
        {
            this.template.querySelector('.uploadedPhoto').src = URL.createObjectURL(event.target.files[0]);
        }
    }

    removeNoteImage(event)
    {
        const order = event.target.dataset.order;
        let note = this.modalProperties.question.questionRichNotes.find(note => note.order === Number(order));
        note.image = null;
        this.modalProperties.question.haveChange = true;
    }

    noteInputChange(event)
    {
        const noteOrder = Number(event.target.closest('.note_block').dataset.noteorder);
        const mode = event.target.dataset.mode;

        let note = this.modalProperties.question.questionRichNotes.find(note => note.order === noteOrder);
        note[mode] = event.target.value;
        this.modalProperties.question.haveChange = true;
    }

    deleteNote(event)
    {
        const noteOrder = Number(event.target.closest('.note_block').dataset.noteorder);
        const noteIndex = this.modalProperties.question.questionRichNotes.findIndex(note => note.order === noteOrder);
        if (this.modalProperties.question.questionRichNotes[noteIndex].richNoteId !== null)
        {
            deleteNote({noteId: this.modalProperties.question.questionRichNotes[noteIndex].richNoteId});
        }

        this.modalProperties.question.questionRichNotes.splice(noteIndex, 1);
        this.modalProperties.question.haveRichNotes = this.modalProperties.question.questionRichNotes.length !== 0;
        this.modalProperties.question.haveChange = true;

        if (this.modalProperties.question.questionRichNotes.length === 0)
        {
            this.closeModal(event, true);
        }
    }


    addNote(event)
    {
        this.modalProperties.question.questionRichNotes.unshift(
            {
                richNote: true,
                richNoteId: null,
                richNoteTitle: '',
                richNoteBody: '',
                order: this.modalProperties.question.questionRichNotes.length,
                forDelete: false
            }
        );

        this.modalProperties.question.haveRichNotes = true;
        this.modalProperties.question.haveChange = true;
    }

    saveQuestion(event)
    {
        this.showSpinner = true;
        const order = Number(event.target.dataset.questionorder);
        const question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);
        if (question.branchId === null || question.branchId === undefined)
        {
            question.branchId = this.newLibObject.defaultBranchId;
        }

        saveQuestion({question: JSON.stringify(question)}).then(result =>
        {
            const error = Object.keys(result).includes('error');
            const newLib = this.newLibObject.libId === 'new';
            if (newLib && !error)
            {
                this.newLibObject.libId = result.newLibId;

                const savedQuestion = this.newLibObject.branches[0].questions.find(
                    question => question.questionOrder === Number(result.questionOrder)
                );
                savedQuestion.questionId = result.questionId;
                savedQuestion.shortName = result.shortText;

                this.newLibObject.newTargetDisabled = false;
                this.newLibObject.newQuestionDisabled = false;
                this.newDisabled = false;
            }
            if (!newLib && !error)
            {
                let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);
                question.haveChange = false;
                question.questionId = result.questionId;
                question.shortName = result.shortText;
                question.opened = false;
                question.textEdit = false;
                this.newLibObject.allQuestions.sort((a, b) => (a.questionOrder > b.questionOrder) ? 1 : -1);
                this.showNotification(null, 'Successfully Saved', 'success');
            }

            if (error)
            {
                this.showNotification('Error', result.error, 'error');
            }
            this.showSpinner = false;
        }
        );
    }

    changePosition(event)
    {
        const mode = event.target.closest('a').dataset.mode;
        const order = Number(event.target.closest('.up_down_block').dataset.order);
        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);

        if (mode === 'up')
        {
            let questionIndexBefore = this.newLibObject.allQuestions.findIndex(q => q.questionOrder === question.questionOrder - 1);
            question.questionOrder = question.questionOrder >  1 ? question.questionOrder - 1 : question.questionOrder;
            if (questionIndexBefore !== -1)
            {
                this.newLibObject.allQuestions[questionIndexBefore].questionOrder = question.questionOrder + 1;
            }

        } else {
            let questionIndexBefore = this.newLibObject.allQuestions.findIndex(q => q.questionOrder === question.questionOrder + 1);

            question.questionOrder = this.newLibObject.allQuestions.length !== question.questionOrder ? question.questionOrder + 1 : question.questionOrder;
            if (questionIndexBefore !== -1)
            {
                this.newLibObject.allQuestions[questionIndexBefore].questionOrder = question.questionOrder - 1;
            }
        }

        this.newLibObject.allQuestions.sort((a, b) => (a.questionOrder > b.questionOrder) ? 1 : -1);
        this.newLibObject.haveChanges = true;
    }

    saveQuestionnaire(event)
    {
        this.showSpinner = true;
        saveLib({libJson: JSON.stringify(this.newLibObject)}).then(result => {
            if (Object.keys(result).includes('success'))
            {
                console.log(result);
                this.newLibObject.haveChanges = false;
                this.newLibObject.saveQuestionDisabled = false;
                this.newLibObject.libId = result.newLibId;

                const savedQuestion = this.newLibObject.allQuestions.find(question => question.questionOrder === Number(result.questionOrder));
                savedQuestion.questionId = result.questionId;
                savedQuestion.shortName = result.shortText;
                savedQuestion.haveChange = false;
                savedQuestion.questionnaireId = result.newLibId;

                this.newDisabled = false;
                this.newLibObject.newQuestionDisabled = false;
                this.newLibObject.newTargetDisabled = false;
                this.libs.splice(0, 1);
                this.libs.push(this.newLibObject);

                setTimeout(() =>
                {
                    this.template.querySelectorAll('.lib_item').forEach(node => {node.classList.remove('lib_item_current')});
                    this.template.querySelector('.lib_item[data-libid="'+ this.newLibObject.libId +'"]').classList.add('lib_item_current');
                }, 0);
                this.showNotification('Success', 'Successfully Saved', 'success');
            } else {
                this.showNotification('Error', result.error, 'error');
            }

            this.showSpinner = false;
        });
    }

    editTextQuestion(event)
    {
        const order = Number(event.target.closest('.up_down_block').dataset.order);
        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);
        question.opened = !question.opened;
        question.textEdit = !question.textEdit;
    }

    changeThreatLevel(event)
    {
        const order = Number(event.target.dataset.order);
        let question = this.newLibObject.allQuestions.find(question => question.questionOrder === order);
        question.threatPoints = event.target.value;
        question.haveChange = true;
    }

    closeDeleteModal()
    {
        this.openDeleteModal = false;
        this.deleteSpinner = false;
        this.showSpinner = false;
        this.deleteInfo = {};
    }

    deleteProcess(event)
    {
        this.deleteSpinner = true;

        if (this.deleteInfo !== undefined)
        {
            switch (this.deleteInfo.mode)
            {
                case "lib":
                    this.deleteLibProcess(event);
                    return;
                case "question":
                    this.deleteQuestionProcess(event);
                    return;
                case "target":
                    this.deleteTargetProcess(event);
                    return;
            }
        }
    }

    deleteTargetProcess(event)
    {
        deleteTarget({params: this.deleteInfo.params}).then(result => {
            if (Object.keys(result).includes('success'))
            {
                const targetIndex = this.newLibObject.targets.findIndex(target => target.targetId === this.deleteInfo.params.targetId);
                this.newLibObject.targets.splice(targetIndex, 1);
                this.showNotification('Success', 'Successfully Removed', 'success');
            } else {
                this.showNotification('Error', result.error, 'error');
            }

            this.showSpinner = false;
            this.deleteSpinner = false;
            this.closeDeleteModal();
        });
    }

    deleteLibProcess(event)
    {
        if (this.newLibObject.libId !== 'new')
        {
            deleteLib({questionnaireId: this.newLibObject.libId}).then(result => {
                if (Object.keys(result).includes('success'))
                {
                    const index = this.libs.findIndex(lib => lib.libName === this.newLibObject.libName);
                    this.libs.splice(index, 1);
                    this.newLibObject = this.libs[0];
                    this.showNotification('Success', 'Questionnaire successfully deleted', 'success');
                } else {
                    this.showNotification('Error', result.error, 'error');
                }

                this.showSpinner = false;
                this.deleteSpinner = false;
                this.closeDeleteModal();
            })
        } else {
            this.showSpinner = false;
            this.deleteSpinner = false;
            this.libs.splice(0, 1);
            this.newDisabled = false;
            this.closeDeleteModal();
            this.newLibObject = this.libs[0];
        }
    }

    deleteQuestionProcess(event)
    {
        if (this.deleteInfo.mode !== undefined)
        {
            this.showSpinner = true;
            deleteQuestion({questionId: this.deleteInfo.params}).then(result => {
                if (result.includes('success'))
                {
                    this.showNotification(
                        'Success',
                        'Successfully deleted',
                        'success'
                    )
                }
                this.showSpinner = false;
                this.closeDeleteModal();
            });
            const index = this.newLibObject.allQuestions.findIndex(question => question.questionId === this.deleteInfo.params);
            this.newLibObject.allQuestions.splice(index, 1);
        } else {
            const order = Number(event.target.dataset.order);
            const index = this.newLibObject.allQuestions.findIndex(question => question.questionOrder === order);
            this.newLibObject.allQuestions.splice(index, 1);
            this.closeDeleteModal();
        }
    }

    closeTaskModal()
    {
        this.newLibTask = false;
        this.newTaskProps = {};
    }

    taskChange(event)
    {
        this.newTaskProps[event.target.dataset.mode] = event.target.value;

        this.taskSaveDisabled = false;
        Object.keys(this.newTaskProps).forEach(prop => {
            if (prop !== 'id' && (this.newTaskProps[prop] === null || this.newTaskProps[prop] === ''))
            {
                this.taskSaveDisabled = true;
            }
        });
    }

    openTask(event)
    {
        const taskId = event.target.closest('div.hover_opacity').dataset.id;
        const task = this.newLibObject.tasks.find(task => task.taskId === taskId);

        this.newTaskProps = {
            id: task.taskId,
            title: task.taskTitle,
            description: task.taskDescription,
            type: task.taskType
        };

        this.newLibTask = true;
    }

    openTaskModal(event)
    {
        this.newTaskProps = {
            id: null,
            title: null,
            description: null,
            type: event.target.dataset.type
        };

        this.newLibTask = true;
    }

    deleteTask(event)
    {
        this.showSpinner = true;
        this.newLibTask = false;
        deleteTask({taskId: this.newTaskProps.id}).then(result => {
            if (Object.keys(result).includes('success'))
            {
                const index = this.newLibObject.tasks.find(task => task.taskId === this.newLibTask.id);
                this.newLibObject.tasks.splice(index, 1);
                this.newTaskProps = {};
                this.showSpinner = false;
            }
        })
    }

    saveTask(event)
    {
        this.showSpinner = true;
        const params = {
            libId: this.newLibObject.libId,
            type: this.newTaskProps.type,
            title: this.newTaskProps.title,
            description: this.newTaskProps.description,
            taskId: this.newTaskProps.id
        };
        this.newLibTask = false;

        newTask({params: params}).then(result => {
            if (Object.keys(result).includes('success'))
            {
                let index;
                if (params.taskId !== null)
                {
                    index = this.newLibObject.tasks.findIndex(task => task.taskId === params.taskId);
                }
                if (this.newLibObject.tasks === undefined)
                {
                    this.newLibObject.tasks = [result.newTask];
                } else {
                    if (index !== undefined)
                    {
                        this.newLibObject.tasks[index] = result.newTask;
                    } else {
                        this.newLibObject.tasks.push(result.newTask);
                    }
                }
                this.showNotification('Success', 'Successfully created', 'success');
            } else {
                this.showNotification('Error', result.error, 'error')
            }
            this.showSpinner = false;
        });
    }

    addPrice(event)
    {
        this.modalProperties.question.prices.push(
            {
                priceFrom: 0,
                priceTo: 0,
                message: null,
                questionId: this.modalProperties.question.questionId,
                priceOrder: this.modalProperties.question.prices.length
            }
        )

        this.modalProperties.question.havePrices = true;
    }

    priceInputChange(event)
    {
        const dataset = event.target.dataset;
        this.modalProperties.question.prices[0][dataset.mode] = event.target.value;
        this.modalProperties.question.haveChange = true;
    }

    removePrice(event)
    {
        const priceIndex = this.modalProperties.question.prices.findIndex(price =>
            price.priceOrder === Number(event.target.dataset.order)
        );

        this.modalProperties.question.prices.splice(priceIndex, 1);
    }

    getBase64(file, mode, note) {
        let reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = () => {
            if (mode === 'issue')
            {
                this.modalProperties.question.issueImage = reader.result;
                this.modalProperties.question.haveIssueImage = true;
                this.modalProperties.question.haveIssue = true;
            }
            if (mode === 'rec')
            {
                this.modalProperties.question.recImage = reader.result;
                this.modalProperties.question.haveRecImage = true;
                this.modalProperties.question.haveRec = true;
            }

            if (mode === 'imageNote')
            {
                this.modalProperties.question.noteImage = reader.result;
                this.modalProperties.question.haveNoteImage = true;
            }
            if (mode === 'richNoteImage')
            {
                note.image = reader.result;
            }
            this.modalProperties.question.haveChange = true;
        };
    }

}