<script setup>
import AppHeader from './components/AppHeader.vue'
</script>

<template>
  <div class="min-h-screen flex flex-col bg-white font-sans">
    <AppHeader />
    <main class="flex-1">
      <router-view />
    </main>
  </div>
</template>
