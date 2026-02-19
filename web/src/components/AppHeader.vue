<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const scrolled = ref(false)
const mobileOpen = ref(false)

const navLinks = [
  { to: '/', label: 'Scripts' },
  { to: '/hardware', label: 'Hardware' },
  { to: '/docs', label: 'Docs' },
]

function handleScroll() {
  scrolled.value = window.scrollY > 10
}

onMounted(() => window.addEventListener('scroll', handleScroll))
onUnmounted(() => window.removeEventListener('scroll', handleScroll))
</script>

<template>
  <header
    :class="[
      'sticky top-0 z-50 transition-all duration-300',
      scrolled
        ? 'bg-white/95 backdrop-blur-md shadow-sm border-b border-mint-100'
        : 'bg-white border-b border-transparent'
    ]"
  >
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex items-center justify-between h-16">
        <!-- Logo -->
        <router-link to="/" class="flex items-center gap-3 group">
          <div class="w-8 h-8 rounded-lg bg-mint-500 flex items-center justify-center shadow-sm group-hover:bg-mint-600 transition-colors">
            <svg viewBox="0 0 24 24" fill="none" class="w-5 h-5 text-white" stroke="currentColor" stroke-width="2">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" stroke-linecap="round"/>
              <path d="M8 12l2 2 4-4" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </div>
          <span class="font-semibold text-gray-900 text-lg tracking-tight">
            Llama<span class="text-mint-500">.cpp</span>
          </span>
        </router-link>

        <!-- Desktop Nav -->
        <nav class="hidden md:flex items-center gap-1">
          <router-link
            v-for="link in navLinks"
            :key="link.to"
            :to="link.to"
            class="px-4 py-2 rounded-lg text-sm font-medium transition-all"
            :class="route.path === link.to
              ? 'bg-mint-50 text-mint-700'
              : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'"
          >
            {{ link.label }}
          </router-link>
        </nav>

        <!-- CTA + Mobile toggle -->
        <div class="flex items-center gap-3">
          <a
            href="https://github.com/ggml-org/llama.cpp"
            target="_blank"
            rel="noopener"
            class="hidden sm:flex items-center gap-2 text-sm font-medium text-gray-600 hover:text-gray-900 px-3 py-2 rounded-lg hover:bg-gray-50 transition-all"
          >
            <svg viewBox="0 0 24 24" class="w-4 h-4" fill="currentColor">
              <path d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34-.46-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.87 1.52 2.34 1.07 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.92 0-1.11.38-2 1.03-2.71-.1-.25-.45-1.29.1-2.64 0 0 .84-.27 2.75 1.02.79-.22 1.65-.33 2.5-.33.85 0 1.71.11 2.5.33 1.91-1.29 2.75-1.02 2.75-1.02.55 1.35.2 2.39.1 2.64.65.71 1.03 1.6 1.03 2.71 0 3.82-2.34 4.66-4.57 4.91.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2z"/>
            </svg>
            GitHub
          </a>

          <!-- Mobile hamburger -->
          <button
            @click="mobileOpen = !mobileOpen"
            class="md:hidden p-2 rounded-lg text-gray-600 hover:text-gray-900 hover:bg-gray-50 transition-all"
          >
            <svg v-if="!mobileOpen" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
            <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>
    </div>

    <!-- Mobile menu -->
    <transition name="slide-down">
      <div v-if="mobileOpen" class="md:hidden border-t border-mint-100 bg-white">
        <nav class="flex flex-col p-3 gap-1">
          <router-link
            v-for="link in navLinks"
            :key="link.to"
            :to="link.to"
            @click="mobileOpen = false"
            class="px-4 py-3 rounded-lg text-sm font-medium transition-all"
            :class="route.path === link.to
              ? 'bg-mint-50 text-mint-700'
              : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'"
          >
            {{ link.label }}
          </router-link>
        </nav>
      </div>
    </transition>
  </header>
</template>

<style scoped>
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.2s ease;
}
.slide-down-enter-from,
.slide-down-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
