import { createApp } from 'vue'
import { createRouter, createWebHashHistory } from 'vue-router'
import './style.css'
import App from './App.vue'

import HomePage from './pages/HomePage.vue'
import ScriptsPage from './pages/ScriptsPage.vue'
import HardwarePage from './pages/HardwarePage.vue'
import DocsPage from './pages/DocsPage.vue'

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/', component: HomePage },
    { path: '/scripts', component: ScriptsPage },
    { path: '/hardware', component: HardwarePage },
    { path: '/docs', component: DocsPage },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
  scrollBehavior() {
    return { top: 0 }
  },
})

createApp(App).use(router).mount('#app')
