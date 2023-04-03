/**
 * Created by Artsiom.Klimanski on 12/13/2019.
 */

import {LightningElement, track} from 'lwc';
import getAssessments from '@salesforce/apex/UserController.getTasksInfo';
import uploadTaskPhoto from '@salesforce/apex/UserController.uploadTaskPhoto';

export default class Tasks extends LightningElement {

    @track tasksCards;
    @track haveTasks = false;

    connectedCallback()
    {
        getAssessments({token: localStorage.getItem('exToken')}).then(result => this.tasksProcessor(result));
    }

    tasksProcessor(result)
    {
        this.tasksCards = result;
        this.haveTasks = result.length > 0;
    }

    handleFiles(event)
    {
        let target = event.target;
        const targetId = target.dataset.targetid;
        const photoUrl = URL.createObjectURL(event.target.files[0]);

        this.template.querySelector('.uploadedPhoto[data-targetid=' + targetId + ']').src = photoUrl;

        let targetTask = this.tasksCards.find(card => card.targetId === targetId);
        let taskItem = targetTask.tasks.find(task => task.taskId === targetTask.activeTaskId);
        targetTask.haveCurrentPhoto = true;
        targetTask.currentPhotoBlob = photoUrl;
        taskItem.haveCurrentPhoto = true;
        taskItem.currentPhotoBlob = photoUrl;
        this.getBase64(event.target.files[0], taskItem);
    }

    removePhotoFromTarget(event)
    {
        const targetId = event.target.dataset.targetid;
        this.template.querySelector('.uploadedPhoto[data-targetid=' + targetId + ']').src = '';

        let targetTask = this.tasksCards.find(card => card.targetId === targetId);
        let taskItem = targetTask.tasks.find(task => task.taskId === targetTask.activeTaskId);
        targetTask.haveCurrentPhoto = false;
        targetTask.currentPhotoBlob = null;
        taskItem.currentPhotoBlob = null;
        taskItem.haveCurrentPhoto = false;
    }

    tryToSend(event)
    {
        const targetId = event.target.dataset.targetid;
        let currentCard = this.tasksCards.find(card => card.targetId === targetId);
        let taskItem = currentCard.tasks.find(task => task.taskId === currentCard.activeTaskId);
        uploadTaskPhoto({jsonTask: JSON.stringify(taskItem)}).then(result => this.connectedCallback());
    }

    getBase64(file, taskItem) {
        let reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = () => {taskItem.currentPhotoString = reader.result};
    }

    taskClick(event)
    {
        let currentTaskHolder = event.target.closest('.tasksHolder');
        let currentTaskItem = event.target.closest('.taskItem');

        const targetId = currentTaskHolder.dataset.taskid;
        const taskItemId = currentTaskItem.dataset.itemid;

        currentTaskHolder.childNodes.forEach(node => {
            node.classList.contains('taskItem') ? node.classList.remove('activeTask') : '';
        });
        currentTaskItem.classList.add('activeTask');

        let currentCard = this.tasksCards.find(card => card.targetId === targetId);
        let currentTask = currentCard.tasks.find(task => task.taskId === taskItemId);
        currentCard.showAction = true;
        currentCard.showPhoto = currentTask.photo;
        currentCard.showSchedule = currentTask.meeting;
        currentCard.calendyLink = currentTask.calendyLink;
        currentCard.redirected = currentTask.redirected;
        currentCard.activeTaskId = taskItemId;
        currentCard.currentCompleted = currentTask.completed;
        currentCard.haveTime = currentTask.haveTime;
        currentCard.meetingTime = currentTask.meetingTime;
        currentCard.meetingDate = currentTask.meetingDate;
        currentCard.meetingTimeFrom = currentTask.meetingTimeFrom;
        currentCard.meetingTimeTo = currentTask.meetingTimeTo;

        if (currentTask.haveCurrentPhoto || currentCard.currentCompleted)
        {
            currentCard.haveCurrentPhoto = true;
            currentCard.currentPhotoBlob = currentCard.currentCompleted ? currentTask.currentPhotoString : currentTask.currentPhotoBlob;
            this.template.querySelector('.uploadedPhoto[data-targetid=' + targetId + ']').src = currentCard.currentPhotoBlob;
        } else {
            currentCard.haveCurrentPhoto = false;
            currentCard.currentPhotoBlob = null;
            this.template.querySelector('.uploadedPhoto[data-targetid=' + targetId + ']').src = '';
        }
    }

    redirectToSchedule(event)
    {
        const dataset = event.target.dataset;
        const target = this.tasksCards.find(card => card.targetId === dataset.targetid);
        const task = target.tasks.find(task => task.taskId === dataset.taskid);

        task.redirected = true;
        target.redirected = true;
        window.open(task.calendyLink, '_blank');
    }


}