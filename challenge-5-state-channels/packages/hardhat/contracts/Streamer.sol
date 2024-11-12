// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Streamer is Ownable {
    event Opened(address, uint256);
    event Challenged(address);
    event Withdrawn(address, uint256);
    event Closed(address);

    struct Signature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    struct Voucher {
        uint256 updatedBalance;
        Signature sig;
    }

    mapping(address => uint256) balances;
    mapping(address => uint256) canCloseAt;

    function fundChannel() public payable {
        require(msg.value > 0, "Funds not provided!");
        require(balances[msg.sender] == 0, "A channel is already running!");
        balances[msg.sender] = msg.value;
        emit Opened(msg.sender, msg.value);
    }

    function timeLeft(address channel) public view returns (uint256) {
        require(canCloseAt[channel] != 0, "channel is not closing");
        if (canCloseAt[channel] < block.timestamp) {
            return 0;
        } else {
            return canCloseAt[channel] - block.timestamp;
        }
    }

    function withdrawEarnings(Voucher calldata voucher) public onlyOwner {
        bytes32 _hashed = keccak256(abi.encode(voucher.updatedBalance));
        bytes memory _prefixed = abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            _hashed
        );
        bytes32 _prefixedHashed = keccak256(_prefixed);

        address _msgSigner = ecrecover(
            _prefixedHashed,
            voucher.sig.v,
            voucher.sig.r,
            voucher.sig.s
        );
        require(
            balances[_msgSigner] > voucher.updatedBalance,
            "Insufficient balance!"
        );
        uint256 _amount = balances[_msgSigner] - voucher.updatedBalance;
        payable(msg.sender).transfer(_amount);
        balances[_msgSigner] = voucher.updatedBalance;
        emit Withdrawn(_msgSigner, _amount);
    }

    function challengeChannel() public {
        require(balances[msg.sender] > 0, "There is no channel running!");
        canCloseAt[msg.sender] = block.timestamp + 30 seconds;
        emit Challenged(msg.sender);
    }

    function defundChannel() public {
        require(timeLeft(msg.sender) == 0, "Channel can't be closed yet!");
        payable(msg.sender).transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
        emit Closed(msg.sender);
    }
}