"""Predict opponent's deck from revealed cards + MarvelSnap.pro archetypes (getmeta)."""
import json


def predict(revealed, archetypes, top_n=3):
    revealed = set(revealed)
    # cards that exist in some archetype structure — drops generated tokens (TigerSpirit, Rock, ...)
    real = {c for c in revealed
            if any(c == s["CardDefId"] for a in archetypes for s in a["structure"])}
    ranked = []
    for a in archetypes:
        cards = {s["CardDefId"]: float(s["weight"]) for s in a["structure"]}
        covered = real & cards.keys()
        if not covered:
            continue
        # coverage first, then summed weight of matches, then popularity
        score = (len(covered), sum(cards[c] for c in covered), int(a["decks_count"]))
        remaining = sorted((c for c in cards if c not in revealed),
                           key=lambda c: -cards[c])
        ranked.append((score, a, covered, remaining))
    ranked.sort(key=lambda r: r[0], reverse=True)
    return real, ranked[:top_n]


if __name__ == "__main__":
    import sys
    meta = json.load(open("/tmp/getmeta.json"))
    opp = sys.argv[1:] or ["LukeCage", "Magik", "Wong", "WhiteTiger",
                           "TigerSpirit", "BruceBanner", "Ironheart", "Odin"]
    real, ranked = predict(opp, meta["archetypes"])
    print("revealed (deck cards):", sorted(real))
    print()
    for (n, w, pop), a, covered, remaining in ranked:
        print(f"{a['name']} ({a['supertype']})  match {n} cards  ~{pop} decks")
        print(f"   matched : {sorted(covered)}")
        print(f"   likely next: {remaining[:6]}")
        print()
