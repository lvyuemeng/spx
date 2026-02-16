# Development

This document records the development of `spx`.

## CLI

A CLI has basic functionality.

- Operations: `Verb-Noun` by `<cli> <op> <noun>`.
- Help: `<cli> <op> <help>` or `<cli> <help>`.

Inspect above, we can find that several thing should be achieved:

- parameter deconstruction, a.k.a `parse`.
	- Positional(Sequence)/Flag
- general layered help context.

Parse a parameter can only be identified through **known position** or **flag indication**,
no matter `verb` or `noun`. However, we can't decompose all arguments for whole due to the inefficiency. 
Inspect that `ops` sequence by `<cli> <op^*> <noun^*>` is positional, so we can dispatch recursively 
in each level.

We identify `verb` in each layer and dispatch residual to next layer.

```ps1
# Safety: conanical must be exist
$handle = "$PSScriptRoot/exec/$normal.ps1"
Write-Debug "$handle $($args -join ' ')"
flatten_exec $handle @args
```

And `$handle` will handle its parameters sequence. Finally, we only has `nouns` sequence.
First, suppose we know each flag values, basically: `bool`, `string`, `[string]`, we can
iterate the sequence, the flag is context with type restriction:

[`opts`](/lib/parse.ps1):

- context: identify and store flag.
- in flag context: absorb values greedily by type into the flag.
- not in flag context: absorb values greedily into positional. 

However, if we don't know the type, we can only absorb all values after the flag context greedily
until we reach the next flag. Thus any positional should be placed at first.

Same for `Help`, in each verb layer, we identify whether the next flag is `help`, if so, we force into
`help` prompt. I made it by search the residual **contains** help commands, but thus it force a help prompt
for **this layer** rather dispatch possible next verb-help command, which should be factored.

---

**Caveat**:

- Powershell's `[string]` can only identified with `,` otherwise identified as next positional args
if the rest `@args` exists.
- Unix style `--flag/-f` is not supported by powershell. It's the only choice to use `-Flag` without capital
restriction. 
- `@args` transfer will parsed everything as string elements, the problem is we lose information
about flags, the problem already shown in [Tests](/lib/.Tests.ps1). Thus you can only use `Invoke-Expression`,
but you lose already parsed information causing error on string expansion directly s.t. `System.Object[]` in `@args`. The only way to solve this is to flatten it by [`flatten_exec`](/lib/parse.ps1).

Due to second problem, I manually write the `opts` function but left the positional `[[string]]appNames` to
powershell to parse, which should be factored.

## Side Effect

To interact with file system, we need to conceal side effect into
a pure function with inner mutability. 

## Context

Given a context, which could be global variables(**Dangerous!**) or
conceal hidden access of outer system, like database, file system, IO etc.

In this project, we want to access `scoop` context, `config` context etc.
It should be invariant not by value but by **effect**, e.g. `Get-Scoop` should
provide the path point to `scoop`, even the value changes, the `scoop`-oriented effect
should be invariant with local mutable entity, thus it's a file tree with `apps,persist` etc.

```
effect fn scoop_context(): io ScoopContext {
	val scoop = ...
	{
		...
	}
}
```

Return the scoop context with IO access. In order to record inventory, a.k.a the paths of app,
More effect can be concluded like `raise` if the file tree didn't match.
Then we can separate pure function modularly:

```
# Given the path consistency, join path is safe.
fn scoop_app(scoop_ctx: ScoopContext , app_name: string): path {
	path_join(...)
}

# Given a inventory consistency, look up is safe.
fn get_app_inventory(config_ctx: ConfigContext, key: string): maybe<string> {
	config_ctx.look_up(key)
}
```

In powershell, we can't take effect but only exceptional flow or `$null`, boolean.
More so, as a script language, many effect info are missing, thus a consistent nomination is needed.
For example, if we want `maybe<a>`, return `$a/$null` is only choice, thus we need a function name
with `may_...`. But `raise` is general for any function， if we transform any `raise` into `maybe<a>`,
we will get a huge sequence flow. Thus it's a general effect `raise` for any possible functions.
Then we want to use `Write-Error` with IO output or `-ErrorAction Stop` with a termination.

- For any context, we should immediately shut down without recovering. After context, it's a pure function.
- For any maybe flow, a `maybe<a>` is reasonable with `may_...` notation.
- For any recovering error flow, a `try catch` is needed as effect handle.
- For any effect flow, a function must wrap as a non-effect flow.