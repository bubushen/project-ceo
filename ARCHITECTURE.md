# Project CEO — Architecture

This document defines the **only** approved architecture for Project CEO.

It is written for solo development and for AI assistants that will work on this project over time. When in doubt, follow this document. When this document conflicts with a new feature idea, update this document first — do not bypass it in code.

For game vision and design principles, see `PROJECT_GUIDE.md`.

---

## Purpose

Project CEO is a business simulation where the player builds a resilient company while managing personal life constraints. Money is a consequence of decisions, not the primary objective.

The architecture exists to:

1. Keep the codebase small enough for one developer.
2. Prevent systems from becoming tangled.
3. Make every important player action flow through **Decisions**.
4. Allow features to be added in future versions without rewriting existing systems.

---

## Golden Rules

These rules are non-negotiable.

| Rule | Meaning |
|------|---------|
| **Eight systems only** | No new runtime system without updating this document. |
| **Decisions is the heart** | Important actions are never applied silently. They become decisions with visible consequences. |
| **EventBus only** | Systems do not call each other's internal methods. They publish and subscribe to events. |
| **One owner per fact** | Each piece of game state has exactly one owning system. Other systems react via events. |
| **Small scripts** | If a script grows past ~200 lines, split responsibilities — not by creating a new system, but by extracting helpers within the same system. |
| **Defer complexity** | Features marked "later" must not leak into v0.1 code paths. |
| **No UI logic** | UI displays state and forwards player intent. UI never calculates game outcomes. |
| **World runs alone** | WorldSim updates even when the player does nothing. |

---

## System Overview

The game is built from **eight systems** arranged in three layers.

```
┌─────────────────────────────────────────────────────────┐
│  UI                                                      │
│  Reads state · forwards player intent                    │
├─────────────────────────────────────────────────────────┤
│  Decisions                                               │
│  Heart of the game · all meaningful actions pass here    │
├─────────────────────────────────────────────────────────┤
│  Player · Business · WorldSim                            │
│  Domain state and simulation                             │
├─────────────────────────────────────────────────────────┤
│  GameSession · SimulationTime · EventBus                 │
│  Infrastructure                                          │
└─────────────────────────────────────────────────────────┘
```

### System list

| System | Layer | Role |
|--------|-------|------|
| **EventBus** | Infrastructure | Message channel between all systems |
| **SimulationTime** | Infrastructure | Game clock and tick phases |
| **GameSession** | Infrastructure | Run lifecycle and scenario setup |
| **Player** | Domain | Personal life, body, money, assets |
| **Business** | Domain | Company finances and operations |
| **WorldSim** | Domain | External economy and events |
| **Decisions** | Core gameplay | Meaningful choices and consequences |
| **UI** | Presentation | Screens and player input |

---

## Folder Layout

Keep files grouped by system. Do not invent parallel structures.

```
res://
├── core/
│   ├── event_bus.gd
│   ├── simulation_time.gd
│   └── game_session.gd
├── systems/
│   ├── player/
│   ├── business/
│   ├── world_sim/
│   └── decisions/
├── ui/
│   ├── dashboard/
│   └── decision_modal/
├── data/
│   └── (Resources added when needed — not required for v0.1)
└── main.tscn
```

Each system folder contains its own scripts and, if needed, local Resources. Cross-system imports of internal scripts are forbidden.

---

## Infrastructure Layer

### EventBus

**Purpose:** The single communication channel between systems.

**Owns:** Event signal definitions and emit helpers. No game state.

**Does not own:** Business logic, player data, UI nodes.

#### Communication contract

1. Systems **publish** events when something meaningful has already happened inside the owning system.
2. Systems **subscribe** to events they need to react to. Reactions may update local state and publish new events.
3. Systems **never** read or write another system's internal variables.
4. UI subscribes to events for refresh. UI publishes `PlayerIntent` events — never domain events like `CashChanged`.
5. **Decisions** is the only system that may publish `DecisionResolved` with structured outcomes. Owning systems apply those outcomes to their own state.

#### Event naming

Use past tense for facts (`CashChanged`, `DayAdvanced`) and imperative noun phrases for requests (`PlayerIntentSubmitted`). Decision lifecycle events use present progressive or past tense (`DecisionOffered`, `DecisionResolved`).

#### Event categories

| Category | Examples | Publishers | Subscribers |
|----------|----------|------------|-------------|
| **Clock** | `DayAdvanced`, `MonthAdvanced`, `SimulationPaused` | SimulationTime | WorldSim, Business, Player, Decisions, UI |
| **World** | `InflationUpdated`, `DemandChanged`, `PriceChanged`, `WorldEventTriggered` | WorldSim | Business, Decisions, UI |
| **Player** | `HealthChanged`, `EnergyChanged`, `StressChanged`, `PersonalMoneyChanged`, `PersonalExpenseDue` | Player | Decisions, UI, GameSession |
| **Business** | `CompanyCashChanged`, `RevenueRecorded`, `ExpenseRecorded`, `ProductionCompleted` | Business | Decisions, UI, GameSession |
| **Decision** | `DecisionOffered`, `DecisionResolved`, `DecisionExpired`, `PlayerIntentSubmitted` | Decisions, UI | Player, Business, WorldSim, UI, GameSession |
| **Session** | `GameStarted`, `GameOver`, `ScenarioLoaded` | GameSession | All |

New events require a one-line entry in this document's [Event Catalog](#event-catalog) before implementation.

---

### SimulationTime

**Purpose:** Advance the game calendar and coordinate tick order.

**Owns:** Current date, tick speed, pause state, tick phase scheduling.

**Does not own:** What happens during a tick.

#### Tick phases (fixed order)

Each `DayAdvanced` (or `MonthAdvanced` — configurable per scenario) runs phases in sequence:

1. **World phase** — WorldSim updates inflation, demand, prices; may emit random events.
2. **Passive phase** — Player applies passive drains (energy recovery, stress decay, personal expenses). Business applies passive costs.
3. **Decision phase** — Decisions checks deadlines, expires unresolved choices, may offer new decisions triggered by world or state thresholds.
4. **Resolution phase** — If a decision was resolved since last tick, owning systems have already applied outcomes via `DecisionResolved`. No extra work here unless a deferred consequence is time-based.
5. **Check phase** — GameSession evaluates lose conditions (e.g. player health collapse, personal bankruptcy, company insolvency).

SimulationTime publishes `DayAdvanced` at the start and `TickPhaseCompleted` after each phase. Systems subscribe only to the phases they need.

---

### GameSession

**Purpose:** Start, run, and end a game session.

**Owns:** Scenario configuration, starting conditions (€20,000 personal savings per `PROJECT_GUIDE.md`), win/lose rules, references to registered systems.

**Does not own:** Domain state belonging to Player, Business, or WorldSim.

#### Responsibilities

- Load scenario and initialize system starting state through each system's public `reset(scenario)` method.
- Register systems at boot. Systems register their EventBus listeners in `_ready` or `reset`.
- Listen for terminal events (`GameOver` triggers) from Player, Business, or explicit scenario goals.
- Publish `GameStarted` and `GameOver`.

GameSession is an orchestrator, not a god object. It does not calculate prices, apply decision outcomes, or format UI.

---

## Domain Layer

### Player

**Purpose:** Model the human behind the company. The business does not exist in a vacuum — personal constraints drive meaningful tradeoffs.

**Owns:**

| Attribute | Description |
|-----------|-------------|
| **health** | Physical wellbeing. Collapse can end the run or restrict actions. |
| **energy** | Daily capacity to act. Actions and decisions consume energy. |
| **stress** | Accumulated pressure. High stress degrades health and decision quality. |
| **appearance** | How the player presents publicly. Affects social and business opportunities (later hooks). |
| **available time** | Hours per day/week not spent on fixed obligations. Decisions consume time. |
| **personal money** | Savings separate from company cash. Starting scenario: €20,000. |
| **personal expenses** | Rent, food, car payments, and other recurring personal costs. |
| **car** | Mobility asset. Affects available time and personal expenses. |
| **house** | Housing asset. Affects personal expenses, stress baseline, and appearance. |

**Does not own:** Company cash, production, market prices, or decision definitions.

#### How Player interacts with the game

- Player never applies decision outcomes directly from UI. Decisions publishes `DecisionResolved`; Player's listener applies personal consequences (money spent, energy spent, stress change).
- Passive drains run on the passive tick phase: personal expenses reduce personal money, low energy increases stress, etc.
- Player publishes state change events after every mutation so UI and Decisions can react.

#### v0.1 scope

Implement health, energy, stress, personal money, personal expenses, and available time. **appearance**, **car**, and **house** may exist as static scenario placeholders (default values) without full decision chains until a later version.

---

### Business

**Purpose:** Model the player's company as a separate financial and operational entity from the player's personal life.

**Owns:**

| Attribute | v0.1 | Later versions |
|-----------|------|----------------|
| **company cash** | Yes | — |
| **revenues** | Yes | — |
| **expenses** | Yes | — |
| **production / service** | Yes (single line) | Multiple lines |
| **employees** | No — use fixed labor cost in expenses | Hiring, morale, productivity |
| **investments** | No | Equipment, marketing, R&D |

**Does not own:** Personal money, player health, world price indices, or decision templates.

#### How Business interacts with the game

- Business reads world conditions only via EventBus (`PriceChanged`, `DemandChanged`) — never queries WorldSim directly.
- Revenue and production calculations run during the passive or world-reactive phase when Business subscribes to `MonthAdvanced` or `DayAdvanced`.
- Injecting personal money into the company (or paying yourself) is always a **Decision** — Business does not move personal money; it reacts to `DecisionResolved` outcomes that authorize a transfer.
- Company insolvency is detected by Business and published as `CompanyCashChanged` with solvency flag; GameSession listens.

#### v0.1 scope

One product or service line. Fixed monthly operating costs including implicit labor. No employee entities.

---

### WorldSim

**Purpose:** Represent the external economy that evolves **independently** of the player.

**Owns:**

| Attribute | v0.1 | Later versions |
|-----------|------|----------------|
| **inflation** | Yes | Linked macro indicators |
| **demand** | Yes | Sector-specific demand curves |
| **prices** | Yes (input and output multipliers) | Multi-market pricing |
| **random events** | Yes (simple table) | Weighted event decks |
| **crises** | No — random events only | Multi-phase crises with escalation |

**Does not own:** Company cash, player stress, or decision presentation.

#### How WorldSim interacts with the game

- WorldSim updates autonomously on clock events. Player inaction does not freeze the world.
- Random events publish `WorldEventTriggered` with a payload ID and severity. **Decisions** subscribes and converts significant events into `DecisionOffered` — WorldSim never shows UI or moves company cash directly.
- Inflation, demand, and prices publish granular change events so Business can recalculate without polling.

#### Design intent

The player learns economics by observing cause and effect: inflation rises → prices change → margins shrink → a decision is offered. WorldSim provides pressure; Decisions provides agency.

---

## Core Gameplay Layer

### Decisions

**Purpose:** The heart of the game. Every important action passes through a decision with visible consequences.

If a feature does not create or resolve a decision, question whether it belongs in v0.1.

**Owns:**

- Decision templates and instances (pending choice, options, deadlines).
- Consequence definitions mapping each option to structured effects.
- Resolution flow: offer → player chooses → outcomes published → instance closed.

**Does not own:** Long-term storage of cash, health, or prices. It applies consequences by publishing `DecisionResolved` with an effect payload; owning systems mutate their own state.

#### What must be a decision

| Action type | Why |
|-------------|-----|
| Spending personal or company money on something meaningful | Tradeoff visibility |
| Changing production or service level | Resource allocation |
| Responding to a world event | Agency under pressure |
| Sacrificing time, energy, or health for business gain | Core fantasy |
| Taking on personal or business financial risk | Consequence clarity |
| Injecting personal savings into the company | Separates wallets explicitly |

#### What may skip Decisions (trivial automation)

- Passive recurring personal expenses (already committed obligations).
- Automatic bookkeeping entries driven purely by prior decisions.
- UI navigation and display toggles.

When unsure, default to **making it a decision**.

#### Decision lifecycle

```
Trigger (world event, threshold, player intent, or schedule)
  → Decisions creates instance
  → DecisionOffered
  → UI shows choice
  → PlayerIntentSubmitted
  → Decisions validates (energy, time, money — via event queries or pre-resolution checks)
  → DecisionResolved (effect payload)
  → Player / Business / WorldSim apply owned changes
  → UI refreshes via state change events
```

#### Effect payload principle

`DecisionResolved` carries a dictionary or typed resource describing **intent**, not final computed state. Example intents: `ReduceProduction`, `InjectPersonalCash`, `PayPersonalExpense`, `AcceptWorldEventOptionB`. The owning system computes the actual numeric result using its current state.

This keeps Decisions free of duplicate business logic.

#### v0.1 scope

- One active decision at a time (modal).
- 5–10 decision templates covering money, time, energy, and world events.
- Expire on inaction where appropriate (consequences of avoidance must be visible).

---

## Presentation Layer

### UI

**Purpose:** Show state and capture intent. Nothing else.

**Owns:** Scenes, layout, formatting, input widgets.

**Does not own:** Game rules, outcome calculation, or cross-system state.

#### Screens (v0.1)

| Screen | Shows | Sends |
|--------|-------|-------|
| **Dashboard** | Player vitals, personal money, company cash, demand/price summary, pending decision alert | Navigation intents |
| **Decision modal** | Active decision text, options, predicted consequence hints | `PlayerIntentSubmitted` |

#### UI rules

1. Subscribe to EventBus state events. Refresh on change — no per-frame polling of system internals.
2. Consequence **hints** shown to the player may be approximate copy defined in Decisions templates — UI does not simulate outcomes.
3. UI never emits `DecisionResolved`, `CashChanged`, or similar domain events.
4. All buttons that matter emit `PlayerIntentSubmitted` with an intent ID. Decisions decides whether that intent opens, confirms, or cancels a decision.

---

## Event Catalog

Canonical events. Extend this table before adding new signals.

### Clock

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `DayAdvanced` | SimulationTime | `{ day, month }` | WorldSim, Player, Business, Decisions, GameSession |
| `MonthAdvanced` | SimulationTime | `{ month, year }` | Business, Player, UI |
| `TickPhaseCompleted` | SimulationTime | `{ phase }` | Optional diagnostics |
| `SimulationPaused` | SimulationTime | `{ paused: bool }` | UI |

### World

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `InflationUpdated` | WorldSim | `{ rate }` | Business, UI |
| `DemandChanged` | WorldSim | `{ demand_index }` | Business, Decisions, UI |
| `PriceChanged` | WorldSim | `{ input_mult, output_mult }` | Business, UI |
| `WorldEventTriggered` | WorldSim | `{ event_id, severity }` | Decisions |

### Player

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `HealthChanged` | Player | `{ health }` | UI, GameSession, Decisions |
| `EnergyChanged` | Player | `{ energy }` | UI, Decisions |
| `StressChanged` | Player | `{ stress }` | UI, Decisions |
| `PersonalMoneyChanged` | Player | `{ amount }` | UI, GameSession, Decisions |
| `PersonalExpenseDue` | Player | `{ expense_id, amount }` | Decisions |

### Business

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `CompanyCashChanged` | Business | `{ cash, solvent }` | UI, GameSession, Decisions |
| `RevenueRecorded` | Business | `{ amount, source }` | UI |
| `ExpenseRecorded` | Business | `{ amount, category }` | UI |
| `ProductionCompleted` | Business | `{ units, revenue }` | UI |

### Decisions

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `DecisionOffered` | Decisions | `{ decision_id, options, deadline }` | UI |
| `PlayerIntentSubmitted` | UI | `{ intent_id, context }` | Decisions |
| `DecisionResolved` | Decisions | `{ decision_id, option_id, effects }` | Player, Business, WorldSim, UI |
| `DecisionExpired` | Decisions | `{ decision_id, default_effects }` | Player, Business, UI |

### Session

| Event | Publisher | Payload summary | Typical subscribers |
|-------|-----------|-----------------|---------------------|
| `GameStarted` | GameSession | `{ scenario_id }` | All systems |
| `GameOver` | GameSession | `{ reason, victory }` | UI |
| `ScenarioLoaded` | GameSession | `{ scenario }` | All systems |

---

## Communication Diagrams

### Daily tick flow

```
SimulationTime
  │ publish DayAdvanced
  ▼
WorldSim ──publish──► InflationUpdated, DemandChanged, PriceChanged
  │                    WorldEventTriggered (if any)
  ▼
Player ──publish──► EnergyChanged, StressChanged, PersonalMoneyChanged ...
  │
  ▼
Business ──publish──► CompanyCashChanged, RevenueRecorded, ExpenseRecorded
  │
  ▼
Decisions ──publish──► DecisionOffered / DecisionExpired
  │
  ▼
GameSession ──publish──► GameOver (if lose condition met)
  │
  ▼
UI ◄──subscribe── all state change events
```

### Player action flow

```
UI
  │ publish PlayerIntentSubmitted
  ▼
Decisions
  │ validates intent · resolves choice
  │ publish DecisionResolved { effects }
  ▼
┌─────────┬───────────┬───────────┐
▼         ▼           ▼           ▼
Player   Business   WorldSim      UI
  │         │           │           │
  └──publish state change events────┘
```

### Forbidden flows

```
UI ──✗──► Business.apply_cost()          direct method call
Business ──✗──► WorldSim.demand          direct state read
WorldSim ──✗──► Player.stress -= 10      cross-system mutation
Decisions ──✗──► Player.money = 500      Decisions publishes; Player applies
Player ──✗──► CompanyCashChanged         wrong owner — Business publishes cash
```

---

## Personal vs Company Money

Two separate wallets. This separation is architectural, not cosmetic.

| Wallet | Owner | Used for |
|--------|-------|----------|
| **Personal money** | Player | Living costs, car, house, personal risk |
| **Company cash** | Business | Operations, production, business expenses |

Transfers between wallets always require a **Decision**. Neither system pulls from the other's balance without a `DecisionResolved` effect.

---

## Starting Scenario (reference)

Aligned with `PROJECT_GUIDE.md`:

- Player begins unemployed with **€20,000 personal money**.
- Company may start pre-formed or created by early decision — scenario config in GameSession.
- Goal is resilience, not speed wealth. v0.1 win condition is defined in GameSession (e.g. survive N months with solvent company and player health above zero).

---

## Deferred Features (do not implement until requested)

| Feature | Originally considered | Defer because |
|---------|----------------------|---------------|
| **Save / load** | Persistence system | v0.1 is single-session; serialization locks schema too early |
| **Employees** | Business subsystem | Fixed costs suffice; HR is a large decision domain |
| **Investments** | Business subsystem | Needs multiple decision chains and reporting |
| **Crises framework** | WorldSim | Random events + Decisions enough for v0.1 |
| **Competition** | Separate AI companies | No market share model yet |
| **Appearance / car / house depth** | Player subsystems | Placeholder values until personal decisions multiply |
| **Data registry** | Central content DB | One scenario does not need a catalog service |
| **Multiple products** | Business | One line proves the loop |
| **Full decision inbox** | Decisions UI | One modal at a time is sufficient for solo v0.1 |

When implementing a deferred feature, extend the owning system listed here. Do not add a ninth runtime system without revising this document.

---

## Adding Features Checklist (for AI developers)

Before writing code, answer these questions:

1. **Which system owns the new state?** If unclear, stop and update this document.
2. **Is it a meaningful decision?** If yes, add a template in Decisions. UI shows it. Outcomes are effect payloads.
3. **Which events are published?** Add them to the Event Catalog section first.
4. **Does it need a new system?** Almost certainly no. Defer or fold into Player, Business, WorldSim, or Decisions.
5. **Can it wait?** If yes, mark it deferred and do not stub half an implementation.

After implementation:

- No direct cross-system references were added.
- Scripts remain small and in the correct folder.
- `PROJECT_GUIDE.md` principles are preserved.

---

## Anti-Patterns

| Anti-pattern | Correct approach |
|--------------|------------------|
| `get_node("/root/Business")` from Player | Subscribe to `CompanyCashChanged` |
| Outcome math inside UI | Decisions effect payload + owning system calculates |
| World event reduces cash directly | WorldSim publishes → Decisions offers choice → Business applies |
| New Autoload per feature | Extend one of the eight systems |
| Skipping Decisions for "small" money spends | Small spends still teach tradeoffs — use a decision |
| God script in GameSession | GameSession orchestrates; it does not simulate |

---

## Version History

| Version | Summary |
|---------|---------|
| **1.0** | Initial architecture. Eight systems. Player/Business split. Decisions as core. EventBus-only communication. |

---

## Related Documents

- `PROJECT_GUIDE.md` — vision, principles, coding rules
- `ARCHITECTURE.md` — this file — systems, events, ownership, boundaries

When building Project CEO, read `PROJECT_GUIDE.md` for *why* and this file for *how*.
