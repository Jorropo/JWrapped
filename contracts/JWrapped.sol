 // SPDX-License-Identifier: GPL-3
 // Jorropo - JWrapped, available at : https://github.com/Jorropo/JWrapped
pragma solidity >= 0.8.0 < 0.9.0; // Really need solidity 0.8 as math isn't checked manually

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC2612} from "./interfaces/IERC2612.sol";

contract WrappedToken is IERC20, IERC2612 {
    // This contract is an on chain implementation of a centralised valued locked wrapped token.
    // A centralised authorities is capable to issue tokens on the ETH chain, it also to promise giving back burned tokens.
    // To do so a new token mint should only happen when the authority have received true tokens on his account.
    
    bool public running = true;
    modifier onlyRunning() {
        require(running || msg.sender == owner, "JWrapped: paused"); // Allows owner to override the paused status
        _;
    }
    function setRunning(bool _running) external onlyOwner {
        running = _running;
    }
    
    address public owner; // Owner is the true owner of the wrapped token, responsible to manage minters
    modifier onlyOwner() {
        require(msg.sender == owner, "JWrapped: not owner");
        _;
    }
    function transferOwnership(address to) external onlyOwner {
        _transferOwnership(to);
    }
    function _transferOwnership(address to) internal {
        emit OwnershipTransfer(owner, to);
        owner = to;
    }
    event OwnershipTransfer(address indexed from, address indexed to);
    
    mapping (address => bool) public minters; // If true a minter is allowed to mint tokens
    modifier onlyMinter() {
        require(minters[tx.origin], "JWrapped: not a minter"); // This is checked against `tx.origin` it is then really important that minters never call untrusted contracts.
        _;
    }
    
    function editPermission(address[] calldata addrs, bool tgt) external onlyOwner {
        uint l = addrs.length;
        while (l > 0) {
            l--;
            minters[addrs[l]] = tgt;
        }
    }
    
    constructor(string memory _name, string memory _symbol) {
        _transferOwnership(msg.sender);
        name = _name;
        symbol = _symbol;
    }
    
    // Minting stuff
    function mint(address to, uint256 amount) external onlyMinter onlyRunning {
        _mint(to, amount);
    }
    
    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    // Burning stuff
    event Burn(bytes32 indexed to, uint256 amount); // targetAddress is the address on the other chain
    
    function burn(bytes32 to, uint256 amount) external onlyRunning {
        _burn(msg.sender, to, amount);
    }
    
    function burnFrom(address from, bytes32 to, uint256 amount) external {
        _approvalDecrease(from, amount);
        _burn(from, to, amount);
    }
    
    function _burn(address from, bytes32 to, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
        emit Burn(to, amount);
    }
    
    // ERC721 minting
    mapping(address => mapping (uint256 => bool)) public minting_nonces; // Using a nonce table to allows 
    uint256 public minMintingDeadline;
    bytes32 public immutable MINTING_TYPEHASH = keccak256("Mint(address emitter,address receiver,uint256 value,uint256 nonce,uint256 emitingDate)");

    function bunchNonceDisproove(uint256 _minMintingDeadline) external onlyOwner { // Allows the owner to remove a bunch of wrong nonces at once
        minMintingDeadline = _minMintingDeadline;
    }

    function mintWithPermit(address emitter, address receiver, uint value, uint256 nonce, uint256 emitingDate, uint8 v, bytes32 r, bytes32 s) external onlyRunning {
        require(minters[emitter], "JWrapped: not a minter");
        require(emitingDate > minMintingDeadline, "JWrapped: revoked minting permit");
        require(!minting_nonces[emitter][nonce], "JWrapped: invalid nonce");
        minting_nonces[emitter][nonce] = true; // Disable this nonce
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(MINTING_TYPEHASH, emitter, receiver, value, nonce, emitingDate))
        ));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == emitter, "JWrapped: invalid minting permit");
        _mint(receiver, value);
    }
    
    // ERC20 stuff
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;
    uint256 public override totalSupply;
    
    uint8 constant public override decimals = 18;
    string public override name;
    string public override symbol;
    
    function approve(address spender, uint256 limit) external override returns (bool) {
        _approve(msg.sender, spender, limit);
        return true;
    }
    
    function _approve(address from, address spender, uint256 limit) internal {
        allowance[from][spender] = limit;
        emit Approval(from, spender, limit);
    }
    
    function transfer(address to, uint256 amount) external override onlyRunning returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        _approvalDecrease(from, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        if (to == address(0)) totalSupply -= amount;
        emit Transfer(from, to, amount);
    }
    
    function _approvalDecrease(address from, uint256 amount) internal {
        if (!running) {
            require(msg.sender == owner, "JWrapped: paused"); // Allows owner to overwrite the paused status.
            return; // It's the owner he is free to do whatever anyway.
        }
        uint256 v = allowance[from][msg.sender];
        if (v == type(uint256).max) return; // Save gas if we are using a maxed approval
        if (v < amount) { // If we are over using, let's check for the owner first
            require(msg.sender == owner, "JWrapped: approval too small"); // Allows the owner to skip approval
            return;
        }
        v -= amount;
        allowance[from][msg.sender] = v;
    }
    
    // ERC2612 stuff
    // DOMAIN_SEPARATOR, PERMIT_TYPEHASH, nonces and were pulled and from https://github.com/Uniswap/uniswap-v2-core/blob/4dd59067c76dea4a0e8e4bfdda41877a6b16dedc/contracts/UniswapV2ERC20.sol and has been modified
    bytes32 public immutable override DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
            keccak256(bytes(name)),
            keccak256(bytes("0")),
            _getChainID(),
            address(this)
        ));
    mapping(address => uint256) public override nonces;
    bytes32 public immutable override PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function permit(address _owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(deadline >= block.timestamp, 'JWrapped: Permit deadline expired');
        bytes32 digest = keccak256(abi.encodePacked(
            '\x19\x01',
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(PERMIT_TYPEHASH, _owner, spender, value, nonces[_owner]++, deadline))
        ));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == _owner, 'JWrapped: invalid permit');
        _approve(_owner, spender, value);
    }

    function _getChainID() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}