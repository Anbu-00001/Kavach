"""Generate a multi-label scam-tactic dataset for the tiny on-device classifier.

The reference detector matches fixed cues; this generator deliberately includes *paraphrases*
those cues miss (e.g. "wire the bail money" vs the cue "wire transfer"), so the trained model
learns the tactic, not the keyword. Output: train.jsonl / val.jsonl of {text, labels:[...]}.

Run:  python3 core/build_dataset.py [--n 1200] [--seed 7]
"""

from __future__ import annotations

import argparse
import json
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "datasets")

# Tactic label space — must match taxonomy.json order.
TACTICS = [
    "URGENCY", "SECRECY", "UNTRACEABLE_PAYMENT", "AUTHORITY_IMPERSONATION",
    "DISTRESS_HOOK", "ISOLATION", "IDENTITY_PROBE", "RELATIONSHIP_SPOOF",
]

# Surface phrasings per tactic — intentionally broader than the cue lists in taxonomy.json.
PHRASES = {
    "URGENCY": [
        "right now", "immediately", "you have to act fast", "there's no time to lose",
        "before it's too late", "within the next hour", "hurry, we can't wait",
        "this can't wait until tomorrow", "do it this minute", "the deadline is today",
    ],
    "SECRECY": [
        "don't tell anyone", "keep this between us", "please don't tell mom",
        "don't mention this to the family", "this has to stay secret",
        "promise me you won't say a word", "nobody else can know about this",
    ],
    "UNTRACEABLE_PAYMENT": [
        "buy some google play gift cards and read me the codes", "send it by wire transfer",
        "pay with apple gift cards", "send bitcoin to this wallet", "wire the bail money over",
        "put it on a steam card", "send it through zelle to this number",
        "go to the store and get gift cards", "western union the cash to me",
        "load the money onto a prepaid card", "transfer the crypto now",
        # digital-arrest money move — "verification / safe account" instead of a gift card
        "transfer the funds to a safe account for verification",
        "deposit the money in this verification account to clear your name",
        "move your savings to a secure rbi account while we investigate",
        "it is a fully refundable security deposit, you will get it back",
        "send the amount to this government account for safekeeping",
        # pig-butchering / investment lure
        "invest in this trading platform with guaranteed returns",
        "put your savings into this opportunity and double your money",
    ],
    "AUTHORITY_IMPERSONATION": [
        "this is officer ramirez from the police", "i'm calling from the irs",
        "this is the tax department", "i'm with your bank's fraud team",
        "there is a warrant for your arrest", "this is the social security administration",
        "i'm a federal agent", "this is customs and border protection",
        # India "digital arrest" authority scripts
        "this is the cbi cyber crime branch",
        "i'm calling from the enforcement directorate",
        "a money laundering case has been registered against your aadhaar",
        "your parcel was seized by customs and contained illegal items",
        "your sim card is linked to a criminal investigation",
        "you are under digital arrest and must cooperate",
        "this is the narcotics control bureau, a case has been filed against you",
    ],
    "DISTRESS_HOOK": [
        "i'm in jail and i need help", "i've been in a terrible accident",
        "i'm in the hospital and it's bad", "they've taken me and i'm scared",
        "i'm in serious trouble", "mom i messed up really badly",
        "i need bail or they keep me locked up", "i'm hurt and i need you",
    ],
    "ISOLATION": [
        "don't hang up the phone", "stay on the line with me the whole time",
        "don't call anyone else", "keep me on the line", "don't put me on hold",
        "whatever you do, don't end this call", "don't talk to anyone about this call",
        # digital-arrest isolation — hours/days on video, no contact with family
        "stay on this video call for the next few days",
        "keep your camera on at all times until the case is closed",
        "do not disconnect or leave the room",
        "you cannot tell your family, this is a confidential investigation",
    ],
    "IDENTITY_PROBE": [
        "read me the code i just texted you", "what's the one-time password you got",
        "tell me your card's cvv number", "confirm your social security number for me",
        "what's your account pin", "verify your date of birth", "give me the verification code",
    ],
    "RELATIONSHIP_SPOOF": [
        "grandma it's me, your grandson", "mom, it's me", "dad, don't you recognize my voice",
        "it's me, my voice sounds off because i have a cold",
        "it's your son calling", "hi grandpa it's your granddaughter",
    ],
}

GREETINGS = ["", "Hello? ", "Hi, ", "Listen, ", "Okay so ", "Hey, ", "Please, "]
CONNECTORS = [", ", " and ", ". ", " — ", ", and ", "; "]
SUFFIXES = ["", " thanks", " talk soon", " let me know", " no rush", " see you then",
            " call me back when you can", " have a good day", " love you"]

# Ordinary legit calls.
LEGIT = [
    "this is Dr. Mehta's office confirming your appointment on Thursday at ten",
    "hey it's Priya, are we still on for coffee this weekend",
    "your package is out for delivery and should arrive between two and four",
    "mom, just calling to say I landed safely",
    "this is the library, the book you reserved is available for pickup",
    "i'm returning your call about the plumbing quote for the kitchen",
    "it's your sister, dinner is at seven, bring the dessert you promised",
    "reminder from the dentist, your cleaning is tomorrow morning",
    "it's Sam from work, did you get the slides for the meeting",
    "this is the pharmacy, your prescription is ready to collect",
    "hi grandma, just checking in, how was your walk today",
    "it's the school office, your son left his lunchbox",
    "calling from the garage, your car is ready and passed inspection",
    "the movie starts at eight so let's meet at seven thirty",
    "this is your neighbour, your parcel was delivered to my door",
    "confirming the table for four under your name for Saturday",
    "it's me, just wanted to hear your voice, how are you doing",
    "the kids say hi, we'll visit on Sunday afternoon",
    "this is the clinic with your test results, everything looks normal",
    "hey, can you pick up milk on your way home tonight",
    "it's the vet, your dog's vaccination is due next week",
    "calling about the job interview, are you free Tuesday morning",
]

# Hard negatives: legit calls that mention money / banks / urgency-ish words but are NOT scams.
# These teach the model that a money or bank mention alone is not the scam pattern.
LEGIT_HARD = [
    "this is your bank confirming the payment you made at the supermarket, no action needed",
    "the rent is due Friday, transfer it whenever suits you this week",
    "your salary has been deposited, just letting you know it cleared",
    "it's the accountant, your tax return is filed and you're getting a refund",
    "i paid you back for lunch over the usual app, check when you get a sec",
    "the electricity bill came, it's the normal amount, I'll handle it",
    "your insurance renewal is coming up next month, no hurry to decide",
    "we split the dinner bill evenly, I'll send you your share later",
    "the bank app is showing your new card was delivered, activate it whenever",
    "mom transferred you some birthday money, it should show up tomorrow",
    # benign mentions of the exact words digital-arrest scams abuse — must NOT flag
    "your aadhaar update was successful, nothing further is needed from you",
    "customs cleared your parcel, it'll be delivered tomorrow with nothing to pay",
    "i moved the deposit to our joint account like we agreed earlier",
    "your investment account statement for this month is ready to view whenever",
    "just a reminder no bank or police will ever ask you to move money over the phone",
    "the passport office confirmed your application, no payment is required",
]

# Targeted hard negatives for the false-positive modes found on real conversational data:
# legit company intros (misread as authority impersonation), wrong-number calls (misread as
# identity-probe/distress), and routine business confirmations. {company}/{name} get filled in.
COMPANIES = ["ABC Insurance", "City Auto Repair", "Bright Telecom", "Sunrise Bank",
             "MediCare Clinic", "QuickShip Logistics", "Green Energy", "Star Mobile",
             "the dental office", "the gas company", "your internet provider"]
NAMES = ["Karen", "Raj", "Maria", "David", "Priya", "Sam", "Anita", "John", "Mr. Patel"]
LEGIT_TRICKY = [
    # legit sales / company intros — must NOT read as authority impersonation
    "hi, this is {name} from {company}, we have a special offer on your plan this month, no pressure",
    "i'm calling from {company} about renewing your policy, call back whenever suits you",
    "this is {company}, you're eligible for a loyalty discount, want me to email the details",
    "{name} here from {company}, just following up on the quote we sent you",
    "this is {company} customer support following up on your ticket, no action needed",
    # wrong-number — must NOT read as identity-probe / distress
    "sorry, i think i have the wrong number",
    "is this the {name} residence? oh, my apologies, wrong number",
    "i was trying to reach {name}, sorry to bother you, have a good day",
    "hello? oh sorry, i must have dialed the wrong number",
    # routine business confirmations — must NOT read as a scam despite 'confirm'
    "this is {company} confirming your appointment for tomorrow, reply to reschedule",
    "calling from {company} to confirm your booking, nothing needed from you",
    "your order with {company} is confirmed and shipping today",
    "this is {company}, your service visit is scheduled for Tuesday morning",
    "just confirming your reservation for four people on Saturday, see you then",
]


def fill(rng: random.Random, template: str) -> str:
    return template.replace("{company}", rng.choice(COMPANIES)).replace("{name}", rng.choice(NAMES))


def make_scam(rng: random.Random) -> tuple[str, list[str]]:
    k = rng.choices([1, 2, 3], weights=[3, 5, 3])[0]
    chosen = rng.sample(TACTICS, k)
    # order them naturally-ish: relationship/distress first, payment/secrecy later
    order = {t: i for i, t in enumerate(
        ["RELATIONSHIP_SPOOF", "AUTHORITY_IMPERSONATION", "DISTRESS_HOOK", "URGENCY",
         "ISOLATION", "IDENTITY_PROBE", "UNTRACEABLE_PAYMENT", "SECRECY"])}
    chosen.sort(key=lambda t: order[t])
    parts = [rng.choice(PHRASES[t]) for t in chosen]
    text = rng.choice(GREETINGS) + rng.choice(CONNECTORS).join(parts)
    if not text.endswith((".", "!", "?")):
        text += "."
    return text, chosen


def make_legit(rng: random.Random) -> tuple[str, list[str]]:
    # Weighted mix: lots of the targeted tricky negatives (the real-data failure modes),
    # some money/bank hard negatives, the rest ordinary legit calls.
    roll = rng.random()
    if roll < 0.45:
        base = fill(rng, rng.choice(LEGIT_TRICKY))
    elif roll < 0.65:
        base = rng.choice(LEGIT_HARD)
    else:
        base = rng.choice(LEGIT)
    text = rng.choice(GREETINGS) + base + rng.choice(SUFFIXES)
    if not text.endswith((".", "!", "?")):
        text += "."
    return text, []


def build(n: int, seed: int) -> list[dict]:
    rng = random.Random(seed)
    seen: set[str] = set()
    rows: list[dict] = []
    # Balance ~50/50 scam vs legit: each step, generate whichever class is currently behind.
    n_scam = n_legit = 0
    tries = 0
    while len(rows) < n and tries < n * 60:
        tries += 1
        make_scam_now = n_scam <= n_legit
        text, labels = make_scam(rng) if make_scam_now else make_legit(rng)
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        rows.append({"text": text, "labels": labels})
        if make_scam_now:
            n_scam += 1
        else:
            n_legit += 1
    rng.shuffle(rows)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=1200)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--val-frac", type=float, default=0.15)
    args = ap.parse_args()

    rows = build(args.n, args.seed)
    n_val = int(len(rows) * args.val_frac)
    val, train = rows[:n_val], rows[n_val:]
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, split in [("train", train), ("val", val)]:
        path = os.path.join(OUT_DIR, f"{name}.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            for r in split:
                fh.write(json.dumps(r) + "\n")
        scam = sum(1 for r in split if r["labels"])
        print(f"  {name}: {len(split):4d} lines  ({scam} scam / {len(split) - scam} legit)  -> {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
