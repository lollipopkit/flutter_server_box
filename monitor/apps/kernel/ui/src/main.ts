import { mount } from 'svelte'
import App from './App.svelte'
import '$common/desk'
import '$common/page.css'

mount(App, { target: document.getElementById('app')! })
