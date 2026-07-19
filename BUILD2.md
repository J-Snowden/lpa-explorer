# Build Spec v2: Latent Profile Explorer — Restructure

`index.html` is being rebuilt from scratch. The previous version was
technically correct and rhetorically dead: it opened with an 18-row grid of fit
indices and asked the reader to care about a model-selection decision before
establishing that anything was at stake. This version inverts that.

The R pipeline is unchanged except for new segmentation output. Re-run all
three scripts, then build against the regenerated
`data/model_results.json`.

---

## Provenance — this is not a toy

The most credible thing available to this page is that the pipeline is real.
It was built for a peer-reviewed study of 1,698 middle and high school
students and presented at AERA 2026. What is synthetic is the data, and only
because the real responses belong to the research organization and were
collected from minors under IRB protocols.

This must be established before any analysis appears. A reader who does not
know the provenance reads the whole page as a classroom exercise.

**Cite the study; do not host the paper.** There is no PDF to link and none
should be added. The citation alone establishes provenance.

**Attribution requirements, non-negotiable:**

- Cite the full author list wherever the paper is referenced: Herrmann Abell,
  C. F., Deverel-Rico, C., Snowden, J., Brubaker, A., Campanella, M.,
  Flanagan, J., Lee, D., Olson, P., & Wilson, C. D. (2026). *Centering Student
  Voice in Science Assessment through Leveraging Student Experience Data.*
  AERA Annual Meeting, Los Angeles.
- Note the co-equal first authorship (Herrmann Abell, Deverel-Rico, Snowden).
- State specifically what this author contributed — the factor analysis, the
  latent profile analysis, and the model selection — rather than implying sole
  authorship of a nine-author study.
- Never imply the synthetic results are the study's findings. They are a
  reconstruction of the method.

---

## The argument the page makes

One claim, and everything on the page serves it:

> Employee listening programs segment by what the HRIS provides — department,
> tenure, level. Those cuts are nearly flat. The people having the worst
> experience are distributed evenly across every one of them, so no dashboard
> the organization already has will ever surface them.

The supporting numbers are in `segmentation` in the JSON. The headline is
`segmentation.ratio`: the widest gap any conventional segmentation produces,
against the widest gap the profile solution produces. Read it from the JSON —
do not hardcode it.

The reader should leave able to repeat the claim. Everything methodological is
in service of it, not the other way round.

---

## Structure

Four sections, in this order. The methodology that used to open the page now
sits at the end, collapsed.

### Section 0 — Where this came from

Short. Three or four sentences, before anything analytical.

The arc: a research team asked 1,698 students how a science test *felt* —
not whether they passed. The answers sorted into four kinds of experience.
The students having the worst time were not identifiable in advance from any
demographic characteristic the team examined; the profiles cut clean across
every group. That finding is what this page reconstructs, in an employee
context, on synthetic data.

Then the transfer, stated rather than implied: student assessment experience
and employee experience are the same measurement problem. Both ask people how
something felt, both need the instrument validated before the answers mean
anything, and both are usually analyzed by segmenting into groups defined in
advance — which is the habit this page is about.

Cite the study here, in full. Say the data are synthetic here. Do not bury
either in a footer.

### Section 1 — The conventional view

Lead with the thing every listening team already does. Small multiples or a
simple grouped display: mean factor score by department, by tenure, by level,
using `segmentation.segments`. Fixed y-axis spanning roughly −1.5 to +1.5 —
the same axis Section 2 will use, because the visual point is that these lines
are flat *on the scale where the profile differences are large*.

Caption states the widest gap available under any conventional cut, in SD,
pulled from `segmentation.max_conventional`.

One line of framing above it, plain: this is what the dashboard looks like.
Nothing here tells you what to do.

### Section 2 — The people the dashboard cannot see

**A prominent toggle, not a buried click target.** Two states: "Segment by org
attribute" and "Segment by experience profile." Same data, same axis, same
chart type. Flipping it makes the signal appear.

This is the single most important interaction on the page. It should be large,
obviously interactive, and positioned so a reader cannot miss it. Default to
the conventional view so the reader experiences the reveal.

In profile state: the four profile lines across the five factors, structural
factors first (Clarity, Enablement) then affective (Engagement, Impact,
Autonomy) so the fanning reads left to right. Profile sizes and AvePP
alongside.

Then the finding that makes it matter, from `segmentation.association`: profile
membership shows no significant association with department, tenure, or level
after Holm correction — Cramér's V values in the JSON, all small. Show the
composition data (`segmentation.composition`) as a compact stacked bar per
department: every department contains roughly the same profile mix.

State the consequence directly. Roughly 19% of respondents are in the Low
Engagement profile. They are in every department in about the same proportion.
No org-chart cut finds them.

### Section 3 — How many kinds of experience?

**Three large buttons: 3 / 4 / 5 profiles.** Changing k must change *the
recommendation text*, not only the chart. That is what gives the click stakes.

- **k = 3** — the Low group dissolves into a broad moderate band. The 266
  people with the worst experience stop being a distinguishable population,
  and nothing would be staffed for them.
- **k = 4** — retained. Low Engagement is 19% and separable, with AvePP above
  .90; an intervention can be aimed at it.
- **k = 5** — splits the middle further. The additional class is small and
  its separation from its neighbours is weak; it would not survive being
  briefed to a stakeholder.

Show the profile plot for the selected k alongside the recommendation. Profile
labels for k = 3 and k = 5 are neutral ("Profile 1..k") in the JSON — use them
as-is rather than inventing engagement labels.

Below the recommendation, a single line: this choice is a judgement, and the
evidence behind it is in Section 5.

### Section 4 — Who answers the "what's wrong" question

The existing response-behavior panel worked and needs no structural change.
Keep the shared-scale bars and the closing note.

Add one sentence connecting it to the page's argument: the same blindness
applies to comment analysis — the people with the fewest problems don't answer
the "what's wrong" prompt, so the corpus overrepresents the disengaged.

### Section 5 — The evidence behind the choice (collapsed by default)

Everything currently in Panel 1 goes here behind a disclosure control labelled
something like "The model selection, in full."

Inside, unchanged in substance: the 18-model grid, the four criterion cards,
and the prose on what each criterion does and does not settle. Two fixes to
carry over:

- **Add Δ BIC and % of previous step as columns** to the Model 2 block, from
  `selection.bic_delta` and `selection.pct_of_prev`, and put the bar on the
  percentage rather than on absolute BIC. The elbow is about rate of change;
  bars scaled to absolute BIC make k=4 and k=5 look identical.
- **Mark Model 3, k = 5 as non-converged.** It shows min class 0.0% and
  BLRT p = 1.0000, and tidyLPA warned on that cell. An unlabelled 0.0 reads as
  a rendering bug.

Also include the CFA fit and the split-sample logic here, briefly. A reader who
opens this section wants to know the measurement model was validated before the
profiles were extracted.

---

## Presentation

Carry over what worked from v1 — the restraint, the type hierarchy, the
figure-like framing. Three fixes:

- **Widen the profile colour ramp.** Four near-identical blues cannot be
  matched to their table rows. Near-white for High down to a dark muted blue
  for Low, and make every legend swatch match its line.
- **Shorten the opening.** The current header carries a title, a subtitle, a
  three-sentence abstract, and five metadata chips before any content. Title,
  one sentence, chips. The argument starts in Section 1.
- **Verify light mode renders.** v1 was only ever checked dark.

Unchanged constraints: single self-contained `index.html`, inline CSS and JS,
no build step, no external dependencies, responsive to 375px, semantic HTML,
keyboard accessible, WCAG AA, graceful failure if the JSON does not load.

---

## Voice

Narrative, not procedural. The page tells the story of a research finding and
what follows from it — never "first we ran an EFA, then a CFA, then extracted
factor scores." That sequence belongs in Section 5 and the README, where a
reader has opted in.

Section headings are claims or questions, not panel numbers. No "Panel 1 ·
Model Selection" labels.

Do not narrate the analysis in the first person plural as though the synthetic
results were discovered. They were generated from stipulated parameters; the
page is a demonstration of method, and saying so plainly is what makes the
provenance claim trustworthy.

## Attribution

A line near the top: who built this and why, linking back to
`https://j-snowden.github.io/`. A reader arriving from a job application needs
one sentence of context before an argument starts.

---

## What to verify before finishing

1. The Section 2 toggle changes the chart in both directions, repeatedly.
2. All three k buttons change both the plot and the recommendation text. If the
   nested `means` objects flattened on read, every k renders identically.
3. Light mode.
4. Nothing anywhere says BIC identified four profiles. BIC has no minimum at
   k = 4; it declines through k = 6. The elbow is the criterion.
5. Every number on the page comes from the JSON. Nothing hardcoded.
6. The study is cited with its full author list, no PDF is linked or hosted,
   and no phrasing anywhere implies the synthetic results are the published
   study's findings.
