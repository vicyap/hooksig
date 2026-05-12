# hooksig

Fast, private webhook debugging tools for Stripe, Paddle, Lemon Squeezy, and Polar.

Live at [hooksig.fly.dev](https://hooksig.fly.dev). Built with Phoenix LiveView.

## Tools

- Stripe webhook signature verifier — paste a payload, `Stripe-Signature` header, and `whsec_` secret; get the exact reason verification failed plus framework-specific fixes
- Paddle webhook signature verifier
- Lemon Squeezy webhook signature verifier
- Stripe event simulator — generate realistic test payloads
- Stripe test cards — searchable library with copy buttons
- Stripe proration calculator
- Stripe event semantics — `checkout.session.completed` vs `invoice.paid` vs `payment_intent.succeeded`
- Stripe subscription state machine

All inputs stay in memory on a single request. Nothing is logged or persisted.

## Local

```sh
mise trust
mise install
mix setup
mix phx.server
```

Open http://localhost:4000.

## Checks

```sh
mix precommit
docker build -t hooksig:local .
```

## Deploy

The app is configured for `hooksig.fly.dev` with one auto-starting, auto-stopping machine.

```sh
flyctl deploy
```
