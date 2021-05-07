# JWrapped

This contract is an on chain implementation of a centralised valued locked wrapped token (and doesn't include the needed backend).

A centralised authorities is capable to issue tokens on the ETH chain, it also to promise giving back burned tokens.

To do so a new token mint should only happen when the authority have received true tokens on his account and the authority must actually release the concerned tokens.

If both requirement are met, then the value of the wrapped token closely follows the true one.

# Liability

Following the [GPL-3](./LICENSE) this code is licensed about this code is provided without any liability (read section 16 of the license). You are fully responsible of anything you do with this code.

# Features

- [ERC20](https://eips.ethereum.org/EIPS/eip-20) tradeable token.
- [ERC2612](https://eips.ethereum.org/EIPS/eip-2612) permit for ERC20 tokens (gas free approvals using [ERC712](https://eips.ethereum.org/EIPS/eip-712)).
- An owned contract where the owner can:
  - Manage multiple minters
  - override safety (force transfer in order to resolve a potential hack)
  - Pause / Unpause the contract.
  - Revoke a bunch of emited permits.
- Minting of tokens:
  - Either by calling the `mint` function using a minter account.
  - Or by signing an [ERC712](https://eips.ethereum.org/EIPS/eip-712) message using a minter account.
- Any user may *burn* some tokens too, this emits an event that the centralised authority pickup and then use to send the original coins on the wrapped chain.
