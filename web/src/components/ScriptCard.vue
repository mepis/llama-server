<script setup>
defineProps({
  script: { type: Object, required: true },
})

const emit = defineEmits(['click'])
</script>

<template>
  <div
    @click="emit('click', script)"
    class="group relative bg-white border border-gray-100 rounded-2xl p-6 cursor-pointer hover:border-mint-200 hover:shadow-lg hover:shadow-mint-50 transition-all duration-200"
  >
    <!-- Icon -->
    <div
      class="w-11 h-11 rounded-xl flex items-center justify-center mb-4 transition-colors"
      :class="script.iconBg"
    >
      <component :is="script.icon" class="w-5 h-5" :class="script.iconColor" />
    </div>

    <!-- Content -->
    <h3 class="font-semibold text-gray-900 mb-1.5 group-hover:text-mint-700 transition-colors">
      {{ script.name }}
    </h3>
    <p class="text-sm text-gray-500 leading-relaxed mb-4">
      {{ script.description }}
    </p>

    <!-- Tags -->
    <div class="flex flex-wrap gap-1.5">
      <span
        v-for="tag in script.tags"
        :key="tag"
        class="text-xs font-medium px-2 py-0.5 rounded-full bg-gray-50 text-gray-500 border border-gray-100"
      >
        {{ tag }}
      </span>
    </div>

    <!-- Arrow -->
    <div class="absolute top-5 right-5 opacity-0 group-hover:opacity-100 transition-opacity">
      <svg class="w-4 h-4 text-mint-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M5 12h14M12 5l7 7-7 7" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>
  </div>
</template>
