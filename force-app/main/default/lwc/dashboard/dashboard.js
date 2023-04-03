/**
 * Created by Artsiom.Klimanski on 12/13/2019.
 */

import {LightningElement, track} from 'lwc';
import getAssessments from '@salesforce/apex/UserController.getTargetResults';
import blue from '@salesforce/resourceUrl/diagram_blue';
import green from '@salesforce/resourceUrl/diagram_green';
import orange from '@salesforce/resourceUrl/diagram_orange';
import red from '@salesforce/resourceUrl/diagram_red';
import yellow from '@salesforce/resourceUrl/diagram_yellow';

export default class Dashboard extends LightningElement {

    @track currentTarget;
    @track currentResult;
    dashboardImages = {
        blue: blue,
        green: green,
        orange: orange,
        red: red,
        yellow: yellow
    };

    connectedCallback()
    {
        getAssessments({token: localStorage.getItem('exToken')}).then(result => this.getAssessmentsProcessor(result));
    }

    getAssessmentsProcessor(result)
    {
        this.currentTarget = result;
        this.currentResult = result.targetResults[0];
        this.currentResult.imageUrl = this.dashboardImages[this.currentResult.imageName];
        setTimeout(() => {
            this.template.querySelector('li.tab').classList.add('slds-is-active');
        }, 0);
    }

    tabClick(event)
    {
        const currentTab = event.target.dataset.tab;
        this.template.querySelectorAll('li.tab').forEach(node => {
            node.classList.remove('slds-is-active');
        });
        event.target.closest('li').classList.add('slds-is-active');

        this.currentResult = this.currentTarget.targetResults.find(result => result.resultId === currentTab);
        this.currentResult.imageUrl = this.dashboardImages[this.currentResult.imageName];
    }

    pdfRedirect(event)
    {
        const url = 'https://www.excalibur.biz/targetreport?targetId='
            + this.currentTarget.targetId
            + '&libId='
            + this.currentResult.libId;

        window.open(url, '_blank');
    }
}