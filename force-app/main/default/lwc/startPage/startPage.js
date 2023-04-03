/**
 * Created by Artsiom.Klimanski on 12/12/2019.
 */

import {LightningElement, track} from 'lwc';
import checkCredentials from '@salesforce/apex/LoginController.checkCredentials';
import checkEmail from '@salesforce/apex/LoginController.sendPasswordEmail';
import background from '@salesforce/resourceUrl/home_page_background'

export default class StartPage extends LightningElement {

    @track loginModal = true;
    @track passwordInvalid = true;
    @track failedCredentials = false;
    @track failMessage;
    @track inspector;
    @track userName;
    forgot = false;
    forgotSuccess = false;
    forgotFail = false;
    afterForgot = false;
    inputs = {};

    connectedCallback()
    {
    }

    loginModalVisibility()
    {
        this.loginModal = !this.loginModal;
        this.backToLogin();
    }

    login()
    {
        if (this.validateCredentials())
        {
            this.inputs.remember = this.inputs.remember ? '1' : '0';
            checkCredentials({credentials: this.inputs}).then(result => this.loginProcessor(result));
        }
    }

    loginProcessor(result)
    {
        console.log(result);
        if (result.failed)
        {
            this.failMessage = result.message;
            this.failedCredentials = true;
        } else {
            localStorage.setItem('exToken', result.token);
            this.dispatchEvent(new CustomEvent('login', {detail: {login: true, type: result.type, userName: result.userName}}));
        }
    }


    validateCredentials()
    {
        let valid = false;
        if (this.inputs.login !== undefined && this.inputs.login !== null)
        {
            this.template.querySelector('.loginInput').classList.remove('slds-has-error');
            valid = true;
        } else {
            this.template.querySelector('.loginInput').classList.add('slds-has-error');
        }
        if (this.inputs.password !== undefined && this.inputs.password !== null)
        {
            this.template.querySelector('.passwordInput').classList.remove('slds-has-error');
            valid = true;
        } else {
            this.template.querySelector('.passwordInput').classList.add('slds-has-error');
        }

        return valid;
    }

    inputChange(event)
    {
        if (event.target.dataset.type === 'remember')
        {
            this.inputs[event.target.dataset.type] = !this.inputs[event.target.dataset.type];
        } else {
            this.inputs[event.target.dataset.type] = event.target.value;
        }

        this.forgotFail = false;
    }

    get backgroundStyle()
    {
        return 'background-image:url(' + background + ')';
    }

    forgotPassword()
    {
        this.forgot = !this.forgot;
        this.afterForgot = true;
    }

    checkEmailLogin()
    {
        checkEmail({email: this.inputs.email}).then(result => {
            if (result.success)
            {
                this.afterForgot = false;
                this.forgotSuccess = true;
            } else {
                this.forgotFail = true;
                this.forgotSuccess = false;
            }
        })
    }

    backToLogin()
    {
        // this.forgot = false;
        // this.afterForgot = false;
        window.location.href = 'https://www.excalibur.biz';
    }


}