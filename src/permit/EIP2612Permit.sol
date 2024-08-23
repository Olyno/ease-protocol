// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./ECDSA.sol";

abstract contract EIP2612Permit {
    using ECDSA for bytes32;

    string private constant EIP712_DOMAIN_NAME = "Compound";
    string private constant EIP712_DOMAIN_VERSION = "1";

    bytes32 private immutable _DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    constructor() {
        _DOMAIN_SEPARATOR = hashEIP712Domain(
            EIP712_DOMAIN_NAME,
            EIP712_DOMAIN_VERSION,
            block.chainid,
            address(this)
        );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit: expired deadline");

        uint256 currentNonce = nonces[owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        spender,
                        value,
                        currentNonce,
                        deadline
                    )
                )
            )
        );

        address recoveredAddress = digest.recover(v, r, s);
        require(recoveredAddress == owner, "Permit: invalid signature");

        nonces[owner]++; // Increment nonce after using it

        _approve(owner, spender, value);
    }

    function domainSeparator() public view returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    function hashEIP712Domain(
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );
    }

    function _approve(address owner, address spender, uint256 value) internal virtual;
}
