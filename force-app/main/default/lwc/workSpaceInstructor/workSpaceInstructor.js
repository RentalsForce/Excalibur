/**
 * Created by Artsiom.Klimanski on 12/13/2019.
 */

import {LightningElement, api, track} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import prolongToken from '@salesforce/apex/LoginController.prolongToken';
import checkToken from '@salesforce/apex/LoginController.checkToken';
import logOut from '@salesforce/apex/LoginController.logOut';
import testavatar from '@salesforce/resourceUrl/default_avatar';
import setNewName from '@salesforce/apex/LoginController.setNewName';
import logo from '@salesforce/resourceUrl/xcalibur_logo'

export default class WorkSpace extends LightningElement {

    avatar = testavatar;

    @api userName;
    @track initialName;
    @track showNameInput = false;
    @track views = {
        assessments: false
    };

    logo = logo;

    connectedCallback()
    {
        setInterval(() => {this.checkToken()}, 100000);
    }

    renderedCallback()
    {
        // prolongToken({token: sessionStorage.getItem('exToken')});
        this.views.assessments = true;
        setTimeout(() => {this.template.querySelector('li.headerItem[data-type="assessments"]').click();}, 0);
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
        this.template.querySelectorAll('li.headerItem').forEach(node => node.style.backgroundColor = '');
        event.target.closest('li').style.backgroundColor = 'snow';

        let type = event.target.closest('li').dataset.type;
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

    refresh(event)
    {
        this.views.assessments = false;
        setTimeout(() => {this.views.assessments = true;}, 0);
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