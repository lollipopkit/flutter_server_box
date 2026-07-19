<script lang="ts">
  import { LoaderCircle } from '@lucide/svelte'

  interface Props {
    size?: 'sm' | 'md' | 'lg'
    class?: string
  }

  const { size = 'md', class: className = '' }: Props = $props()

  const sizeClasses = { sm: 'w-4 h-4', md: 'w-8 h-8', lg: 'w-12 h-12' }
</script>

<div class="flex items-center justify-center {className}">
  <LoaderCircle class="animate-spin text-primary-600 {sizeClasses[size]}" />
</div>
