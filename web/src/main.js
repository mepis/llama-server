import { createApp } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import './style.css'
import App from './App.vue'

import ScriptsPage from './pages/ScriptsPage.vue'
import HardwarePage from './pages/HardwarePage.vue'
import DocsPage from './pages/DocsPage.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: ScriptsPage },
    { path: '/hardware', component: HardwarePage },
    { path: '/docs', component: DocsPage },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
  scrollBehavior() {
    return { top: 0 }
  },
})

createApp(App).use(router).mount('#app')
