import { afterEach, describe, expect, it } from 'vitest'
import { takeAskedApp } from '../desk/deskState.svelte'

afterEach(() => window.history.replaceState(null, '', '/'))

describe('an app the page was opened for', () => {
  it('is taken once and dropped from the address', () => {
    window.history.replaceState(null, '', '/?app=serverbox.kernel&x=1')
    expect(takeAskedApp()).toBe('serverbox.kernel')
    expect(window.location.search).toBe('?x=1')
    expect(takeAskedApp()).toBeNull()
  })

  it('is no app id otherwise', () => {
    window.history.replaceState(null, '', '/?app=../evil')
    expect(takeAskedApp()).toBeNull()
    expect(window.location.search).toBe('')
  })
})
