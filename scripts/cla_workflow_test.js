#!/usr/bin/env node
// Tests the CLA check in .github/workflows/cla.yml against a fake GitHub API.
//
// The workflow cannot be tried out safely on GitHub — a mistake there is a
// mistake in front of a contributor, and half of what it does is refuse things.
// So the script body is lifted straight out of the YAML and run here.
//
//   node scripts/cla_workflow_test.js
//
// No dependencies; any Node with `node:` builtins will do.

'use strict'

const fs = require('node:fs')
const path = require('node:path')

// ---------------------------------------------------------------- the script

const WORKFLOW = path.join(__dirname, '..', '.github', 'workflows', 'cla.yml')

function extractScript(file) {
  const lines = fs.readFileSync(file, 'utf8').split('\n')
  const start = lines.findIndex((l) => /^\s*script:\s*\|\s*$/.test(l))
  if (start === -1) throw new Error(`no "script: |" block in ${file}`)

  const indent = lines[start + 1].match(/^ */)[0].length
  const body = []
  for (let i = start + 1; i < lines.length; i++) {
    const line = lines[i]
    if (line.trim() === '') { body.push(''); continue }
    if (line.match(/^ */)[0].length < indent) break
    body.push(line.slice(indent))
  }
  return body.join('\n')
}

// github-script runs the body as the tail of an async function with `github`,
// `context` and `core` in scope. Reproduce exactly that.
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const runScript = new AsyncFunction('github', 'context', 'core', extractScript(WORKFLOW))

// ------------------------------------------------------------ fake GitHub

function makeWorld() {
  return {
    refs: {},     // 'heads/cla-signatures' -> commit sha
    objects: {},  // sha -> { type, data }
    comments: [],
    statuses: [],
    nextSha: 1,
    nextCommentId: 1,
  }
}

function makeGithub(world, pr, commits) {
  const err = (status) => Object.assign(new Error(`http ${status}`), { status })
  const sha = () => `sha${world.nextSha++}`

  return {
    paginate: async (fn, params) => (await fn(params)).data,
    rest: {
      pulls: {
        get: async () => ({ data: pr }),
        listCommits: async () => ({ data: commits }),
      },
      issues: {
        listComments: async () => ({ data: world.comments }),
        createComment: async ({ body }) => {
          world.comments.push({ id: world.nextCommentId++, body, user: { type: 'Bot' } })
          return { data: {} }
        },
        updateComment: async ({ comment_id, body }) => {
          world.comments.find((c) => c.id === comment_id).body = body
          return { data: {} }
        },
      },
      repos: {
        getContent: async ({ path: p, ref }) => {
          const head = world.refs[`heads/${ref}`] || (world.objects[ref] ? ref : null)
          if (!head) throw err(404)
          const tree = world.objects[world.objects[head].data.tree]
          const entry = tree.data.find((e) => e.path === p)
          if (!entry) throw err(404)
          return {
            data: { content: Buffer.from(world.objects[entry.sha].data, 'utf8').toString('base64') },
          }
        },
        createCommitStatus: async (p) => { world.statuses.push(p); return { data: {} } },
      },
      git: {
        getRef: async ({ ref }) => {
          if (!world.refs[ref]) throw err(404)
          return { data: { object: { sha: world.refs[ref] } } }
        },
        createRef: async ({ ref, sha: s }) => {
          const key = ref.replace('refs/', '')
          if (world.refs[key]) throw err(422)
          world.refs[key] = s
          return { data: {} }
        },
        updateRef: async ({ ref, sha: s }) => { world.refs[ref] = s; return { data: {} } },
        createBlob: async ({ content }) => {
          const id = sha()
          world.objects[id] = { type: 'blob', data: Buffer.from(content, 'base64').toString('utf8') }
          return { data: { sha: id } }
        },
        createTree: async ({ tree }) => {
          const id = sha()
          world.objects[id] = { type: 'tree', data: tree }
          return { data: { sha: id } }
        },
        createCommit: async ({ tree, parents, message }) => {
          const id = sha()
          world.objects[id] = { type: 'commit', data: { tree, parents, message } }
          return { data: { sha: id } }
        },
      },
    },
  }
}

const quiet = { info: () => {}, setFailed: () => {} }

const ctx = (eventName, payload) => ({
  eventName,
  payload,
  repo: { owner: 'lollipopkit', repo: 'flutter_server_box' },
})

// ------------------------------------------------------------------ fixtures

const alice = { login: 'Alice', id: 101, type: 'User' }
const bob = { login: 'bob', id: 202, type: 'User' }
const maintainer = { login: 'lollipopkit', id: 10864310, type: 'User' }
const dependabot = { login: 'dependabot[bot]', id: 999, type: 'Bot' }

const SENTENCE = 'I have read the CLA Document and I hereby sign the CLA'

const commitBy = (user, name, email) => ({
  author: user,
  commit: { author: { name: name || (user && user.login), email: email || 'x@y.z' } },
})

const openPr = (user, number) => ({ state: 'open', user, number, head: { sha: `head${number}` } })

const onPr = (world, pr, commits) =>
  runScript(makeGithub(world, pr, commits), ctx('pull_request_target', { pull_request: pr }), quiet)

const onComment = (world, pr, commits, body, user) =>
  runScript(
    makeGithub(world, pr, commits),
    ctx('issue_comment', {
      issue: { number: pr.number, pull_request: {} },
      comment: { body, user },
    }),
    quiet,
  )

const signatures = (world) => {
  const head = world.refs['heads/cla-signatures']
  if (!head) return null
  const tree = world.objects[world.objects[head].data.tree]
  return JSON.parse(world.objects[tree.data[0].sha].data)
}

const status = (w) => w.statuses[w.statuses.length - 1]
const comment = (w) => (w.comments.length ? w.comments[w.comments.length - 1].body : '')
const fresh = (w) => ({ ...w, comments: [], statuses: [] })

// -------------------------------------------------------------------- runner

let failed = 0
let current = ''
const section = (name) => { current = name; console.log(`\n${name}`) }
const check = (label, cond, detail) => {
  console.log(`  ${cond ? '✓' : '✗'} ${label}`)
  if (!cond) {
    failed++
    if (detail !== undefined) console.log('      got:', JSON.stringify(detail))
  }
}

async function main() {
  section('an unsigned contributor opens a pull request')
  const world = makeWorld()
  const pr1 = openPr(alice, 1)
  await onPr(world, pr1, [commitBy(alice)])
  check('the status fails', status(world).state === 'failure', status(world))
  check('it names Alice', status(world).description.includes('Alice'))
  check('a comment asks her to sign', comment(world).includes('CLA signature required'))
  check('the comment mentions her', comment(world).includes('@Alice'))
  check('nothing is written yet', !world.refs['heads/cla-signatures'])

  section('she signs')
  await onComment(world, pr1, [commitBy(alice)], SENTENCE, alice)
  check('the status passes', status(world).state === 'success', status(world))
  check('the signature branch exists', !!world.refs['heads/cla-signatures'])
  check(
    'its first commit is an orphan',
    world.objects[world.refs['heads/cla-signatures']].data.parents.length === 0,
  )
  const sigs = signatures(world)
  check('one signature is recorded', sigs.signatures.length === 1, sigs)
  check(
    'it holds login, id and pull request',
    sigs.signatures[0].login === 'Alice' &&
      sigs.signatures[0].id === 101 &&
      sigs.signatures[0].pullRequest === 1,
    sigs.signatures[0],
  )
  check('the comment is rewritten, not duplicated', world.comments.length === 1 && comment(world).includes('CLA signed'))

  section('her next pull request')
  const w2 = fresh(world)
  await onPr(w2, openPr(alice, 2), [commitBy(alice)])
  check('passes straight away', status(w2).state === 'success')
  check('with no comment at all', w2.comments.length === 0, w2.comments)

  section('an unsigned co-author appears on a signed contributor’s pull request')
  const w3 = fresh(world)
  await onPr(w3, pr1, [commitBy(alice), commitBy(bob)])
  check('the status fails', status(w3).state === 'failure')
  check(
    'only bob is named',
    status(w3).description.includes('bob') && !status(w3).description.includes('Alice'),
    status(w3).description,
  )

  section('someone else posts the sentence on her pull request')
  const w4 = makeWorld()
  await onComment(w4, openPr(alice, 4), [commitBy(alice)], SENTENCE, bob)
  check('no signature is recorded for anyone', !w4.refs['heads/cla-signatures'])
  check('the status still fails', status(w4).state === 'failure')

  section('the maintainer and bots')
  const w5 = makeWorld()
  await onPr(w5, openPr(maintainer, 5), [commitBy(maintainer), commitBy(dependabot)])
  check('neither has to sign', status(w5).state === 'success', status(w5))
  check('and nothing is posted', w5.comments.length === 0)

  section('a commit whose author is not a GitHub account')
  const w6 = makeWorld()
  await onPr(w6, openPr(maintainer, 6), [
    { author: null, commit: { author: { name: 'Ghost', email: 'ghost@nowhere' } } },
  ])
  check('the status fails', status(w6).state === 'failure', status(w6))
  check('the identity is spelled out', comment(w6).includes('Ghost <ghost@nowhere>'))
  check('with a way to fix it', comment(w6).includes('github.com/settings/emails'))

  section('the sentence quoted inside a longer comment')
  const w7 = makeWorld()
  await onComment(w7, openPr(alice, 7), [commitBy(alice)], `do I just write > ${SENTENCE} ?`, alice)
  check('is not a signature', !w7.refs['heads/cla-signatures'])
  check('and reports nothing', w7.statuses.length === 0, w7.statuses)

  section('the sentence with stray whitespace and a full stop')
  const w8 = makeWorld()
  await onComment(w8, openPr(alice, 8), [commitBy(alice)], `  ${SENTENCE}.\n`, alice)
  check('still signs', !!w8.refs['heads/cla-signatures'])

  section('a bot posting the sentence')
  const w9 = makeWorld()
  await onComment(w9, openPr(alice, 9), [commitBy(alice)], SENTENCE, { ...dependabot, type: 'Bot' })
  check('is ignored', !w9.refs['heads/cla-signatures'])

  section('a recycled login on a different account')
  const w10 = fresh(world)
  const impostor = { login: 'alice', id: 777, type: 'User' }
  await onPr(w10, openPr(impostor, 10), [commitBy(impostor)])
  check('does not inherit the signature', status(w10).state === 'failure', status(w10))

  section('recheck on a pull request that is now fully signed')
  const w11 = fresh(world)
  await onComment(w11, openPr(alice, 11), [commitBy(alice)], 'recheck', bob)
  check('passes', status(w11).state === 'success', status(w11))

  section('a closed pull request')
  const w12 = makeWorld()
  await onPr(w12, { ...openPr(alice, 12), state: 'closed' }, [commitBy(alice)])
  check('is left alone', w12.statuses.length === 0 && w12.comments.length === 0)

  console.log(failed ? `\n${failed} check(s) failed` : '\nall checks passed')
  process.exit(failed ? 1 : 0)
}

main().catch((e) => {
  console.error(`\nthrew during "${current}":`)
  console.error(e)
  process.exit(1)
})
