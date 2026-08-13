---
description: Teach me a topic one chunk at a time, with prerequisites, steering me off tangents
argument-hint: "<topic I want to understand>"
allowed-tools: Read, Grep, Glob, Bash, WebSearch, WebFetch, TaskCreate, TaskList, TaskGet, TaskUpdate, AskUserQuestion
disable-model-invocation: true
---

Teach me this, in chunks: `$1`

Do not answer this as one long explanation. A wall of text means I read the
first third, start asking questions from there, and we both waste a turn. Give
me one piece, wait, then the next.

## Steps

1. **Sketch the path first.** Before explaining anything, give me the outline:
   the 3-8 concepts we will go through, in dependency order, one line each, plus
   what I will be able to do at the end. `TaskCreate` one task per concept so the
   path survives a compaction and I can see how far in I am. Then stop. Do not
   start concept 1 in that message.

2. **One chunk per turn.** Mark the concept `in_progress`, then give me:
   - **The concept.** A name for it, one line.
   - **Prerequisites.** What has to be straight before this lands. Point at the
     earlier chunk that covered each one. If a prerequisite is outside the
     outline and I probably lack it, say so and offer to detour, do not just
     assume it and carry on.
   - **The explanation.** A paragraph. Plain English, concrete over abstract, one
     example if it earns its place. If it will not fit in a paragraph, that is a
     sign the concept should be split into two chunks: split it.
   - **See it yourself.** One to three commands I can paste to watch the concept
     happen on my own machine, in a fenced block, one per line, with a word on
     what each shows. Say what I should expect in the output *before* I run it,
     and what a surprising result would mean. This is the part that makes it a
     lab and not a cheatsheet, so do not skip it when the topic is observable:
     networks, processes, filesystems, DNS, ports, git state. Skip it only when
     the concept genuinely has nothing to look at, and say so.

   Then stop. Not two chunks, not "and briefly, the next one is". Stop.

3. **Wait for me.** I will say proceed, or I will ask something. Answer what I
   ask under the same one-chunk rule: an answer to a clarifying question is not a
   licence to dump. When the concept is done, mark it `completed`.

4. **Call it when we are running away from the topic.** Say it plainly and early,
   in the first sentence, not after answering at length. Three cases, each with a
   different move:
   - **Cycling.** We have covered this from another angle already. Say so, name
     the chunk where we did, and ask what specifically did not land, rather than
     re-explaining the same way.
   - **Diverging.** A real question, wrong time, not on the path to what I asked
     for. Say it is off-path, `TaskCreate` it as an open question so it is not
     lost, and offer it at the end.
   - **Premature.** It is answered by a later chunk. Say which one, give me the
     one-line version so I am not stuck, and move on.

   In all three, do the same two things before continuing: tell me **what is
   enough to know to proceed** in a sentence or two, and **name the next chunk**
   so I can see the path is still there. Then wait for me to say go.

5. **Do not be talked into the dump.** If I say "just give me everything", give
   me the outline plus the first chunk and remind me I asked for it this way.
   If I insist a second time, drop the chunking and explain it straight through.

6. **Close.** When the outline is done, list the open questions parked in step 4
   and ask which to take. Nothing else, no summary of what we covered.

## Constraints

- **Explanation only.** No Edit, no Write, no commits. If understanding the topic
  needs the actual code, read it and quote the lines, do not rewrite it.
- **The commands you hand me must be safe to paste and must exist.** Read-only
  inspection, never anything that changes state: `docker network inspect`, not
  `docker network rm`. Mark the ones needing `sudo`. Check the tool is actually
  installed here before recommending it rather than assuming, and give the
  modern spelling with the old one as a fallback, not the reverse, since the
  classic tools are often missing on a current distro (`ip addr` before
  `ifconfig`, `ss` before `netstat`). If a command only makes sense with my real
  values in it, say which parts I substitute.
- **Offer to run them too.** I may want to paste the output back and have you
  read it with me. Interpret it against what you predicted, and say plainly when
  the real output contradicts the explanation you just gave.
- **Say what you are unsure of**, in the chunk where it comes up, not at the end.
  If a chunk rests on something you have not verified in this repo or read from a
  real source, say which and how confident you are.
