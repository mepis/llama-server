import { createApp } from 'vue'
import { createRouter, createWebHistory } from 'vue-router'
import { createPinia } from 'pinia'
import './style.css'
import App from './App.vue'

import ScriptsPage from './pages/ScriptsPage.vue'
import ModelsPage from './pages/ModelsPage.vue'
import DocsPage from './pages/DocsPage.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: ScriptsPage },
    { path: '/models', component: ModelsPage },
    { path: '/docs', component: DocsPage },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
  scrollBehavior() {
    return { top: 0 }
  },
})

createApp(App).use(createPinia()).use(router).mount('#app')
