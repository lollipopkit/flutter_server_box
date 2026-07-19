<script lang="ts">
  import { cn } from './utils.js'

  interface Props {
    size?: 'sm' | 'md' | 'lg'
    class?: string
  }

  const { size = 'md', class: className }: Props = $props()

  const sizeClasses = { sm: 'w-4 h-4', md: 'w-8 h-8', lg: 'w-12 h-12' }
</script>

<div class={cn('flex items-center justify-center', className)}>
  <svg
    class={cn('animate-spin text-accent', sizeClasses[size])}
    viewBox="0 0 24 24"
    fill="none"
    aria-hidden="true"
  >
    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
    <path
      class="opacity-75"
      fill="currentColor"
      d="M4 12a8 8 0 0 1 8-8v4a4 4 0 0 0-4 4H4z"
    />
  </svg>
</div>
