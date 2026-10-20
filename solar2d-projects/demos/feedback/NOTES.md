# Notes

The points the demo is making, which the seven versions can show but not say.

## There is no single correct formula

Different things work in different games. Nothing in this demo is a checklist. A hit flash that reads perfectly here would be noise in a game where six enemies are on screen at once, and a knockback that sells a pistol shot would feel wrong on a weapon meant to be light and fast.

## Game development is iterative

Try something, keep it, throw it away, try again. The values in this demo are one test. Several of them could be done better differently, and the only way to find out which is to change them and look.

## Not everything you add is an improvement

Version 7 is the demo arguing with itself. The casing sound is a real, plausible, cheap addition, and it makes the result worse: it repeats too often and it stands out too much next to the shots and impacts it is supposed to sit under. Nothing about that was visible on paper. It took adding it, listening to it for a while, and then taking it out again to hear the difference, which is the only method there is.

## These effects are one guess out of many

Every duration, distance and curve in `data/versions.lua` was picked by eye rather than derived from anything. They are a starting point for your own project, not a reference implementation. Change one, watch the fight, and decide for yourself whether it got better.

## This could go much further

Real character art, animation, hit reactions per body part, damage numbers, camera work, weapon variety. The demo stops at boxes deliberately: the point is that feel comes from behaviour rather than from art, and boxes make that impossible to mistake for anything else.

## What the demo does not do

The fight plays itself. Nobody pulls the trigger, and that is a real limitation: feedback on an action you took yourself lands harder than feedback on an action you only watched. The trade was deliberate, because letting a viewer shoot would mean every version played a different fight and the comparison between versions is the whole demo.
