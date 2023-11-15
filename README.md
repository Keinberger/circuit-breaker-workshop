## Nomad hack Circuit Breaker prevention

This repository contains a reconstruction of the Nomad bridge hack with an EIP-7265 Circuit Breaker integration.

The Circuit Breaker integration completely renders the exploit unusable and prevents the funds from being drained.

## Usage

### Install dependencies

```shell
$ forge install
```

### Running the hack replication

```shell
$ forge test
```

You can notice that the balance of the attacker stays 0, meaning that they are not able to drain any funds from the bridge.

For a more detailed view run:

```shell
$ forge test -vvvv
```

You will notice the `RateLimited` event being emitted and the `prevent` function being called on the Reject Settlement Module contract when the exploit is being run.

This means, that the Circuit Breaker has triggered and is actively preventing the liquidity drain by reverting the attack transactions.
