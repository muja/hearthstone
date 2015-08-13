# Hearthstone Scripts

This is "supposed" to be a collection of some Hearthstone scripts.
Currently it holds only a REPL for drafting arena via command line.

## Arena

The arena script is a REPL (read evaluate print loop) that you can use to draft a deck.
My original motivation for writing this was that Heartharena's Web Interface
is too clumsy for me and it forces you to enter all 3 cards before giving suggestions.

With this I can just type `arena rogue` and start my draft right away.  
If I have to choose between **Wisp**, **Goldshire Footman** and **Piloted Shredder**, I can just type `p pshred` (as I know it's higher value)
and it will be added to my deck (the matcher is rather clever btw). If I liked `heartharena.com`'s advice,
I can also type: `pshred vs wisp vs gfoot` and the result will be printed:

```
> pshred vs wisp vs gfoot
Piloted Shredder  - 80.10 - Synergies:
Wisp              - 20.07 - Synergies:
Goldshire Footman - 29.97 - Synergies:
Great! Let's go purely by the tier list: <b>Piloted Shredder</b>.
```

I can then pick Shredder by entering `p 1` ("pick the first minion from the last comparison")  
I can also just omit a third minion. It will put `Wisp`s in its place and not display them in the output:

```
> pshred vs gfoot
Piloted Shredder  - 80.10 - Synergies:
Goldshire Footman - 29.97 - Synergies:
Great! Let's go purely by the tier list: <b>Piloted Shredder</b>.
```

The help commands shows which commands are available:

```
> help
Available commands are:
f[ind] / q[uery] `expr`   list all cards that match `expr`
p[ick] `expr`             pick the card that matches `expr`
`e1` vs `e2` [vs `e3`]    ask Heartharena.com to compare the cards matching `e1`-`e3`
                          The cards will be stored to enable picking via
                          `p 1`, `p 2` or `p 3` in a subsequent command
                          e.g.: `Wisp vs Ogre Brute` and then `p 2` to pick Ogre
c[hoices]                 Show the last choices that were stored (from above command)
l[ist|s]                  List the current drafted deck
e[rr[or]]                 Show the last error message with debug info
d[elete] `expr`           Deletes the card from the deck that matches `expr`
s[ubmit|ave]              Output script to persist the drafted deck for heartharena.com
?|help|m                  Print this help
```

The `submit`/`save` command is really useful if you want to submit the draft to Heartharena:  
It will print a Javascript snippet that you can paste in the console on the heartharena website.
Or in the address bar by prepending `javascript:` before it. This step is necessary because we have no access to your cookies
so the created draft would be an orphan in the heartharena universe.

### Installation

You'll need Ruby, I used it on v2.2.2, but it probably works on >=1.9

Clone this repository, or download the files [arena.rb](./arena.rb) and [cards.yml](./cards.yml).
Link it into your $PATH and you're good to go!

```bash
git clone https://github.com/muja/hearthstone
ln -s $(pwd)/hearthstone/arena.rb /usr/local/bin # or ~/bin
# to start a draft as Shaman: arena shaman
```

### Notes

This was written as a side project and the code quality isn't great, spaghetti-ish etc.  
If you have any questions, ask away. Issues can be reported!  
If older Ruby support is wished (and not possible), you can tell me, I'll work on it.  
If Windows users would like to use this but they don't have/want Ruby, I may look into rewriting it 
as a Rust or Go project.  


### Issues

Picking **Mind Control** (and a few other cards) can sometimes be rather hard,
because the tool will not be sure whether you meant **Mind Control Tech** - currently,
the only solution to this is to  *quote* **Mind Control** like this:

```
> p Mind Control
Multiple matches: Mind Control Tech, Mind Control
> p "Mind Control"
Picking Mind Control
```

As a solution, maybe a list of matches would be nice to choose from using numbers.
