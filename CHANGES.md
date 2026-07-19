# Changes to index.html

Edit the existing `index.html` in place. Do not rebuild it — the layout,
typography, charts, and interactions all work and should be preserved. These
are content and framing changes, plus one section removal.

The underlying data has not changed. `data/model_results.json` is unchanged and
the R scripts should not be re-run.

---

## 1. Delete the conventional-view section

Remove the section that shows mean factor scores by department, tenure, and
level, and the org-attribute/profile toggle that switches between them.
Everything associated with it goes: the markup, the chart, the toggle control,
its CSS, and its JS.

**Why**, so the reasoning is not lost: the simulation draws department, tenure,
and level *independently of profile membership*. A section demonstrating that
conventional segmentation fails to predict profile is therefore displaying a
result that was stipulated in the data generation, not discovered by the
analysis. It is circular, and it is the first thing a knowledgeable reader
would take apart.

The material does not disappear entirely — see change 5.

## 2. Remove all claims of novelty or critique

Search the page for any phrasing that positions this work as revealing what
current practice misses, as a better alternative to how employee listening is
done, or as a method the field is overlooking. Remove or rewrite all of it.

This matters for accuracy, not modesty. Person-centered analysis of engagement
is well established in the organizational literature, and listening teams run
key driver analysis as standard practice. A page implying otherwise reads as
unfamiliar with the field.

Replace with the calibrated framing: latent profile analysis is an established
method, and this shows what it looks like applied to experience data — the
analysis, the judgement calls, and what the results do and do not support.

## 3. The profile section becomes the opening finding

With the conventional view gone, the four-profile section follows the
provenance intro directly. It should now read as the finding rather than as a
payoff to a setup.

Remove any transitional language that referred to the deleted section
("now switch to…", "the same data, segmented differently", and similar).

Add a paragraph of interpretation after the profile plot, if one is not already
there. The substance: the profiles separate far more on the affective factors
(Engagement, Impact, Autonomy) than the structural ones (Clarity, Enablement).
People report broadly similar clarity about what is expected of them, and very
different levels of investment in it. Whatever distinguishes these groups, it
is not that some of them lack information.

## 4. Add the limitation, in the profile section

New paragraph, immediately after the interpretation above. Set it in the same
voice as the rest of the page — not a disclaimer, not smaller type, not
bracketed as a caveat.

Content: these profiles are ordinal. The groups differ in level more than in
shape, which is the common result in engagement profile research and which
constrains what follows from them. A solution with genuinely different shapes
would support different interventions per profile. This one supports knowing
how large the struggling group is, and knowing that it is not defined by
anything already recorded in the HR system.

## 5. Move the organizational-attribute result into the methods section

The `segmentation` object in the JSON is still used, but only here, and framed
honestly.

Report it as a descriptive characteristic of the solution: profile membership
shows no significant association with department, tenure, or level after Holm
correction (Cramér's V values from `segmentation.association`).

Then state the caveat in the same breath, not in a footnote: the simulation
draws these attributes independently of profile membership, so the null is
stipulated rather than discovered. Note that the source study found the same
pattern empirically — Cramér's V .049 to .091, all null after Holm correction —
and cite that as the warrant for encoding it this way.

Do not give this its own heading or visual treatment. Two or three sentences
inside the methods disclosure.

## 6. Give the free-text section more room

With the contrast panel removed, this is the most substantive analytical
observation on the page. It currently reads as an appendix; it should read as a
finding.

Keep the two tables and the shared-scale bars exactly as built. Expand the
closing prose to make the point explicit: response behaviour is data, not
missingness. The people with the fewest problems are least likely to answer the
"what's wrong" prompt, so a comment corpus systematically overrepresents the
disengaged. Any thematic analysis that treats the corpus as representative
reads the loudest signal as the typical one.

If the section sits below the methods disclosure, move it above — methods
should be last on the page.

---

## Verify before finishing

1. No orphaned CSS or JS from the deleted section. No dead toggle handler, no
   unused chart-rendering function, no console errors on load.
2. The k = 3 / 4 / 5 control still changes both the plot and the recommendation
   text.
3. Light and dark mode both render.
4. Nothing on the page says BIC identified four profiles. BIC declines
   monotonically through k = 6; the elbow is the criterion.
5. Nothing claims the method is novel or that it corrects an error in current
   practice.
6. Every number still comes from the JSON. Nothing hardcoded during the edit.

Report what you changed and what you checked.
