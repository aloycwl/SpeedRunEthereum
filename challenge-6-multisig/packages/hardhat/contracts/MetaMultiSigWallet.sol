// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MetaMultiSigWallet {
    using ECDSA for bytes32;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event ExecuteTransaction(
        address indexed owner,
        address payable to,
        uint256 value,
        bytes data,
        uint256 nonce,
        bytes32 hash,
        bytes result
    );
    event Owner(address indexed owner, bool added);
    mapping(address => bool) public isOwner;
    uint256 public signaturesRequired;
    uint256 public nonce;
    uint256 public chainId;

    constructor(
        uint256 _chainId,
        address[] memory _owners,
        uint256 _signaturesRequired
    ) {
        require(
            _signaturesRequired > 0,
            "constructor: must be non-zero sigs required"
        );
        signaturesRequired = _signaturesRequired;
        unchecked {
            for (uint256 i = 0; i < _owners.length; ++i) {
                address owner = _owners[i];
                require(
                    owner != address(0) && !isOwner[owner],
                    "constructor: invalid"
                );
                emit Owner(owner, isOwner[owner] = true);
            }
        }
        chainId = _chainId;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "Not Self");
        _;
    }

    function addSigner(address newSigner, uint256 newSignaturesRequired)
        public
        onlySelf
    {
        require(
            newSigner != address(0) &&
                !isOwner[newSigner] &&
                newSignaturesRequired > 0,
            "addSigner: invalid"
        );
        signaturesRequired = newSignaturesRequired;
        emit Owner(newSigner, isOwner[newSigner] = true);
    }

    function removeSigner(address oldSigner, uint256 newSignaturesRequired)
        public
        onlySelf
    {
        require(
            isOwner[oldSigner] && newSignaturesRequired > 0,
            "removeSigner: invalid"
        );
        signaturesRequired = newSignaturesRequired;
        emit Owner(oldSigner, isOwner[oldSigner] = false);
    }

    function updateSignaturesRequired(uint256 newSignaturesRequired)
        public
        onlySelf
    {
        require(newSignaturesRequired > 0, "updateSignaturesRequired: invalid");
        signaturesRequired = newSignaturesRequired;
    }

    function getTransactionHash(
        uint256 _nonce,
        address to,
        uint256 value,
        bytes memory data
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    chainId,
                    _nonce,
                    to,
                    value,
                    data
                )
            );
    }

    function executeTransaction(
        address payable to,
        uint256 value,
        bytes memory data,
        bytes[] memory signatures
    ) public returns (bytes memory) {
        require(isOwner[msg.sender], "executeTransaction: invalid");
        bytes32 _hash = getTransactionHash(nonce, to, value, data);
        uint256 validSignatures;
        address duplicateGuard;
        unchecked {
            ++nonce;
            for (uint256 i = 0; i < signatures.length; ++i) {
                address recovered = recover(_hash, signatures[i]);
                require(
                    recovered > duplicateGuard,
                    "executeTransaction: invalid"
                );
                duplicateGuard = recovered;
                if (isOwner[recovered]) ++validSignatures;
            }
        }

        (bool success, bytes memory result) = to.call{value: value}(data);
        require(
            success && validSignatures >= signaturesRequired,
            "executeTransaction: invalid"
        );

        emit ExecuteTransaction(
            msg.sender,
            to,
            value,
            data,
            nonce - 1,
            _hash,
            result
        );
        return result;
    }

    function recover(bytes32 _hash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        return _hash.recover(_signature);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    event OpenStream(address indexed, uint256, uint256);
    event CloseStream(address indexed);
    event Withdraw(address indexed, uint256, string);

    struct Stream {
        uint256 amount;
        uint256 frequency;
        uint256 last;
    }
    mapping(address => Stream) public streams;

    function streamWithdraw(uint256 amount, string memory reason) public {
        require(streams[msg.sender].amount > 0, "withdraw: invalid");
        _streamWithdraw(payable(msg.sender), amount, reason);
    }

    function _streamWithdraw(
        address payable to,
        uint256 amount,
        string memory reason
    ) private {
        uint256 totalAmountCanWithdraw = streamBalance(to);
        require(totalAmountCanWithdraw >= amount, "withdraw: invalid");
        unchecked {
            streams[to].last =
                streams[to].last +
                (((block.timestamp - streams[to].last) * amount) /
                    totalAmountCanWithdraw);
        }
        emit Withdraw(to, amount, reason);
        to.transfer(amount);
    }

    function streamBalance(address to) public view returns (uint256) {
        unchecked {
            return
                (streams[to].amount * (block.timestamp - streams[to].last)) /
                streams[to].frequency;
        }
    }

    function openStream(
        address to,
        uint256 amount,
        uint256 frequency
    ) public onlySelf {
        require(
            streams[to].amount == 0 && amount > 0 && frequency > 0,
            "openStream: invalid"
        );

        (streams[to].amount, streams[to].frequency, streams[to].last) = (
            amount,
            frequency,
            block.timestamp
        );

        emit OpenStream(to, amount, frequency);
    }

    function closeStream(address payable to) public onlySelf {
        require(streams[to].amount > 0, "closeStream: invalid");
        _streamWithdraw(to, streams[to].amount, "stream closed");
        delete streams[to];
        emit CloseStream(to);
    }
}
