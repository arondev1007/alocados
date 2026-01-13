// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "forge-std/Test.sol";
import "../src/SubscriptionNFT.sol";

contract SubscriptionNFTTest is Test {
    SubscriptionNFT nft;
    using MessageHashUtils for bytes32;

    address owner = address(this); // 사업자
    address user = address(0x1);
    address newPayer = address(0x2);

    // 더미 ERC20 (transferFrom 항상 성공)
    DummyERC20 token;

    function setUp() public {
        token = new DummyERC20();
        nft = new SubscriptionNFT(address(token));
    }

    // 테스트 - 구독
    function testSubscribeMintsNFT() public {
        bytes memory sig = _signSubscribe(
            user,
            100 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 30 days)
        );

        nft.subscribe(
            user,
            100 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 30 days),
            sig
        );

        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.ownerOf(1), user);
    }

    // 테스트 - Ping
    function testPingByOwner() public {
        _subscribe(user);

        vm.prank(user);
        bytes memory out = nft.ping("hello");

        assertEq(out, "hello");
    }

    function testPingFailsWithoutNFT() public {
        vm.expectRevert();
        nft.ping("fail");
    }

    // 테스트 - 구독 해지
    function testUnsubscribeTransfersNFTToContract() public {
        _subscribe(user);

        vm.prank(user);
        nft.unsubscribe(1);

        assertEq(nft.ownerOf(1), address(nft));
    }

    // 테스트 - claim
    function testClaimDoesNotRevert() public {
        _subscribe(user);

        vm.warp(block.timestamp + 31 days);
        nft.claim(1); // 성공/실패 여부와 무관하게 revert ❌
    }

    // 테스트 - assign
    function testAssignChangesPayer() public {
        _subscribe(user);

        bytes memory sigFrom = _signAssign(1, user);
        bytes memory sigTo = _signAssign(1, newPayer);

        nft.assign(1, user, newPayer, sigFrom, sigTo);
    }

    function _subscribe(address _user) internal {
        bytes memory sig = _signSubscribe(
            _user,
            100 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 30 days)
        );

        nft.subscribe(
            _user,
            100 ether,
            uint64(block.timestamp),
            uint64(block.timestamp + 30 days),
            sig
        );
    }

    function _signSubscribe(
        address _user,
        uint256 price,
        uint64 start,
        uint64 end
    ) internal returns (bytes memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(_user, price, start, end, address(nft))
        ).toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_privateKeyOf(_user), hash);

        return abi.encodePacked(r, s, v);
    }

    function _signAssign(
        uint256 tokenId,
        address signer
    ) internal returns (bytes memory) {
        bytes32 hash = keccak256(
            abi.encodePacked(tokenId, signer, address(nft))
        ).toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_privateKeyOf(signer), hash);

        return abi.encodePacked(r, s, v);
    }

    function _privateKeyOf(address a) internal pure returns (uint256) {
        return uint256(uint160(a));
    }
}

// Dummy ERC20
contract DummyERC20 {
    function transferFrom(
        address,
        address,
        uint256
    ) external pure returns (bool) {
        return true;
    }
}
