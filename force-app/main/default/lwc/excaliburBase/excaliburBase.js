/**
 * Created by Artsiom.Klimanski on 12/12/2019.
 */

import {LightningElement, api, wire, track} from 'lwc';
import checkToken from '@salesforce/apex/LoginController.checkToken';

export default class ExcaliburBase extends LightningElement {

    @track login;
    @track loginInstructor;
    @track start;
    userName;

    connectedCallback()
    {
        this.checkToken();
    }

    haveLogin(event)
    {
        if (event.detail.login)
        {
            this.login = event.detail.type !== 'Inspector';
            this.loginInstructor = !this.login;
            this.start = false;
        } else {
            this.login = false;
            this.loginInstructor = false;
            this.start = true;
        }

        this.userName = event.detail.userName;
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
                    this.loginInstructor = false;
                    this.start = true;
                } else {
                    localStorage.setItem('exToken', result.newToken);
                    this.login = result.type !== 'Inspector';
                    this.loginInstructor = !this.login;
                    this.start = false;
                    this.userName = result.userName;
                }
            });
        } else {
            this.login = false;
            this.loginInstructor = false;
            this.start = true;
        }
    }

}