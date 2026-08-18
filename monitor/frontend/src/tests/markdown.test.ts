import { describe, it, expect } from 'vitest'
import { render } from '@testing-library/svelte'
import Markdown from '../components/Markdown.svelte'

/// The component renders with `{@html}`, which is only safe because the input
/// is escaped before snarkdown sees it. That escaping is the whole reason the
/// lint rule is suppressed there, so it is worth a test rather than a comment.
describe('Markdown', () => {
  it('renders the markdown it is given', () => {
    const { container } = render(Markdown, {
      props: { text: '**bold** and `code` and [link](https://a.example)' },
    })
    expect(container.querySelector('strong')?.textContent).toBe('bold')
    expect(container.querySelector('code')?.textContent).toBe('code')
    expect(container.querySelector('a')?.getAttribute('href')).toBe('https://a.example')
  })

  it('does not let markup in the input reach the DOM', () => {
    // snarkdown escapes inside code spans but passes raw HTML through
    // everywhere else, so without the escaping step this would be a real tag
    const { container } = render(Markdown, {
      props: { text: 'hi <img src=x onerror=alert(1)> there' },
    })
    expect(container.querySelector('img')).toBeNull()
    expect(container.textContent).toContain('<img src=x onerror=alert(1)>')
  })

  it('escapes a script tag rather than executing it', () => {
    const { container } = render(Markdown, {
      props: { text: '<script>window.__xss = 1</script' + '>' },
    })
    expect(container.querySelector('script')).toBeNull()
    expect((window as unknown as Record<string, unknown>).__xss).toBeUndefined()
  })

  it('still shows comparison operators as text', () => {
    // The rule-help strings contain `(<, <=, =, >=, >)`; they must read as
    // characters, not disappear into a half-parsed tag
    const { container } = render(Markdown, {
      props: { text: 'comparator `(<, <=, =, >=, >)` here' },
    })
    expect(container.querySelector('code')?.textContent).toBe('(<, <=, =, >=, >)')
  })
})
