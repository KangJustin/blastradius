"""The core walker: given a function name, traverse the real Calls graph
outward (both who calls it and what it calls) up to a bounded number of
hops, and report every Function it finds along the way. This traversal -
not a lookup, not a single LLM call - is what makes an answer to "what
breaks if I change this?" trustworthy.
"""

import from graph { Function, Calls }

walker:pub BlastRadius {
    has target_fn: str;
    has max_hops: int = 3;
    has visited: list[str] = [];
    has hop_of: dict[str, int] = {};
    has reports: list[Function] = [];

    can start with Root entry {
        visit [-->[?:Function, name == self.target_fn]];
    }

    can walk with Function entry {
        if here.name in self.visited {
            skip;
        }
        self.visited.append(here.name);
        report here;

        my_hop: int = 0;
        if here.name in self.hop_of {
            my_hop = self.hop_of[here.name];
        }

        if my_hop < self.max_hops {
            for caller in [here <-:Calls:<-] {
                if caller.name not in self.hop_of {
                    self.hop_of[caller.name] = my_hop + 1;
                }
            }
            for callee in [here ->:Calls:->] {
                if callee.name not in self.hop_of {
                    self.hop_of[callee.name] = my_hop + 1;
                }
            }
            visit [here <-:Calls:<-];
            visit [here ->:Calls:->];
        }
    }
}
