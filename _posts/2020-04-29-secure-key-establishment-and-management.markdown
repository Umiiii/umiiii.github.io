---
title: "Secure key establishment and management"
date: 2020-04-29T15:30:59+08:00
draft: false
tags: ["Network","Security"]
layout: post
---

# Agenda 
- Ad Hoc Network Key Establishment
- Key Distribution in Large-scale Network

# Ad Hoc Network Key Establishment

## What is Ad hoc network?

In a ad hoc network, each device acts as a router.
Anyone can join and leave in the middle. The range, location of them can be totally different.
It is almost impossible to predict the structure of network. 
We need to run a routing protocol to discover the path through network. 
The resources in those node usually has few resources.

## Ad hoc network properties

- Mobile 
- Wireless communication
- No fixed infrastructure
- Participants from different administrative domains
- Medium to high computation, memory
- Usually human user with each device 

## Typical Key Establishment

### SSL/TLS

Assumption: Browser can authenticate server's certificate with its local CA root certificates

### Large-group key distribution

Assumption: Each client already has a secure connection to key distribution server

The challenge in ad hoc networks: establish keys without any prior trust relationships

## Problem definition

### Goals

- Secure, authenticated communication between devices that share no prior context
- *Demonstractive identification*: ensure to human user which other device they are communicating with

For example, if I have an Apple device and I walk to a room which contains an Epson projector. It is hard to tell whether the projector is the one that I want to connect. There may exists another Epson projector in other room which hijacks and relays the connection.

### Conditions

- No CAs or other trusted authorities
- No PKI
- No shared secrets
- No shared communication history

The problem reduces to key establishment. 

Diffie & Hellman tells us how to share secret.

### Diffie-Hellman Key Agreement

Public values: large prime $p$, generator $g$

Alice has secret $a$, Bob has secret $b$

A -> B: $g^a mod p$

B -> A: $g^b mod p$

Bob: ${(g^a mod p)}^b mod p = g^{ab} mod p$

Alice: ${g^b mod p}^a mod p = g^{ab} mod p$

$g^{ab} mod p$ is the final key.

Eve cannot compute $g^{ab} mod p$, even she observe all messages.

But we are not done. The problem is Man-in-the-middle attack.

### MitM Attack

Mallory can impersonate Alice to Bob, and impersonate Bob to Alice.

```
     g^a        g^m2
A --------> M --------> B
  <-------    <--------
   g^m1   m1,m2  g^b

   g^am1         g^bm2
```

B can listen this message, since it is a boardcast message.

By the time when M is sending the impersonated message, B may said he is already received this message.

How does M prevent it?

- ARP posioning. When M send ARP message, A think M is B and B think M is A. 
- Change wireless channel. KRACK attack (2018). The attacker forces A to use channel 1 and B to use channel 2. 

#### How serious is MitM attack?

- Wireless communication is invisible
   - People can't tell which devices are connected
- Neighbor can easily execute MitM attack
   - If neighbor has a faster computer, it can easily respond faster than the legitimate devices

Easy to perform with high success rate.

#### Solution to MitM attack

- Authentication
- Public DH values must be authenticated
- Tradeoffs between security, usability, and transparency to the user
   - Transparency
      - Does the user realize she is involved in a key establishment protocol?
      - Does the user need to realize this?

# Key Agreement in P2P Wiresless Networks

Source: Key agreement in peer-to-peer wireless networks. Mario Cagalj, Srdjan Capkun, Jean-Pierre Hubaux. 

- Use Diffie-Hellman to establish keys
- Present three techniques to combat MitM
   - Visual comparison of short strings
   - Distance bounding
   - Integrity codes
- All 3 verify the integrity of DH public parameters $g^A$ and $g^B$

## Commitment schemes

Commitment semantics
- Binding
- Hiding

$$(c, d) <- commit(m)$$

m: message; c: commitment; d: opening value

A want to commit the message, but doesn't weant to reveal the message. So A send $c$ first to B, and send $d$ after. By sending $d$, A is revealing the message $m$, and also B knows A is commiting the message $m$ by $c$.

Given $c$, infeasible to find the decommitment $d'$

It is infeasible to find $d'$ s.t. $(c, d')$ reveals $m' \neq m$

Example
- $c=H(m||r)$ where $r$ is a random number
- $d = m,r$

### Simple Protocol: String Comparison

- Public values: large prime $p$, generator $g$
- Alice has secret $a$, Bob has secret $b$
- A -> B: $g^a mod p$
- B -> A: $g^b mod p$
- Alice and Bob computer: $g^{ab} mod p$
- Alice's and Bob's devices display last 20 bits of $H(g^{ab} mod p)$ and they manually compare them (5 hexadecimal digits), if they match, the both click "ok".

Is it a secure protocol?

No! Birthday paradox. 

#### Shortcomings of Simple Protocol

- First, Alice and Bob may not really compare the strings, but simply click "ok", how to avoid this?

- Knowing $g^a$ and $g^b$, attack can computer $g^c$ and $g^d$ such that $H(g^{ac})_{n} = H(g^{bd})_{n}$
   - Complexity: Only $ O(2^{n/2}) $, around 1000.

 

