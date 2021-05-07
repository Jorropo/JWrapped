// SPDX-License-Identifier: gpl3
// Martin Lundfall, "EIP-2612: permit – 712-signed approvals [DRAFT]," Ethereum Improvement Proposals, no. 2612, April 2020. [Online serial]. Available: https://eips.ethereum.org/EIPS/eip-2612.
pragma solidity >=0.5.0;

import { IERC20 } from './IERC20.sol';

interface IERC2612 is IERC20 {
  function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
  function nonces(address owner) external view returns (uint);
  function DOMAIN_SEPARATOR() external view returns (bytes32);
  function PERMIT_TYPEHASH() external view returns (bytes32);
}
