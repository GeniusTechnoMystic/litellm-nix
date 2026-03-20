<h1 align="center">
        🚅 LiteLLM
    </h1>
    <p align="center">
        <p align="center">Call 100+ LLMs in OpenAI format. [Bedrock, Azure, OpenAI, VertexAI, Anthropic, Groq, etc.]
        </p>
        <p align="center">
        <a href="https://render.com/deploy?repo=https://github.com/BerriAI/litellm" target="_blank" rel="nofollow"><img src="https://render.com/images/deploy-to-render-button.svg" alt="Deploy to Render"></a>
        <a href="https://railway.app/template/HLP0Ub?referralCode=jch2ME">
          <img src="https://railway.app/button.svg" alt="Deploy on Railway">
        </a>
        </p>
    </p>
<h4 align="center"><a href="https://docs.litellm.ai/docs/simple_proxy" target="_blank">LiteLLM Proxy Server (AI Gateway)</a> | <a href="https://docs.litellm.ai/docs/enterprise#hosted-litellm-proxy" target="_blank"> Hosted Proxy</a> | <a href="https://docs.litellm.ai/docs/enterprise"target="_blank">Enterprise Tier</a></h4>
<h4 align="center">
    <a href="https://pypi.org/project/litellm/" target="_blank">
        <img src="https://img.shields.io/pypi/v/litellm.svg" alt="PyPI Version">
    </a>
    <a href="https://www.ycombinator.com/companies/berriai">
        <img src="https://img.shields.io/badge/Y%20Combinator-W23-orange?style=flat-square" alt="Y Combinator W23">
    </a>
    <a href="https://wa.link/huol9n">
        <img src="https://img.shields.io/static/v1?label=Chat%20on&message=WhatsApp&color=success&logo=WhatsApp&style=flat-square" alt="Whatsapp">
    </a>
    <a href="https://discord.gg/wuPM9dRgDw">
        <img src="https://img.shields.io/static/v1?label=Chat%20on&message=Discord&color=blue&logo=Discord&style=flat-square" alt="Discord">
    </a>
    <a href="https://www.litellm.ai/support">
        <img src="https://img.shields.io/static/v1?label=Chat%20on&message=Slack&color=black&logo=Slack&style=flat-square" alt="Slack">
    </a>
    <a href="https://codspeed.io/BerriAI/litellm?utm_source=badge">
        <img src="https://img.shields.io/endpoint?url=https://codspeed.io/badge.json" alt="CodSpeed"/>
    </a>
</h4>

# LiteLLM — NixOS Tooling

⚠️ This repository is a fork of:
https://github.com/BerriAI/litellm

The purpose of this fork is **not to replace the upstream project**.

Instead it provides:

• NixOS container packaging
• reproducible container builds
• Nix flake integration
• optional compose/k3s deployment

---

## Upstream Project

LiteLLM is an OpenAI-compatible LLM gateway supporting
100+ providers.

Full documentation:
https://github.com/BerriAI/litellm

---

## What This Fork Adds

This fork adds infrastructure for running LiteLLM in a
reproducible NixOS container environment.

---

## Why This Exists

NixOS users often prefer declarative infrastructure and
reproducible builds. This fork provides a clean way to run
LiteLLM within that ecosystem.

---

## Sync with Upstream

This repository tracks upstream LiteLLM and periodically
merges updates.
