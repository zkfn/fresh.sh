---
description: Walk me through a recap one item at a time, verified, until I'm caught up
argument-hint: "[optional: a topic, file, or PR to narrow the walk to]"
allowed-tools: Read, Grep, Glob, Bash, TaskCreate, TaskList, TaskGet, TaskUpdate, AskUserQuestion
disable-model-invocation: true
---

Walk me through what just happened, one item at a time. Focus (may be empty): `$1`

I skip between contexts and come back to a wall of caveats and bullet points. I
need to absorb them one by one, not re-read a summary. This is a comprehension
pass, not an implementation pass.

## Rules for the whole walk

- **Do not edit, fix, or refactor anything during the walk.** No Edit, no Write,
  no commits, even if a fix looks trivial and I sound like I want it. The point
  is that I understand the state, not that it changes under me. Fixes come after,
  as a separate ask.
- **One item per turn.** Present a single item, then stop and wait for me. Never
  queue two items in one message, never end a turn with the next item's heading
  already written, and never "briefly cover" the rest at the end.
- **Verify before you explain.** A recap, especially one from a subagent, is a
  claim, not a fact. Open the actual file and read the code before you describe
  a mechanism. Quote the exact lines you are relying on.

## Steps

1. **Find the material.** Default source is the recap, findings list, or caveats
   already in this conversation. If `$1` is given, treat it as a filter (a topic)
   or as the source (a file path, PR number, or branch) and say which reading you
   took. If there is nothing to walk through in context, say so and stop, rather
   than inventing a plausible list.

2. **Cluster it.** Group by mechanism or subsystem, not by the order things were
   listed in. Merge duplicates and near-duplicates into one item, and say they
   were merged. Split an item that quietly bundles two unrelated causes. Aim for
   the smallest number of items that still keeps each cause distinct.

3. **Verify each cluster before the walk starts.** For each one, read the code it
   points at and confirm the claim holds. Mark each as `confirmed`, `partly wrong`
   (say which part), or `could not verify` (say what you would need). Do not
   silently drop an item that fails to verify: it becomes an item about a recap
   that was wrong, which is worth more of my attention, not less.

4. **Put them on the task list.** One `TaskCreate` per cluster, subject in my
   words, description carrying the verification verdict and the file paths, so
   the list survives a compaction. Then tell me how many items there are and
   their one-line titles, so I know the shape of what's coming. Do not start
   item 1 in that same message.

5. **Walk them, hardest or most load-bearing first.** Mark the item `in_progress`
   before you present it. Cover exactly this, in this order, short paragraphs, no
   walls:
   - **Mechanism.** What the code actually does, in plain English.
   - **Where.** `file.ts:42` style, with the lines that matter quoted.
   - **The bug.** What breaks, and the concrete case where it breaks. If it is
     latent and nothing breaks today, say that plainly.
   - **How it surfaced.** Test failure, trace, code read, agent claim? Say which,
     and say plainly if the answer is "a subagent asserted it and I confirmed it
     by reading X".
   - **The fix.** What is proposed, what it costs, and what happens if we do
     nothing. Name the simpler alternative if one exists.
   - **My confidence.** One line, and what would change it.

6. **Stop and check it landed.** End each item with a single question, not a
   quiz: does that land, or do you want the deeper version. Answer whatever I ask
   before moving on. If my reply shows I have the mechanism wrong, re-explain from
   a different angle rather than repeating the same words. Only advance when I
   say to.

7. **Record what I decided.** Before moving on, mark the item `completed` and put
   my call in its description: agreed, disagreed with reason, or deferred. If I
   reject a proposed fix, keep the reason. That record is the output of the walk.

8. **Close.** One short list of the decisions, then one next action: usually the
   agreed fixes, in the order we agreed. Nothing else.
