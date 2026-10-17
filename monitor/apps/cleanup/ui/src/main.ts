import { mount } from 'svelte'
import App from './App.svelte'
import './desk'
import './app.css'

mount(App, { target: document.getElementById('app')! })
