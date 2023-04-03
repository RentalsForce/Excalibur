/**
 * Created by Artsiom.Klimanski on 12/13/2019.
 */

import {api, LightningElement, track} from 'lwc';
import prolongToken from '@salesforce/apex/LoginController.prolongToken';
import checkToken from '@salesforce/apex/LoginController.checkToken';
import logOut from '@salesforce/apex/LoginController.logOut';
import testavatar from '@salesforce/resourceUrl/default_avatar'
import logo from '@salesforce/resourceUrl/xcalibur_logo'
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import setNewName from '@salesforce/apex/LoginController.setNewName';

export default class WorkSpace extends LightningElement {

    avatar = testavatar;

    @api userName;
    @track initialName;
    @track showNameInput = false;
    @track views = {
        dashboards: false,
        forms: false,
        services: false,
        tasks: false,
        questions: false,
    };

    componentInitialized = false;

    logo = logo;
    connectedCallback()
    {
        setInterval(() => this.checkToken(), 100000);
    }

    renderedCallback()
    {
        prolongToken({token: localStorage.getItem('exToken')});
        if (!this.componentInitialized){
            this.validateUrl();
        }
    }

    validateUrl()
    {
        const url = window.location.href;
        if (url.includes('dashboards'))
        {
            // this.template.querySelector('li.headerItem[data-type=dashboards]').click();
        }
        setTimeout(() => {this.template.querySelector('li.tabItem[data-type="dashboards"]').click();}, 0);
        this.componentInitialized = true;
    }

    checkToken()
    {
        let token = localStorage.getItem('exToken');

        if (token !== undefined && token !== null)
        {
            checkToken({token: token}).then(result => {
                if (result.expired)
                {
                    localStorage.removeItem('exToken');
                    this.login = false;
                    this.dispatchEvent(new CustomEvent('login', {detail: {login: false}}));
                } else {
                    localStorage.setItem('exToken', result.newToken);
                    this.login = true;
                }
            });
        } else {
            this.login = false;
            this.dispatchEvent(new CustomEvent('login', {detail: {login: false}}));
        }
    }

    changeComponent(event)
    {
        let type = event.target.closest('li').dataset.type;
        // this.template.querySelectorAll('li.headerItem').forEach(node => node.style.backgroundColor = '');
        this.template.querySelectorAll('li.tabItem').forEach(node => node.classList.remove('slds-is-active'));
        let targetNode = event.target.closest('li');

        if (targetNode.classList.contains('headerItem'))
        {
            targetNode.style.backgroundColor = 'lightseagreen';
            this.template.querySelector('li.tabItem[data-type=' + type + ']').classList.add('slds-is-active');
        } else {
            targetNode.classList.add('slds-is-active');
            // this.template.querySelector('li.headerItem[data-type='+ type + ']').style.backgroundColor = 'lightseagreen';
        }

        let keys = Object.keys(this.views);

        keys.forEach(key => {this.views[key] = false});

        this.views[type] = true;
    }

    logOut()
    {
        logOut({token: localStorage.getItem('exToken')});
        this.login = false;
        this.dispatchEvent(new CustomEvent('login', {detail: {login: false}}));
    }

    changeName()
    {
        this.showNameInput = true;
    }

    nameInputChange(event)
    {
        this.initialName = event.target.value;
    }

    setNewName()
    {
        if (this.initialName === '' || this.initialName === undefined)
        {
            this.showNotification('Error', 'You should enter new Name', 'error');
        } else {
            setNewName({name: this.initialName, token: localStorage.getItem('exToken')}).then(result => {
                if (result.success)
                {
                    this.userName = this.initialName;
                    this.showNameInput = false;
                    this.showNotification('Success', 'Name was successfully changed', 'success');
                } else {
                    this.showNotification('Error', result.message, 'error');
                }
            })
        }
    }

    closeChange()
    {
        this.showNameInput = false;
    }

    showNotification(title, message, variant)
    {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

}