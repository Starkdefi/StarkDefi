# StarkDefi

This is the official contract repository for StarkDefi.

## Getting Started

This project (Cairo1) uses [Protostar](https://docs.swmansion.com/protostar/) - a Starknet smart contract development toolchain - for development and testing.

### Get Protostar
First [install](https://docs.swmansion.com/protostar/docs/cairo-1/installation) Protostar and confirm that it is working by following these steps:

1. Install Protostar

```bash
curl -L https://raw.githubusercontent.com/software-mansion/protostar/master/install.sh | bash
```

2. Restart termnial

3. Confirm installation

```bash
protostar -v
```

## Testing & Development

### Protostar

Run the following command to install the Protostar dependencies:

```bash
protostar install
```

Compile the contracts by running the following command:

```bash
protostar build
```

Run the tests by running the following command:

```bash
protostar test
```

### Scripts

TODO: Add scripts for deploying and interacting with the contracts.
