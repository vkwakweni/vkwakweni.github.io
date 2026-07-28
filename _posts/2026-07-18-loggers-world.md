---
layout: post
title: Logger's World — Serverless, NoSQL Generic Logging Application
summary: Walks through the development of a generic logging and tracking application built on a fully serverless AWS stack (Cognito, Lambda, DynamoDB, CDK) over a solo, 7-day SDLC sprint.
author: vuyokwakweni
date: "2026-07-28"
category: web-application
thumbnail: /assets/img/posts/log-wood.png
keywords:
permalink: /blog/loggers-world-init
---

# Motivation

It seems as if there is always something new to keep track of: what am I reading; what am I watching; when was my last workout? This need to simply keep track of habits led me to develop _Logger's World_.

It's called _Logger's World_ because, powered by NoSQL, the user can store any kind of habit, with whatever shape, as a log. In this minimalist application, a user can create a custom Log Type, and add entries for it.

# Demo

**Live demo:** [loggersworld.literaturelounge.org](https://loggersworld.literaturelounge.org)

<p align="center">
  <img src="https://raw.githubusercontent.com/vkwakweni/loggers-world/main/artifacts/demo/create-account.png" alt="Create account screen" width="45%" />
  <img src="https://raw.githubusercontent.com/vkwakweni/loggers-world/main/artifacts/demo/log-in.png" alt="Log in screen" width="45%" />
</p>

A full walkthrough of the core flow — creating a log type, adding an entry, editing it — is recorded in [`loggersworld-demo.webm`](https://github.com/vkwakweni/loggers-world/blob/main/artifacts/demo/loggersworld-demo.webm).

# Tech Stack

| Layer | Technology | Free tier |
|---|---|---|
| Frontend framework | React (Vite) | Free (open source) |
| Frontend hosting | AWS Amplify Hosting | Always-free tier |
| Backend runtime | Node.js + Express | Free (open source) |
| Compute | AWS Lambda (via Function URLs) | Always free — 1M requests/month |
| Database | Amazon DynamoDB | Always free — 25GB storage, 25 RCU/WCU |
| Auth | Amazon Cognito | Always free — up to 50,000 MAUs |
| Infrastructure as Code | AWS CDK (TypeScript) | Free tool — pay only for what it provisions |
| CI/CD | GitHub Actions | Free (public repo) |

Every piece was chosen to stay inside AWS's always-free tier while still reflecting a production-shaped architecture:

- **DynamoDB, single-table design** over one-table-per-entity, because both `LogType` and `LogEntry` share the same owner-scoped access pattern (`USER#<ownerId>` partition key), so a single query satisfies "get everything for this user" without a secondary index.
- **Cognito over hand-rolled auth**, so password storage, hashing, and JWT issuance never had to be built or audited from scratch — the Express backend only ever verifies a token it didn't issue.
- **Lambda + Function URL over API Gateway**, since a single Express app behind `serverless-http` needed no routing, throttling, or transformation layer beyond what Express already does.
- **CDK (TypeScript) over hand-written CloudFormation** was chosen for loops/types/reuse when defining near-identical resources (e.g. table/pool ARNs threaded into IAM grants) instead of repeating YAML blocks.

# Technical Challenges

**Cognito's alias vs. username attribute — a silent data-integrity trap.**
The user pool originally used `signInAliases: { email: true, username: true }`, treating email as an alias pointer to a separate username. AWS only enforces alias uniqueness among *confirmed* users, so testing surfaced two problems: multiple `UNCONFIRMED` accounts could register the same email with no warning, and when a second account confirmed with an already-claimed email, Cognito silently reassigned the alias — flipping the *first* account's `email_verified` back to `false` with no notice to either party.

The fix? Switching to `signInAliases: { email: true }` alone, making email the pool's actual username (enforced unique immediately at sign-up, confirmed via a duplicate `signUp()` failing instantly with `UsernameExistsException`).

The catch... `UsernameAttributes` is an immutable CloudFormation property, so `cdk deploy` refuses to update it in place. Since the pool had zero real users at the time, renaming the CDK construct ID (`LoggersWorldUserPool` → `LoggersWorldUserPoolV2`) let CloudFormation treat it as a new resource — replacing the pool in the same deploy. Catching this pre-launch mattered: the same fix against a live pool with real accounts would have deleted every one of them, and would instead require a User Migration Lambda to re-authenticate users into a second pool one login at a time.

**CORS as a browser-only failure mode, invisible to every other test.**
The first real frontend call (`POST /log-types`) failed with a generic "Failed to fetch," even though `curl` and a Node-based token-fetch script worked fine against the same endpoint. The difference: CORS is a browser-only check, and the Lambda Function URL wasn't configured to allow it.

The fix was simple once found — CDK's `addFunctionUrl()` takes a `cors` option where the allowed origins have to be explicitly listed. Adding the frontend's origin there fixed it, no Express middleware needed.

# Architecture

![Architecture diagram](https://raw.githubusercontent.com/vkwakweni/loggers-world/main/artifacts/architecture.svg)

- **Frontend** — React (Vite), hosted on AWS Amplify Hosting, auto-built from `main`
- **Auth** — Amazon Cognito User Pool; the frontend talks to Cognito directly for sign-up/sign-in and attaches the resulting JWT to every API call
- **API** — Express app running inside a single AWS Lambda function, exposed via a Function URL (no API Gateway); JWT verification middleware extracts the caller's identity (`sub` claim) and scopes every query to their own data — `ownerId` is never accepted from the request itself
- **Data** — Amazon DynamoDB, single-table design: `PK = USER#<ownerId>`, `SK = TYPE#<typeId>` or `ENTRY#<typeId>#<createdAt>`, so both "all my log types" and "all entries for one type, newest-first" are satisfied by the base table alone
- **Infrastructure** — the whole backend (table, user pool, Lambda, IAM) is defined in AWS CDK (TypeScript)
- **CI/CD** — GitHub Actions lints/tests every push and PR, then runs `cdk deploy` on merge to `main`; Amplify Hosting rebuilds the frontend on the same push

Two independent auth gates sit in front of every request: the Function URL's `authType: NONE` (an AWS-level "can this invoke Lambda at all" check — the only alternative, `AWS_IAM`, isn't viable for a public browser client) and, only after invocation, the Express JWT middleware that actually authenticates the caller.

# Results

- Assembled a serverless AWS system spanning 6 services end-to-end (Amplify, Cognito, Lambda, DynamoDB, CDK, IAM) entirely within AWS's free tier.
- Designed and shipped a solo, 7-day full-stack serverless application, from requirements through production deployment, following a documented day-by-day SDLC (requirements/design → IaC → backend → frontend → integration → testing/CI → deployment).
- Implemented a GitHub Actions CI/CD pipeline that lints, runs 24 automated tests, and deploys infrastructure changes via CDK on every merge to `main`.
- Caught and fixed a data-integrity bug (Cognito alias uniqueness) and a security-relevant validation gap (entry field types not checked against their parent `LogType` schema) before production launch.

# Links

- **Live demo:** [loggersworld.literaturelounge.org](https://loggersworld.literaturelounge.org)
- **GitHub repo:** [github.com/vkwakweni/loggers-world](https://github.com/vkwakweni/loggers-world)
- **Docs:** [API contract](https://github.com/vkwakweni/loggers-world/blob/main/artifacts/api-contract.md) · [Data models](https://github.com/vkwakweni/loggers-world/blob/main/artifacts/data-models.md) · [Infrastructure](https://github.com/vkwakweni/loggers-world/blob/main/artifacts/infrastructure.md) · [Roadmap](https://github.com/vkwakweni/loggers-world/blob/main/artifacts/roadmap.md)

# Further Development

- **Region latency**: AWS Amplify has no African region yet, so the frontend routes through Ireland, adding latency; Lambda, Cognito, and DynamoDB are all supported locally, so API and auth calls stay fast — only static hosting is affected.
- **`LogType` editing/deletion**: not in scope for the initial build; once entries can outlive schema changes, existing `LogEntry` items won't retroactively match an edited `fields` list, and deleting a type with live entries needs a cascade/block/soft-delete decision.
- **Entry filtering and a cross-type timeline view**, beyond the current per-log-type chronological list.
- **Account management**: session expiry, self-service account deletion, and editable profile details (currently read-only).
- A general mobile-viewport pass — no dedicated responsive review has been done yet.
