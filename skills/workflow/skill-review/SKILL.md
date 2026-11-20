---
name: skill-review
description: Reviews one skill against `writing-for-agents` and a greenfield lens — verdicts first, edits after approval, optional trial run in a temp project.
disable-model-invocation: true
argument-hint: "<skill folder> [--trial] [--stack <stack>]"
---

# Skill review

Reviews one skill: the folder named in the arguments. The yardstick is `writing-for-agents`; this file adds the **greenfield** lens, the **coupling** table and the procedure.

## 1. Load the yardstick

Load `writing-for-agents` and its `SKILL-MECHANICS.md`. When the harness has no skill of that name, print the line below and stop.

```bash
npx skills add mattpocock/skills --skill writing-for-agents -g
```

**Done when:** both files are in context.

## 2. Read the target

- Every file in the skill folder.
- **Inbound references**: grep the repository for the skill's name — for a skill outside a repository, the skills directory it sits in; record each `file:line` and the section it names.
- **Outbound references**: every skill, package, tool and file the target names; mark each as present, declared as a prerequisite, or neither.
- The repository's glossary when it has one (`CONTEXT.md`, `GLOSSARY.md`): its terms are binding.

**Done when:** every file of the skill is read, and every inbound and outbound reference is listed.

## 3. Decide whether the skill stays

Choose one outcome and name its ground:

- **Remove**, on any one of: after no-op pruning less remains than its description costs; its decisions already live in a neighbouring or official skill; it serves one past project and does not generalise to a class of task.
- **Merge** into a named skill that owns the same decisions.
- **Split**, by the sequence or invocation cut from `writing-for-agents`.
- **Keep**.

**Done when:** one outcome is chosen with its ground. On remove, go straight to step 5. On merge or split, step 4 judges every block as usual and the report names where each block goes.

## 4. Judge every block

Apply every rule of `writing-for-agents` and `SKILL-MECHANICS.md` to the description and to each block of each file. Then the two lenses of this skill.

**Greenfield**: the reader is an agent in an empty repository holding only this skill. There is no existing code to imitate and no author to ask, so everything it needs to start building is in the skill or behind a pointer the skill declares. A **gap** is a point where that agent has to guess; list every one. The author's decisions stay: what to choose, how to name it, where it goes. A rewrite restates a decision the author made; a decision the skill lacks goes to the gaps. The glossary stays behind in the repository, so a glossary term the skill uses is defined in the skill, in the glossary's words.

**Coupling**: whatever ties the skill to its author or to one past project.

| Kind | What it looks like | Verdict |
| --- | --- | --- |
| Provenance | where and when the rules were harvested, source post ids, the history of a past project | cut |
| Version pin | the tool or library version a rule was checked on | keep |
| Example names | modules, classes and files from one project | keep while the rule is stated without them; a rule that exists only as the example is rewritten as the rule the examples settle, and what they leave open goes to the gaps |
| Author's habits | branch names, ticket id formats, output language, paths of one agent harness | rewrite as a lookup in the repository that falls back to the user's language or the user's answer; a habit with nothing to look up is cut and named in the gaps |
| External dependency | another skill, a package, a CLI | declared in one line as a prerequisite with its install command, or the skill works without it |
| Dangling reference | a pointer to a skill, section or file that does not exist | rewrite to the live target the author meant, or cut and name the lost content in the gaps |
| Glossary conflict | a glossary term used in another meaning | rewrite in the glossary's meaning, or with a word the glossary neither defines nor avoids |

A **block** is a paragraph, a list item, a table row or a code block; a paragraph whose sentences earn different verdicts is judged sentence by sentence. Headings and frontmatter fields other than the description carry no verdict. A piece a rule demands and a block lacks — a completion criterion, a prerequisite line — is a rewrite of that block, and so is moving a block. Each block gets one verdict — **keep**, **cut** or **rewrite** — and every cut or rewrite names its failure mode in the vocabulary of `writing-for-agents` or of the table above.

With `--trial`, read [`TRIAL.md`](TRIAL.md) now and run its baseline before reporting.

**Done when:** the description and every block carry exactly one verdict, and every cut and rewrite has a named failure mode.

## 5. Report and wait

Write the report in the conversation, in the user's language:

1. The outcome of step 3 and its ground.
2. Verdicts: block → verdict → failure mode → what changes, in one line.
3. Gaps.
4. Every file outside the skill folder the edits will touch: inbound references, the repository's skill index and registry.
5. Trial baseline: reds and guesses, when it ran.
6. Not verified: whether the description triggers the skill on its own — a trial hands the skill to the agent.

Then wait. Edits start on the user's explicit yes, and cover only the rows they approved. A gap closes only with the decision the user gives for it; that decision becomes a row.

**Done when:** the report is delivered and the user has answered.

## 6. Apply

Apply the approved rows. A cut deletes the whole sentence or block. A gap the user left unanswered stays open and is listed again in the final message. In the same pass, fix every inbound reference from step 2 and the repository's skill index and registry. Leave everything uncommitted.

With `--trial`, run the confirm loop from [`TRIAL.md`](TRIAL.md).

**Done when:** every approved row is applied, a grep for the skill's name and for each removed or renamed section finds only live targets, and the user has the final `git diff --stat`.
