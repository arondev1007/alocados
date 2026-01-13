// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SubscriptionPaymentToken.sol";

contract SubscriptionPaymentTokenTest is Test {
    SubscriptionPaymentToken token;

    address owner = address(0x1);
    address user = address(0x2);
    address subscriptionNFT = address(0x3);
    address attacker = address(0x4);

    uint256 ownerPk = 0xA11CE;
    uint256 userPk = 0xB0B;

    function setUp() public {
        // owner 주소에 private key 매핑
        vm.deal(owner, 10 ether);
        vm.deal(user, 10 ether);

        vm.startPrank(owner);
        token = new SubscriptionPaymentToken("SubscriptionPaymentToken", "SUB", 1_000 ether);
        vm.stopPrank();
    }

    // 테스트 - 초기 발행
    function testInitialSupplyMintedToOwner() public {
        assertEq(token.balanceOf(owner), 1_000 ether);
        assertEq(token.totalSupply(), 1_000 ether);
    }

    // 테스트 - owner만 subscriptionNFT 설정 가능
    function testSetSubscriptionNFTByOwner() public {
        vm.prank(owner);
        token.setSubscriptionNFT(subscriptionNFT);

        assertEq(token.subscriptionNFT(), subscriptionNFT);
    }

    function testSetSubscriptionNFTByNonOwnerRevert() public {
        vm.prank(attacker);
        vm.expectRevert();
        token.setSubscriptionNFT(subscriptionNFT);
    }

    // 테스트 - transferFrom ( subscriptionNFT만 가능 )
    function testTransferFromByUnauthorizedCallerRevert() public {
        vm.prank(owner);
        token.setSubscriptionNFT(subscriptionNFT);

        vm.prank(attacker);
        vm.expectRevert(SubscriptionPaymentToken.UnauthorizedCaller.selector);
        token.transferFrom(owner, user, 1 ether);
    }

    // 테스트 - Permit 서명으로 allowance 설정
    function testPermitSetsAllowance() public {
        vm.prank(owner);
        token.setSubscriptionNFT(subscriptionNFT);

        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        user,
                        subscriptionNFT,
                        100 ether,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        token.permit(user, subscriptionNFT, 100 ether, deadline, v, r, s);

        assertEq(token.allowance(user, subscriptionNFT), 100 ether);
    }

    // 테스트 - Permit + transferFrom 성공 프로세스
    function testPermitAndTransferFromSuccess() public {
        vm.prank(owner);
        token.setSubscriptionNFT(subscriptionNFT);

        // owner -> user 토큰 이동 (초기 상태 세팅)
        vm.prank(owner);
        token.transfer(user, 100 ether);

        uint256 nonce = token.nonces(user);
        uint256 deadline = block.timestamp + 1 days;

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        user,
                        subscriptionNFT,
                        50 ether,
                        nonce,
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

        token.permit(user, subscriptionNFT, 50 ether, deadline, v, r, s);

        // subscriptionNFT 결제 청구
        vm.prank(subscriptionNFT);
        token.transferFrom(user, owner, 50 ether);

        assertEq(token.balanceOf(user), 50 ether);
        assertEq(token.balanceOf(owner), 950 ether);
    }
}
