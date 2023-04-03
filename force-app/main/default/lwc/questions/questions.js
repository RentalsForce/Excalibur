/**
 * Created by Artsiom.Klimanski on 12/13/2019.
 */

import {LightningElement, track} from 'lwc';
import init from '@salesforce/apex/UserController.getQuestions';

export default class Questions extends LightningElement {

    @track types;

    connectedCallback()
    {
        init().then(result => this.initProcessor(result));
    }

    initProcessor(result)
    {
        this.types = result;
    }
}