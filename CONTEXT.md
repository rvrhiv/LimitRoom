# LimitRoom

LimitRoom gives a Mac user a private, glanceable view of the remaining allowance of their AI coding agents. It consolidates data that each enabled agent exposes to the local Mac.

## Allowance

**Agent**:
An AI coding product for which LimitRoom can obtain and display an allowance reading, such as Codex, Claude Code, or Cursor.
_Avoid_: provider, tool

**Connector**:
The agent-specific, read-only boundary that obtains an agent's allowance information and normalizes it for LimitRoom.
_Avoid_: scraper, integration

**Connector Mode**:
One authenticated way that an Agent makes allowance information available to its Connector, such as an official team API or a user-authorized personal session.
_Avoid_: account type, login method

**Account Scope**:
The identity of the subscription whose readings belong together; personal and team subscriptions are distinct even when a person uses both.
_Avoid_: session, agent

**Allowance Window**:
One independently resetting limit within an agent subscription, defined by the provider's own duration, scope, and reset moment.
_Avoid_: quota, plan

**Reading**:
A timestamped value reported by a Connector for one Allowance Window, including its remaining amount and reset information when the agent exposes them.
_Avoid_: estimate, balance

**Pinned Window**:
The Allowance Window selected by the user for the Compact Indicator in either Presentation Mode; its latest Reading changes without changing the selection. Browsing another Agent Card does not change this selection.
_Avoid_: primary quota, default limit, pinned panel

**Reading State**:
The trust state of a Reading: live, stale, signed out, unavailable, or unsupported.
_Avoid_: empty, zero

## Presentation

**Presentation Mode**:
The user's choice of where LimitRoom presents the Compact Indicator: the menu bar or the Notch Panel. Both modes refer to the same Pinned Window.
_Avoid_: connector mode, account mode

**Presentation Fallback**:
Temporary use of the menu bar when the built-in notched display for the preferred Notch Panel is unavailable. It does not change the user's preferred Presentation Mode or Pinned Window.
_Avoid_: reset mode, new selection

**Compact Indicator**:
A glanceable summary of the Pinned Window's remaining allowance and Reading State, identified by its Agent.
_Avoid_: app icon, selected agent

**Notch Panel**:
LimitRoom's compact or expanded allowance panel that forms one continuous visual silhouette with the camera housing. Collapsed content sits in configurable wings beside the camera, within its height. The camera area contains no controls but participates in hover opening; expanded cards and controls sit below it. Both wings refer to the same Pinned Window.
_Avoid_: camera overlay, tray

**Agent Card**:
One Agent's subscription information and Allowance Windows grouped into a consistent visual unit. The card containing the Pinned Window is explicitly marked while the other Agent Cards remain available.
_Avoid_: window card, selected quota

**Panel Hold**:
A temporary user-selected state in which the expanded Notch Panel remains open after the pointer leaves it. It is independent of the Pinned Window.
_Avoid_: pinned quota, selected agent

## Insight

**Usage History**:
A local-only series of Reading snapshots used to describe the user's past allowance consumption.
_Avoid_: activity log, conversation history

**Consumption Trend**:
The observed change in a specific Allowance Window's utilization over time, measured in percentage points per day within comparable observations.
_Avoid_: prediction, burn rate

**Analytic Window**:
The one Allowance Window selected per Agent for cross-agent comparison in the Consumption Trend chart.
_Avoid_: pinned window, primary quota

**Retention Period**:
The maximum age of Usage History retained for analysis.
_Avoid_: archive period, backup

**Allowance Cycle**:
The period between confirmed resets of one Allowance Window; a new cycle breaks continuity with the previous consumption measurement.
_Avoid_: subscription renewal, observation
