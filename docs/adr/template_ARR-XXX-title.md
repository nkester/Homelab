# ADR-XXXX: [Short Title]

* **Status:** [Proposed | Accepted | Superseded]
* **Date:** YYYY-MM-DD
* **Author:** Neil Kester

## 1. Context
Describe the forces at play. What was the problem? (e.g., "The CR1000A firmware refused to route the .0.x subnet.")

## 2. Decision
The specific action taken. (e.g., "We pivoted the ER605 and the entire management plane to 192.168.1.x.")

## 3. Consequences
* **Positive:** Stability achieved; vendor 'sanity checks' bypassed.
* **Negative:** Deviates from standard .0.x lab conventions.
* **Neutral:** Requires manual IP reassignment for existing nodes.