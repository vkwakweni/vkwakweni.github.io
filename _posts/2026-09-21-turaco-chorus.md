---
layout: post
title: Turaco Chorus — An Exploration in Architecture and Containerisation
summary: Describes Turaco Chorus as a microservice, along with its architecture, technology stack, and motivation for development.
author: vuyokwakweni
date: "2026-09-21"
category: ["microservice", "ai-integration"]
thumbnail: /assets/img/posts/turaco-logo.svg
keywords:
permalink: /blog/turaco-chorus
---

# Motivation

At the beginning of every project, I ask one simple question that needs a lot of time to answer: what do I want it to do?

The project description you are about to read stands on its own: it describes its own architecture and why its decoupled approach works so well. But, before we begin, I want to let you know that Turaco Chorus was not born like that.

I made another application, Logger's World, a habit tracker. And naturally, I thought about how to gain insights from such data, should a user choose to do so. But, before I added that as a feature to Logger's World, I came back to that question: what do I want it to do?

My idea for adding an insight engine felt so large that I felt it crowded over the application's purpose. Logger's World had its own room, and I wanted to move a stranger into there; that couldn't work at all. So, I built another room. That way, Turaco Chorus could grow as much as it wanted, without being a lodger in Logger's World's space.

<p align="center">
    <img src="/assets/img/posts/logger-turaco-box.png" alt="Logger's World and Turaco Chorus are represented as blobs, enclosed in a box together. Logger's World looks calm and happy, while Turaco Chorus looks excited and energetic." width="45%">
</p>

My room analogy is the fundamental thinking behind [**Microservice architecture**](https://microservices.io/patterns/microservices.html), where an application has a set of two or more independently deployable services. Thus, while Turaco Chorus is its own straightforward service, its (future) integration with Logger's World will transform its design into a microservice architecture.

A small comment on the name. Where Logger's World described things to be cut down and stored, I felt this insight service had a life of its own. It would show the colour of a user's data; it would be able to engage in dialogue with a user. After looking through birds endemic to my corner of the world, I settled on Turaco Chorus, named after the [colourful Turaco](https://en.wikipedia.org/wiki/Turaco).

# Demo

Turaco Chorus is an API for upstream applications, so it has no user interface of its own. Below, I've written some request/response sequences instead of demo screenshots; you can run them against the live deployment ([turacochorus.literaturelounge.org](http://turacochorus.literaturelounge.org)).

The AI service is opt-in, so a user needs to grant consent before they can make use of it.

**1. Check consent (none granted yet):**

```http
GET /consent
Authorization: Bearer <jwt>
```
```json
{ "granted": false, "grantedAt": null }
```

**2. Grant consent:**

```http
PUT /consent
Authorization: Bearer <jwt>
Content-Type: application/json

{ "granted": true }
```
```json
{ "granted": true, "grantedAt": "2026-09-21T18:20:04.413958+00:00" }
```

**3. Ask a question:**

```http
POST /ask
Authorization: Bearer <jwt>
Content-Type: application/json

{ "question": "How many books and movies did I watch in August?" }
```
```json
{
  "answer": "You read 2 books and watched 2 films this August.",
  "dataUsed": {
    "statsQueried": ["Books", "Films"],
    "range": { "from": "2026-08-01", "to": "2026-08-31" }
  }
}
```

When an upstream application wants to use a user's data for the insight engine, only aggregated stats are given. Since this is the powerhouse of Turaco Chorus, I will speak more about it here.

We have `AggregateStats`, a record constructed from a source, a `DateRange`, the number of entries, and a list of `Dimension`s. Further, a `Dimension` is constructed from a name and a list of `DimensionBucket`s. And, finally, a `DimensionBucket` is constructed from a value and a count. To put it simply, it counts the number of times a particular value appears and only reports back that aggregated number.

So, the `AggregateStats` that could give this answer would be:

```json
{
  "sourceId": "user1",
  "range": { "from": "2026-08-01", "to": "2026-08-31" },
  "totalEntries": 8,
  "dimensions": [
    {
      "name": "Category",
      "buckets": [
        { "value": "Books", "count": 2 },
        { "value": "Films", "count": 2 },
        { "value": "Other", "count": 4 }
      ]
    }
  ]
}
```

# Tech Stack

| Layer | Technology | Free tier |
|---|---|---|
| Service runtime | .NET 8 Web API | Free (open source) |
| Compute | AWS ECS (EC2 launch type) | Single `t3.micro`, free-tier eligible |
| Networking/DNS | Elastic IP + Route 53 | Static IP behind `turacochorus.literaturelounge.org` |
| Database | Amazon DynamoDB (×3 tables: consent, audit, plus read-only access to the upstream's own table) | Always free — 25GB storage, 25 RCU/WCU |
| Auth | Amazon Cognito (verifies the upstream app's own JWTs) | Always free — up to 50,000 MAUs |
| AI provider | Anthropic Claude API or Google Gemini API (config-switchable) | Gemini: ongoing free tier; Claude: one-time trial credit |
| Secrets | AWS Secrets Manager | Provider API key, injected into the ECS task at runtime |
| Infrastructure as Code | AWS CDK (TypeScript) | Three stacks: tables, compute, CI/CD bootstrap |
| CI/CD | GitHub Actions | Build → test → Docker build → push → deploy |

- **Two interchangeable `IInsightEngine` adapters (Claude + Gemini) instead of one**
  - The service can run end-to-end without needing Claude API credits; Gemini's free tier is ongoing, Claude's isn't.
- **Config-driven adapters, not installer-specific code** for `CognitoIdentityVerifier` and `DynamoDbLogDataSource`:
  - The same adapter works for any Cognito pool / DynamoDB schema an installer points it at.
  - This means that a user just passes configuration values, rather than getting into the code.
- **A managed IP prefix-list for the security group, referenced by ID rather than CDK-managed entries**: updating the allow-list is a single CLI call, zero redeploy.

# Technical Challenges: Something's Wrong with this Package?

After you've made some changes in your infrastructure code, you type in the deploy command and your heart's in your throat, hoping that you *finally* understand how to boot an EC2 instance.

```bash
user@users:~/turaco-chorus/infra$ cdk deploy TuracoChorusComputeStack

✨  Synthesis time: 4.8s

TuracoChorusComputeStack: deploying... [1/1]
TuracoChorusComputeStack: creating CloudFormation changeset...

 ✅  TuracoChorusComputeStack

✨  Deployment time: 187.3s

Stack ARN:
arn:aws:cloudformation:af-south-1:123456789012:stack/TuracoChorusComputeStack/abcd1234-...

✨  Total time: 192.1s

```
*(illustrative output, not a real run)*

But something sinister was happening underneath it all. I was using `amazonLinux2()` for my machine image, but that image (the ECS-optimized Amazon Linux 2 AMI) did not come with the AWS CLI already installed. So when the user-data script (defined in `compute-stack.ts`) tried to run an `aws` command, it failed silently.

This script is important because it helps orientate us to the correct IP address for this software. In cloud computing, there are specific IP addresses called **Elastic IP addresses**. Despite the counter-intuitive name, this IP address actually stays associated with your AWS account, so every new instance needs to attach the address to itself at boot. *Every* instance needs this, so that command not running is a huge problem.

For this microservice, things like the servers, storage, and networks are written as code. So, while the user-data script has a command that can technically fail on a given system, that script is only run way later, and the errors are logged in the cloud-init logs on the instance itself, leaving your terminal deceptively clean.

And while your terminal looks good, and ECS *and* CloudFormation show that things are alright too, the request just hangs in your browser, because the command failed, so the Elastic IP never got attached to the new instance.

Solution? Change the machine image to `amazonLinux2023()`, which comes with the AWS CLI installed.

---

* An Amazon **machine image** provides the software needed to boot an Amazon EC2 instance. ([AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html))
* An Amazon EC2 instance is a virtual server in the AWS Cloud. ([AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html))
* A **user-data script** is a script that, by default, EC2 runs only once, when an instance first boots. ([AWS](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html))


# Architecture

While this article began as a description of microservice architecture, Turaco Chorus itself is built on a related architecture: Hexagonal (ports and adapters).

This means that we have a core functionality, written up as client-facing APIs, with users then able to pick which technologies they want to use.

There are three *kinds* of modules in the source code:
* A base module, `TuracoChorus`, containing contracts and configuration scripts for the various adapters.
* `TuracoChorus.Adapters.*`-type modules, containing implementations of exact technologies for different parts of the API's functionality.
* Finally, `TuracoChorus.Core`, containing the actual interface definitions.

The Adapter and Core modules are also accompanied by `*.Tests` modules.

## Hexagonal (Ports and Adapters) Architecture

This is the higher-level directory structure of the service. Now, let's take a closer look at that phrase I used earlier: [Hexagonal architecture](https://alistair.cockburn.us/hexagonal-architecture).

> Both the user-side and the server-side problems actually are caused by the same error in design and programming -- the entanglement between the business logic and the interaction with external entities.

An application has certain functionalities. In Turaco Chorus's case, these functionalities are the following:

* **Identity**: verifying users
* **Data**: where the data exists, for aggregated stats to be made
* **AI Insight**: the AI API responsible for parsing data and answering NL questions
* **Auditing**: logs every account action that runs through the application
* **Consent**: tracking consent for AI insight

The core functionalities of an application are called **ports**: this is where we *enter* the application. The purpose of a port is to have an interface that allows it to communicate with its coupled components.

Now, every upstream user can be different: some are already committed to particular technologies, and for others an alternative has a steep learning curve. Whatever the reason may be, I wanted to build a service that is adaptable… and so I used **adapters**.

<p align="center">
    <img src="/assets/img/posts/turaco-architecture.png" alt="Hexagon labeled with 'Data', 'Consent', 'Identity', 'Insight', and 'Audit' on five of the sides. The sixth has dead-end chevrons. The four of the five sides have one road leading in, except for 'Insight'." width="45%">
</p>

## Containerisation, Infrastructure, and Deployment

On its face, this is quite a simple API to actually use. It provides a service through three routes, `/stats`, `/ask`, and `/consent`. But as you have read above, there are quite a few moving parts holding up these routes. I don't want an upstream application developer to worry too much about environment set-up, so I containerised the application and automated its infrastructure and deployment:
- **Containerisation**: a multi-stage `Dockerfile`. The build stage restores and publishes the app, and the final stage copies only the published output onto the slim ASP.NET runtime image. All configuration is passed in as environment variables, so one image works for any upstream application.
- **Infrastructure**: three CDK stacks (`TuracoChorusStack` for tables, `TuracoChorusComputeStack` for ECS/ASG/task/secret, `TuracoChorusGithubOidcStack` for CI/CD bootstrap), kept apart so tearing down compute never risks table data.
- **CI/CD**: GitHub Actions builds, tests, and pushes the Docker image, then bounces the live ECS service on every merge to `main`.


# Closing

TL;DR: I made a containerised microservice to explore hexagonal architecture, troubleshot through deployment problems, and had *a lot* of fun naming the service.

Not-Long-Enough;Give-Me-Proper-Closer:

I really enjoyed designing with hexagonal architecture. The level of abstraction it requires to design simple interfaces working with several coupled components is an exciting challenge. It makes me explore technologies and uncover the underlying mechanisms that keep software running.

Turaco Chorus is small right now: I've taken it to production, and I'm preparing to implement it in Logger's World. But much like the beautiful bird it's named after, small doesn't mean restricted: it's light enough to fly from forest to forest, singing its song.

<div style="display: flex; justify-content: center; align-items: center; gap: 4%;">
    <img src="/assets/img/posts/turaco-wiki.png" alt="A green Turaco" width="45%">
    <img src="/assets/img/posts/turaco-logo.svg" alt="A green Turaco stylised as a logo" width="45%">
</div>

# Links

- **Live deployment:** [turacochorus.literaturelounge.org](http://turacochorus.literaturelounge.org)
- **GitHub repo:** [github.com/vkwakweni/turaco-chorus](https://github.com/vkwakweni/turaco-chorus)
- **Docs:** [Ethics by Design](https://github.com/vkwakweni/turaco-chorus/blob/main/artifacts/ethics-by-design.md) · [Domain interfaces & objects](https://github.com/vkwakweni/turaco-chorus/blob/main/artifacts/domain-interfaces-and-objects.md) · [Roadmap](https://github.com/vkwakweni/turaco-chorus/blob/main/artifacts/roadmap.md)
